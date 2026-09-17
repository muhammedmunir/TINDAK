<#
TINDAK - static tests for the RLS fixture and its harness (EAR-BLOCKER-01)

No network, no database. Proves the fixture can no longer write to auth.*,
that the harness refuses to run unless explicitly confirmed, and that the
harness only deletes the users it created.

  powershell -ExecutionPolicy Bypass -File supabase/tests/rls_fixture.tests.ps1
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sqlPath = Join-Path $here 'rls_memories.sql'
$harnessPath = Join-Path $here 'run-rls-matrix.ps1'
$sql = [IO.File]::ReadAllText($sqlPath)
$harness = [IO.File]::ReadAllText($harnessPath)
# Code only: the harness explains the old INSERT in its header, which must not
# count as the harness doing it.
$harnessCode = [regex]::Replace($harness, '(?s)<#.*?#>', '')
$harnessCode = [regex]::Replace($harnessCode, '(?m)^\s*#.*$', '')

$failures = New-Object System.Collections.Generic.List[string]
function Check([string]$Name, [bool]$Ok) {
  $label = if ($Ok) { 'ok  ' } else { 'FAIL' }
  Write-Output "$label $Name"
  if (-not $Ok) { $failures.Add($Name) }
}

# Strip SQL comments so prose in the header cannot hide or fake a statement.
$sqlCode = [regex]::Replace($sql, '(?m)--.*$', '')

# --- fixture ---
Check 'fixture: no INSERT/UPDATE/DELETE/TRUNCATE/ALTER/DROP on auth.*' `
  ($sqlCode -notmatch '(?i)\b(insert\s+into|update|delete\s+from|truncate(\s+table)?|alter\s+table|drop\s+table)\s+auth\.')
# Two legitimate reads: the guard, and check B-12 proving an ordinary user
# CANNOT read auth.users. Every reference must be a read.
$sqlNoStrings = [regex]::Replace($sqlCode, "'[^']*'", "''")
$authRefs = [regex]::Matches($sqlNoStrings, '(?i)\bauth\.users\b').Count
$authReads = [regex]::Matches($sqlNoStrings, '(?i)\bfrom\s+auth\.users\b').Count
Check "fixture: every auth.users reference is a read ($authReads of $authRefs)" (($authRefs -eq 2) -and ($authReads -eq $authRefs))
Check 'fixture: user A placeholder appears exactly once' `
  (([regex]::Matches($sqlCode, '__RLS_TEST_USER_A__')).Count -eq 1)
Check 'fixture: user B placeholder appears exactly once' `
  (([regex]::Matches($sqlCode, '__RLS_TEST_USER_B__')).Count -eq 1)
Check 'fixture: test user ids are no longer generated in SQL' `
  ($sqlCode -notmatch '(?m)^\s*[ab]\s+uuid\s*:=\s*gen_random_uuid\(\)')
Check 'fixture: guard refuses identical ids' ($sqlCode -match 'if a = b then\s+raise exception')
Check 'fixture: guard requires rls-test-*@tindak.invalid users' ($sqlCode -match "email like 'rls-test-%@tindak\.invalid'")
Check 'fixture: guard refuses users that already own data' ($sqlCode -match 'already own memories')
Check 'fixture: cleanup removes public rows of the test users only' `
  ($sqlCode -match 'delete from public\.memories where user_id in \(a, b\)')

$checkIds = @([regex]::Matches($sqlCode, "\(\s*'([PBISZ]-\d+[a-z]?)'|select\s+'([PBISZ]-\d+[a-z]?)'") | ForEach-Object {
  if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
} | Select-Object -Unique)
Check "fixture: still 32 checks (found $($checkIds.Count))" ($checkIds.Count -eq 32)
foreach ($id in 'P-1','P-2','P-3','P-4','P-5','P-6','P-7','P-8','B-1','B-2','B-2b','B-2c','B-3','B-4','B-5','B-5b','B-6','B-7','B-12','B-13','B-13b','B-14','B-15','I-1','I-2','I-3','I-4','I-5','I-6','I-7','S-1','Z-1') {
  if ($checkIds -notcontains $id) { Check "fixture: check $id present" $false }
}

# --- harness: static ---
$errors = $null
$null = [Management.Automation.PSParser]::Tokenize($harness, [ref]$errors)
Check 'harness: parses' (@($errors).Count -eq 0)
Check 'harness: ASCII only' (@([IO.File]::ReadAllBytes($harnessPath) | Where-Object { $_ -gt 127 }).Count -eq 0)
Check 'harness: refusal comes before any file or network access' `
  ($harness.IndexOf('if (-not $ConfirmLiveRun)') -ge 0 -and
   $harness.IndexOf('if (-not $ConfirmLiveRun)') -lt $harness.IndexOf('Read-DotEnv (') -and
   $harness.IndexOf('if (-not $ConfirmLiveRun)') -lt $harness.IndexOf('Invoke-RestMethod'))
Check 'harness: users created only through the Auth Admin API' `
  ($harness -match '-Method Post -Uri "\$base/auth/v1/admin/users"')
Check 'harness: exactly one DELETE, against a user it created' `
  ((([regex]::Matches($harness, '-Method Delete')).Count -eq 1) -and ($harness -match 'foreach \(\$id in \$created\)[\s\S]{0,120}-Method Delete -Uri "\$base/auth/v1/admin/users/\$id"'))
