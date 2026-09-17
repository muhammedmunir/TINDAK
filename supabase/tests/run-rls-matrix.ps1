<#
TINDAK - RLS matrix harness (EAR-BLOCKER-01)

WHAT IT DOES
  1. Creates two throwaway users (rls-test-a-/b-<guid>@tindak.invalid) through
     the Supabase Auth Admin API. No email is sent and no quota is used.
  2. Runs supabase/tests/rls_memories.sql with their ids filled in.
  3. Deletes exactly those two users through the Auth Admin API, whatever
     happened in step 2, and confirms nothing of theirs is left (Z-2).

WHY IT EXISTS
  The SQL used to create its users with a direct INSERT into auth.users. A
  direct write like that broke sign-in for the whole project on 2026-09-16, and
  writing to auth.* by hand is now forbidden. Users are created and removed
  only through the supported Admin API.

IT WRITES TO THE PROJECT IT POINTS AT
  Two test users and their test rows, all removed at the end. Running it
  against the live project needs explicit Product Direction authorization, so
  it refuses to start without -ConfirmLiveRun.

HOW TO RUN (from the repository root, only when authorized)
  powershell -ExecutionPolicy Bypass -File supabase/tests/run-rls-matrix.ps1 -ConfirmLiveRun

  Reads SUPABASE_ACCESS_TOKEN from supabase/.env and the project ref from
  supabase/.temp/linked-project.json. The service-role key is fetched in memory
  and never printed.

EXIT CODES
  0 every check PASS   1 at least one FAIL   3 harness error   4 not confirmed
#>
[CmdletBinding()]
param(
  [switch]$ConfirmLiveRun,
  [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

if (-not $ConfirmLiveRun) {
  Write-Output 'REFUSED: this harness creates and deletes test users on a real Supabase project.'
  Write-Output '         Re-run with -ConfirmLiveRun only when Product Direction has authorized a live RLS run.'
  exit 4
}

if (-not $RepoRoot) {
  $RepoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..')).Path
}

function Stop-Harness([string]$Message) {
  Write-Output "HARNESS ERROR: $Message"
  exit 3
}

function Read-DotEnv([string]$Path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $values }
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $values[$matches[1]] = $matches[2].Trim() }
  }
  return $values
}

function Get-HttpStatus($ErrorRecord) {
  if ($ErrorRecord.Exception.Response) { return [int]$ErrorRecord.Exception.Response.StatusCode }
  return 0
}

# --------------------------------------------------------------------------
# Inputs
# --------------------------------------------------------------------------
$sqlPath = Join-Path $RepoRoot 'supabase\tests\rls_memories.sql'
if (-not (Test-Path -LiteralPath $sqlPath)) { Stop-Harness 'supabase/tests/rls_memories.sql not found' }
$sqlTemplate = [IO.File]::ReadAllText($sqlPath)

# The fixture must never write to the auth schema, whatever this harness does.
$authWrite = '(?im)\b(insert\s+into|update|delete\s+from|truncate)\s+auth\.'
if ($sqlTemplate -match $authWrite) { Stop-Harness 'rls_memories.sql writes to auth.* - refusing to run (EAR-BLOCKER-01)' }
foreach ($placeholder in '__RLS_TEST_USER_A__', '__RLS_TEST_USER_B__') {
  if (([regex]::Matches($sqlTemplate, [regex]::Escape($placeholder))).Count -ne 1) {
    Stop-Harness "rls_memories.sql must contain $placeholder exactly once"
  }
}

$envValues = Read-DotEnv (Join-Path $RepoRoot 'supabase\.env')
$token = $envValues['SUPABASE_ACCESS_TOKEN']
if (-not $token) { Stop-Harness 'SUPABASE_ACCESS_TOKEN not found in supabase/.env' }
$linked = Join-Path $RepoRoot 'supabase\.temp\linked-project.json'
if (-not (Test-Path -LiteralPath $linked)) { Stop-Harness 'supabase/.temp/linked-project.json not found' }
$ref = (Get-Content -LiteralPath $linked -Raw | ConvertFrom-Json).ref
if ($ref -notmatch '^[a-z0-9]{20}$') { Stop-Harness 'project ref in linked-project.json is not valid' }

$mgmt = @{ Authorization = "Bearer $token" }
$base = "https://$ref.supabase.co"

# The body goes out as explicit UTF-8 bytes. Windows PowerShell 5.1 sends a
# string -Body in a single-byte encoding, which turned every emoji in the
# fixture into two characters: P-6's 10,000 code points arrived as 20,000 and
# were refused (EAR-3B run 1).
function Invoke-ProjectSql([string]$Query) {
  $json = @{ query = $Query } | ConvertTo-Json
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $response = Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$ref/database/query" `
    -Headers $mgmt -ContentType 'application/json; charset=utf-8' -Body $bytes
  foreach ($item in $response) { $item }
}

