<#
TINDAK - tests for preflight-auth.ps1 (EAR-3A)

Runs the preflight against synthetic fixtures only. Every value here is fake:
no project ref, key, digest or email in this file belongs to a real system, and
no network call is made.

  powershell -ExecutionPolicy Bypass -File supabase/scripts/preflight-auth.tests.ps1

Exit 0 when every case passes, 1 otherwise.
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$scriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'preflight-auth.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('tindak-preflight-tests-' + [guid]::NewGuid().ToString('N'))

$FakeRef = 'abcdefghijklmnopqrst'
$FakeDigest = 'fake-smtp-digest-value-not-a-secret'
$FakePublishable = 'sb_publishable_FAKEFAKEFAKEFAKE'

function Get-Fingerprint([string]$Value) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { (([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))) -replace '-', '').Substring(0, 12) }
  finally { $sha.Dispose() }
}
$FakeDigestFp = Get-Fingerprint $FakeDigest

$ApprovedBody = @(
  '<h2>Kod log masuk TINDAK</h2>',
  '<p>Kod log masuk anda ialah <strong>{{ .Token }}</strong>.</p>',
  '<p>Masukkan kod ini dalam TINDAK untuk meneruskan.</p>',
  '<p>Jika anda tidak meminta kod ini, abaikan e-mel ini.</p>'
) -join "`n"

function New-Baseline {
  [ordered]@{
    'project.json' = [ordered]@{ id = $FakeRef; status = 'ACTIVE_HEALTHY' }
    'auth.json' = [ordered]@{
      smtp_host = 'smtp.resend.com'; smtp_port = '465'; smtp_user = 'resend'; smtp_pass = $FakeDigest
      smtp_admin_email = 'auth@tindak.muhammedmunir.my'; smtp_sender_name = 'TINDAK'
      mailer_subjects_magic_link = 'Kod log masuk TINDAK'; mailer_subjects_confirmation = 'Kod log masuk TINDAK'
      mailer_templates_magic_link_content = $ApprovedBody; mailer_templates_confirmation_content = $ApprovedBody
      mailer_subjects_custom_contents = [ordered]@{ MAILER_SUBJECTS_MAGIC_LINK = $true; MAILER_SUBJECTS_CONFIRMATION = $true }
      mailer_templates_custom_contents = [ordered]@{ MAILER_TEMPLATES_MAGIC_LINK_CONTENT = $true; MAILER_TEMPLATES_CONFIRMATION_CONTENT = $true }
      mailer_otp_length = 6; mailer_otp_exp = 3600
      rate_limit_email_sent = 25; rate_limit_otp = 30; rate_limit_verify = 30
      external_email_enabled = $true; disable_signup = $false
      mailer_autoconfirm = $false; mailer_allow_unverified_email_sign_ins = $false
      external_anonymous_users_enabled = $false; security_captcha_enabled = $false
      hook_send_email_enabled = $false; hook_before_user_created_enabled = $false; hook_custom_access_token_enabled = $false
      external_google_enabled = $false; external_apple_enabled = $false; external_phone_enabled = $false
      saml_enabled = $false; passkey_enabled = $false; oauth_server_enabled = $false; custom_oauth_enabled = $false
      site_url = 'http://localhost:3000'
    }
    'api-keys.json' = @(
      [ordered]@{ name = 'anon'; type = 'legacy'; api_key = 'fake-legacy-anon' },
      [ordered]@{ name = 'default'; type = 'publishable'; api_key = $FakePublishable }
    )
    'functions.json' = @([ordered]@{ slug = 'url-check'; status = 'ACTIVE' })
    'secrets.json' = @([ordered]@{ name = 'SUPABASE_URL' }, [ordered]@{ name = 'SUPABASE_ANON_KEY' })
    'legacy.json' = [ordered]@{ enabled = $true }
    'sql-rls.json' = @(
      [ordered]@{ table_name = 'memories'; rls_enabled = $true; policies = 3; anon_grants = 0 },
      [ordered]@{ table_name = 'memory_entities'; rls_enabled = $true; policies = 2; anon_grants = 0 },
      [ordered]@{ table_name = 'reputation_usage'; rls_enabled = $true; policies = 0; anon_grants = 0 }
    )
    'sql-unverified.json' = [ordered]@{ candidates = 0 }
    'client.env' = "SUPABASE_URL=https://$FakeRef.supabase.co`nSUPABASE_ANON_KEY=$FakePublishable`n"
  }
}