Check 'harness: refuses a fixture that writes to auth.*' ($harness -match 'writes to auth\.\* - refusing to run')
Check 'harness: never prints the token or admin key' `
  ($harness -notmatch 'Write-Output[^\r\n]*\$(token|admin|adminKey|keys)\b')
Check 'harness: no project ref or key committed' `
  ($harness -notmatch '[a-z0-9]{20}\.supabase\.co|sbp_[0-9a-f]{10}|sb_secret_[A-Za-z0-9]|eyJ[A-Za-z0-9_-]{10}')
Check 'harness: sends no SQL writes to auth.* of its own' `
  (@([regex]::Matches($harnessCode, '(?i)(insert\s+into|update|delete\s+from)\s+auth\.users') | Where-Object {
    # The refusal pattern itself names these words; it is a detector, not a query.
    $harnessCode.Substring([Math]::Max(0, $_.Index - 40), [Math]::Min(80, $harnessCode.Length - [Math]::Max(0, $_.Index - 40))) -notmatch '\$authWrite'
  }).Count -eq 0)

# --- harness transport: explicit UTF-8 keeps non-ASCII intact (EAR-3B run 1) ---
# Run 1 sent the SQL as a string body; Windows PowerShell 5.1 encoded it in a
# single-byte code page, each emoji arrived as two characters, and P-6's 10,000
# code points became 20,000. These checks exercise the harness's own function.
$sendFn = [regex]::Match($harnessCode, '(?ms)^function Invoke-ProjectSql.*?^\}').Value
Check 'transport: Invoke-ProjectSql found in harness' ([bool]$sendFn)
Check 'transport: body built with UTF8.GetBytes' ($sendFn -match '\[Text\.Encoding\]::UTF8\.GetBytes\(')
Check 'transport: content type declares charset=utf-8' ($sendFn -match "application/json; charset=utf-8")
Check 'transport: no string body passed to Invoke-RestMethod' ($sendFn -notmatch '-Body\s+\(@\{|-Body\s+\$json\b')

if ($sendFn) {
  $script:captured = $null
  function Invoke-RestMethod {
    param($Method, $Uri, $Headers, $ContentType, $Body)
    $script:captured = [pscustomobject]@{ Body = $Body; ContentType = $ContentType }
    return @()
  }
  # Read by the extracted Invoke-ProjectSql through dynamic scope.
  $ref = 'aaaaaaaaaaaaaaaaaaaa'
  $mgmt = @{ Authorization = 'Bearer not-a-real-token' }
  Invoke-Expression $sendFn

  $grin = [char]::ConvertFromUtf32(0x1F600)
  $eAcute = [string][char]0x00E9
  $query = "select repeat('$grin', 10000) as p6, 'caf$eAcute' as accent, 'Kod log masuk TINDAK' as ascii"
  Invoke-ProjectSql $query | Out-Null

  $body = $script:captured.Body
  Check 'transport: request body is a byte array' ($body -is [byte[]])
  Check 'transport: content type sent with charset=utf-8' ($script:captured.ContentType -eq 'application/json; charset=utf-8')
  if ($body -is [byte[]]) {
    $decoded = ([Text.Encoding]::UTF8.GetString($body) | ConvertFrom-Json).query
    Check 'transport: decoded query identical to the one sent (emoji + accent)' ($decoded -ceq $query)
    $grinBytes = [Text.Encoding]::UTF8.GetBytes($grin)
    $hex = ([BitConverter]::ToString($body))
    Check 'transport: emoji travels as its 4 UTF-8 bytes F0-9F-98-80' ($hex.Contains(([BitConverter]::ToString($grinBytes))))
    Check 'transport: no replacement question marks introduced' (([Text.Encoding]::UTF8.GetString($body)) -notmatch "repeat\('\?\?'")
  }
  Remove-Item Function:\Invoke-RestMethod
  Remove-Item Function:\Invoke-ProjectSql
}

# The fixture's own boundary literals are one code point each, so 10,000 and
# 10,001 repeats mean exactly that many code points once transport is correct.
foreach ($n in 10000, 10001) {
  $lit = [regex]::Match($sql, "repeat\('([^']+)', $n\)").Groups[1].Value
  $cp = if ($lit) { [Globalization.StringInfo]::new($lit).LengthInTextElements } else { -1 }
  $isGrin = ($lit -eq [char]::ConvertFromUtf32(0x1F600))
  Check "fixture: repeat literal for $n is one code point U+1F600 (text elements=$cp)" (($cp -eq 1) -and $isGrin)
}

# --- harness: behaviour without confirmation (no network, empty repo root) ---
$emptyRoot = Join-Path ([IO.Path]::GetTempPath()) ('tindak-rls-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $emptyRoot | Out-Null
try {
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $harnessPath -RepoRoot $emptyRoot 2>&1 | Out-String
  $code = $LASTEXITCODE
  Check "harness: without -ConfirmLiveRun exits 4 (got $code)" ($code -eq 4)
  Check 'harness: without -ConfirmLiveRun says REFUSED' ($out -match 'REFUSED')
} finally {
  Remove-Item -LiteralPath $emptyRoot -Recurse -Force
}

Write-Output ''
if ($failures.Count -gt 0) {
  Write-Output "FAILED: $($failures.Count)"
  $failures | ForEach-Object { Write-Output "  - $_" }
  exit 1
}
Write-Output 'ALL RLS FIXTURE TESTS PASSED'
exit 0