# Service-role key for the Auth Admin API: fetched in memory, never printed.
try {
  $keys = @(Invoke-RestMethod -Method Get -Uri "https://api.supabase.com/v1/projects/$ref/api-keys?reveal=true" -Headers $mgmt | ForEach-Object { $_ })
} catch { Stop-Harness "could not read project API keys: HTTP $(Get-HttpStatus $_)" }
$adminKey = @($keys | Where-Object { $_.name -eq 'service_role' -and $_.api_key }) | Select-Object -First 1
if (-not $adminKey) { $adminKey = @($keys | Where-Object { $_.type -eq 'secret' -and $_.api_key }) | Select-Object -First 1 }
if (-not $adminKey) { Stop-Harness 'no service-role or secret key available for the Auth Admin API' }
$admin = @{ apikey = $adminKey.api_key; Authorization = "Bearer $($adminKey.api_key)" }
$keys = $null; $adminKey = $null

# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------
$created = New-Object System.Collections.Generic.List[string]
$failures = 0
$exitCode = 0

try {
  foreach ($label in 'a', 'b') {
    $email = "rls-test-$label-$([guid]::NewGuid().ToString('N'))@tindak.invalid"
    try {
      $user = Invoke-RestMethod -Method Post -Uri "$base/auth/v1/admin/users" -Headers $admin `
        -ContentType 'application/json' -Body (@{ email = $email; email_confirm = $true } | ConvertTo-Json)
    } catch { throw "Auth Admin API could not create test user ${label}: HTTP $(Get-HttpStatus $_)" }
    if ([string]$user.id -notmatch '^[0-9a-fA-F-]{36}$') { throw "Auth Admin API returned no id for test user $label" }
    $created.Add([string]$user.id)
  }
  Write-Output "created 2 test users through the Auth Admin API"

  $sql = $sqlTemplate.Replace('__RLS_TEST_USER_A__', $created[0]).Replace('__RLS_TEST_USER_B__', $created[1])
  if ($sql -match '__RLS_TEST_USER_[AB]__') { throw 'placeholder substitution failed' }

  try { $rows = @(Invoke-ProjectSql $sql) }
  catch {
    $detail = ''
    try { $detail = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch { }
    $detail = ($detail -replace '\s+', ' ')
    if ($detail.Length -gt 300) { $detail = $detail.Substring(0, 300) }
    throw "RLS SQL failed: HTTP $(Get-HttpStatus $_) $detail"
  }

  Write-Output ''
  Write-Output ('{0,-6} {1,-50} {2,-8}' -f 'ID', 'CHECK', 'RESULT')
  foreach ($r in $rows) {
    Write-Output ('{0,-6} {1,-50} {2,-8} expected: {3} | observed: {4}' -f $r.id, $r.check, $r.result, $r.expected, $r.observed)
    if ($r.result -ne 'PASS') { $failures++ }
  }
  if ($rows.Count -ne 32) {
    Write-Output "expected 32 checks from the SQL, got $($rows.Count)"
    $failures++
  }
}
catch {
  Write-Output "HARNESS ERROR: $($_.Exception.Message)"
  $exitCode = 3
}
finally {
  # Delete exactly the users this run created, and nothing else.
  $deleteFailed = 0
  foreach ($id in $created) {
    try { Invoke-RestMethod -Method Delete -Uri "$base/auth/v1/admin/users/$id" -Headers $admin | Out-Null }
    catch { $deleteFailed++; Write-Output "could not delete a test user through the Auth Admin API: HTTP $(Get-HttpStatus $_)" }
  }
  $admin = $null

  if ($created.Count -gt 0) {
    $idList = ($created | ForEach-Object { "'$_'" }) -join ','
    try {
      $left = @(Invoke-ProjectSql "select (select count(*) from auth.users where id in ($idList)) as users_left, (select count(*) from public.memories where user_id in ($idList)) as memories_left")[0]
      $clean = ($deleteFailed -eq 0) -and ([int]$left.users_left -eq 0) -and ([int]$left.memories_left -eq 0)
      Write-Output ('{0,-6} {1,-50} {2,-8} expected: 0 users, 0 memories | observed: {3} users, {4} memories' -f `
        'Z-2', 'test users removed via Auth Admin API', $(if ($clean) { 'PASS' } else { 'FAIL' }), $left.users_left, $left.memories_left)
      if (-not $clean) { $failures++ }
    } catch {
      Write-Output 'Z-2    could not confirm cleanup'
      $failures++
    }
  }
}

Write-Output ''
if ($exitCode -eq 3) { Write-Output 'RESULT   HARNESS ERROR'; exit 3 }
if ($failures -gt 0) { Write-Output "RESULT   FAIL ($failures)"; exit 1 }
Write-Output 'RESULT   PASS (32 checks + Z-2)'
exit 0