function Invoke-Case([string]$Name, [scriptblock]$Mutate) {
  $fixture = New-Baseline
  if ($Mutate) { & $Mutate $fixture }
  $dir = Join-Path $work ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $dir | Out-Null
  foreach ($file in $fixture.Keys) {
    $path = Join-Path $dir $file
    if ($file -eq 'client.env') { [IO.File]::WriteAllText($path, $fixture[$file]) }
    else { [IO.File]::WriteAllText($path, (ConvertTo-Json -InputObject $fixture[$file] -Depth 6)) }
  }
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -FixtureDir $dir -SmtpBaselineFingerprint $FakeDigestFp 2>&1
  [pscustomobject]@{ Name = $Name; Exit = $LASTEXITCODE; Output = ($output | Out-String) }
}

function Status-Of($Run, [string]$Id) {
  $m = [regex]::Match($Run.Output, "(?m)^$Id\s+(\S+)")
  if ($m.Success) { $m.Groups[1].Value } else { '<missing>' }
}

$failures = New-Object System.Collections.Generic.List[string]
function Expect($Run, [string]$Id, [string]$Status, [int]$ExitCode) {
  $got = Status-Of $Run $Id
  $ok = ($got -eq $Status) -and ($Run.Exit -eq $ExitCode)
  $label = if ($ok) { 'ok  ' } else { 'FAIL' }
  Write-Output ("{0} {1,-44} {2} expected {3}/exit {4}, got {5}/exit {6}" -f $label, $Run.Name, $Id, $Status, $ExitCode, $got, $Run.Exit)
  if (-not $ok) { $failures.Add("$($Run.Name) $Id") }
}

try {
  New-Item -ItemType Directory -Path $work | Out-Null

  $base = Invoke-Case 'baseline' $null
  foreach ($id in 'A01','A02','A03','A04','A05','A06','A07','A08','A09','A10','A11','A12','A13','A14','A15','A16','A17','A18','A20','A21','A23','A24') {
    Expect $base $id 'PASS' 0
  }
  Expect $base 'A19' 'WARN' 0
  Expect $base 'A22' 'INFO' 0

  # --- hygiene: nothing secret or identifying reaches the output ---
  foreach ($secret in @($FakeDigest, $FakePublishable, 'fake-legacy-anon', $FakeDigestFp)) {
    $leak = $base.Output.Contains($secret)
    $label = if ($leak) { 'FAIL' } else { 'ok  ' }
    Write-Output ("{0} {1,-44} output does not contain a fixture secret" -f $label, 'baseline')
    if ($leak) { $failures.Add('secret printed') }
  }

  # --- every BLOCK rule actually blocks ---
  Expect (Invoke-Case 'project paused' { param($f) $f['project.json'].status = 'INACTIVE' }) 'A01' 'BLOCK' 2
  Expect (Invoke-Case 'SMTP removed (ALPHA-001)' { param($f) $f['auth.json'].smtp_host = '' }) 'A02' 'BLOCK' 2
  Expect (Invoke-Case 'sender changed' { param($f) $f['auth.json'].smtp_admin_email = 'noreply@mail.app.supabase.io' }) 'A03' 'BLOCK' 2
  Expect (Invoke-Case 'SMTP password cleared' { param($f) $f['auth.json'].smtp_pass = '' }) 'A04' 'BLOCK' 2
  Expect (Invoke-Case 'SMTP credential changed' { param($f) $f['auth.json'].smtp_pass = 'a-different-digest' }) 'A05' 'BLOCK' 2
  Expect (Invoke-Case 'subject reverted' { param($f) $f['auth.json'].mailer_subjects_magic_link = 'Your sign-in link' }) 'A06' 'BLOCK' 2

  $default = Invoke-Case 'template reverted to magic link (ALPHA-001)' {
    param($f)
    $f['auth.json'].mailer_templates_magic_link_content = '<h2>Magic Link</h2><p><a href="{{ .ConfirmationURL }}">Log In</a></p>'
    $f['auth.json'].mailer_templates_custom_contents.MAILER_TEMPLATES_MAGIC_LINK_CONTENT = $false
  }
  Expect $default 'A07' 'BLOCK' 2
  Expect $default 'A08' 'BLOCK' 2
  Expect $default 'A09' 'BLOCK' 2

  Expect (Invoke-Case 'OTP length 8 (platform default)' { param($f) $f['auth.json'].mailer_otp_length = 8 }) 'A10' 'BLOCK' 2
  Expect (Invoke-Case 'email rate dropped to 2' { param($f) $f['auth.json'].rate_limit_email_sent = 2 }) 'A11' 'BLOCK' 2
  Expect (Invoke-Case 'email sign-up disabled' { param($f) $f['auth.json'].disable_signup = $true }) 'A13' 'BLOCK' 2
  Expect (Invoke-Case 'autoconfirm on' { param($f) $f['auth.json'].mailer_autoconfirm = $true }) 'A14' 'BLOCK' 2
  Expect (Invoke-Case 'anonymous sign-in on' { param($f) $f['auth.json'].external_anonymous_users_enabled = $true }) 'A15' 'BLOCK' 2
  Expect (Invoke-Case 'captcha on' { param($f) $f['auth.json'].security_captcha_enabled = $true }) 'A16' 'BLOCK' 2
  Expect (Invoke-Case 'send-email hook on' { param($f) $f['auth.json'].hook_send_email_enabled = $true }) 'A17' 'BLOCK' 2
  Expect (Invoke-Case 'Google provider enabled' { param($f) $f['auth.json'].external_google_enabled = $true }) 'A18' 'BLOCK' 2
  Expect (Invoke-Case 'phone provider enabled' { param($f) $f['auth.json'].external_phone_enabled = $true }) 'A18' 'BLOCK' 2
  Expect (Invoke-Case 'client key rotated away' { param($f) $f['client.env'] = "SUPABASE_URL=https://$FakeRef.supabase.co`nSUPABASE_ANON_KEY=sb_publishable_OTHER`n" }) 'A20' 'BLOCK' 2
  Expect (Invoke-Case 'client points at another project' { param($f) $f['client.env'] = "SUPABASE_URL=https://zzzzzzzzzzzzzzzzzzzz.supabase.co`nSUPABASE_ANON_KEY=$FakePublishable`n" }) 'A20' 'BLOCK' 2
  Expect (Invoke-Case 'RLS turned off' { param($f) $f['sql-rls.json'][0].rls_enabled = $false }) 'A23' 'BLOCK' 2
  Expect (Invoke-Case 'policy removed' { param($f) $f['sql-rls.json'][0].policies = 2 }) 'A23' 'BLOCK' 2
  Expect (Invoke-Case 'anon granted table access' { param($f) $f['sql-rls.json'][1].anon_grants = 1 }) 'A23' 'BLOCK' 2

  # --- WARN and INFO rules never block ---
  Expect (Invoke-Case 'email rate raised to 30' { param($f) $f['auth.json'].rate_limit_email_sent = 30 }) 'A11' 'WARN' 0
  Expect (Invoke-Case 'OTP rate lowered' { param($f) $f['auth.json'].rate_limit_otp = 10 }) 'A12' 'WARN' 0
  Expect (Invoke-Case 'site_url fixed' { param($f) $f['auth.json'].site_url = 'https://example.invalid' }) 'A19' 'PASS' 0
  Expect (Invoke-Case 'legacy JWT keys disabled' { param($f) $f['legacy.json'].enabled = $false }) 'A21' 'WARN' 0
  Expect (Invoke-Case 'Web Risk key present' { param($f) $f['secrets.json'] = @([ordered]@{ name = 'WEB_RISK_API_KEY' }) }) 'A22' 'WARN' 0
  Expect (Invoke-Case 'url-check missing' { param($f) $f['functions.json'] = @() }) 'A22' 'WARN' 0
  Expect (Invoke-Case 'AUTH-R01 candidates present' { param($f) $f['sql-unverified.json'].candidates = 3 }) 'A24' 'WARN' 0
}
finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}

# --- static guarantees about the preflight source itself ---
$source = Get-Content -LiteralPath $scriptPath -Raw
$static = [ordered]@{
  'no PATCH/PUT/DELETE requests'               = ($source -notmatch '-Method\s+(Patch|Put|Delete)')
  'only POST is the read-only SQL endpoint'    = @([regex]::Matches($source, '-Method\s+Post[^\r\n]*') | Where-Object { $_.Value -notmatch 'database/query' }).Count -eq 0
  'no auth endpoint calls'                     = ($source -notmatch '/auth/v1/')
  'does not reference the RLS fixture file'    = ($source -notmatch 'rls_memories\.sql"|rls_memories\.sql''|Get-Content[^\r\n]*rls_memories')
  'no project ref committed'                   = ($source -notmatch '[a-z]{20}\.supabase\.co')
  'no hard-coded token or key'                 = ($source -notmatch 'sbp_[0-9a-f]{10}|sb_secret_|re_[A-Za-z0-9]{8}_|eyJ[A-Za-z0-9_-]{10}')
  'SQL guard present'                          = ($source -match 'function Assert-ReadOnlySql')
}
foreach ($k in $static.Keys) {
  $label = if ($static[$k]) { 'ok  ' } else { 'FAIL' }
  Write-Output ("{0} static: {1}" -f $label, $k)
  if (-not $static[$k]) { $failures.Add("static: $k") }
}

# --- the SQL guard really refuses anything but a single SELECT ---
$guardSource = [regex]::Match($source, '(?ms)^function Assert-ReadOnlySql.*?^\}').Value
if (-not $guardSource) {
  Write-Output 'FAIL guard: Assert-ReadOnlySql not found'
  $failures.Add('guard missing')
} else {
  Invoke-Expression $guardSource
  $guardCases = [ordered]@{
    'select count(*) from public.memories'                         = $true
    "with x as (select 1) select * from x"                         = $true
    "select 'delete from x' as harmless_string"                    = $true
    'delete from auth.users'                                       = $false
    'insert into auth.users (id) values (gen_random_uuid())'        = $false
    'update public.memories set content = 1'                       = $false
    'select 1; delete from public.memories'                        = $false
    'with d as (delete from public.memories returning 1) select 1' = $false
    'alter table public.memories disable row level security'       = $false
    'drop table public.memories'                                   = $false
    'grant select on public.memories to anon'                      = $false
    "select set_config('role', 'postgres', false)"                 = $false
    'select pg_terminate_backend(123)'                             = $false
    "select nextval('some_seq')"                                   = $false
    "select public.push_memory(gen_random_uuid(), 'x')"            = $false
    'select public.consume_reputation_check(null, 60)'             = $false
    'select cron.schedule(1)'                                      = $false
    "select coalesce(null, 1), make_interval(days => 7)"           = $true
    'set role postgres'                                            = $false
    'do $$ begin perform 1; end $$'                                 = $false
  }
  foreach ($sql in $guardCases.Keys) {
    $allowed = $true
    try { Assert-ReadOnlySql $sql } catch { $allowed = $false }
    $ok = ($allowed -eq $guardCases[$sql])
    $label = if ($ok) { 'ok  ' } else { 'FAIL' }
    Write-Output ("{0} guard: {1,-7} {2}" -f $label, $(if ($guardCases[$sql]) { 'allow' } else { 'refuse' }), $sql)
    if (-not $ok) { $failures.Add("guard: $sql") }
  }
}

Write-Output ''
if ($failures.Count -gt 0) {
  Write-Output "FAILED: $($failures.Count)"
  $failures | ForEach-Object { Write-Output "  - $_" }
  exit 1
}
Write-Output 'ALL PREFLIGHT TESTS PASSED'
exit 0
