<#
TINDAK - pre-release auth preflight (EAR-3A)

WHAT IT IS
  A read-only check that the live Supabase Auth configuration still matches the
  approved External Alpha baseline, run before every APK distribution and before
  every tester onboarding wave. It exists because ALPHA-001 happened: the code
  was right, and sign-in still broke, because the SMTP and template settings had
  silently gone back to Supabase defaults.

WHAT IT NEVER DOES
  - It never changes anything. No PATCH, no fix-up, no retry. Detection only.
  - It never sends an auth request, so it never spends email quota and never
    creates a user.
  - It never prints a secret: no PAT, DB password, SMTP password, service-role
    or secret key, no complete digest, and no user email. Secrets are compared
    in memory, by fingerprint.
  - It never runs supabase/tests/rls_memories.sql. A23 reads the catalog only.
  - It never deletes a user. A24 only counts AUTH-R01 candidates.

HOW TO RUN (from the repository root)
  powershell -ExecutionPolicy Bypass -File supabase/scripts/preflight-auth.ps1

  Reads SUPABASE_ACCESS_TOKEN from supabase/.env, the project ref from
  supabase/.temp/linked-project.json (both git-ignored), and the client values
  from mobile/.env.client (git-ignored). Nothing identifying the project is
  committed.

RESULT
  Exit 0 = no BLOCK. The release is still NO-GO until the manual checks B01-B03
  printed at the end are done by the CEO.
  Exit 2 = at least one BLOCK. Do not distribute.
  Exit 3 = the preflight itself could not run (missing file, API error).

TESTING
  -FixtureDir <dir> evaluates saved responses instead of calling the API, so
  the PASS/WARN/BLOCK rules can be exercised offline. Fixture files hold live
  digests and keys: keep them outside the repository and delete them after use.
#>
[CmdletBinding()]
param(
  [string]$RepoRoot,
  [string]$FixtureDir,
  # Tests only: lets synthetic fixtures stand in for the real SMTP digest.
  [string]$SmtpBaselineFingerprint = '8C6EB6AAA557'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

# Windows PowerShell 5.1 does not populate $PSScriptRoot in parameter defaults.
if (-not $RepoRoot) {
  $RepoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..')).Path
}

# --------------------------------------------------------------------------
# Approved baseline. Change only with Product Direction approval (EAR-3).
# --------------------------------------------------------------------------
$Expected = @{
  SmtpHost        = 'smtp.resend.com'
  SmtpPort        = '465'
  SmtpUser        = 'resend'
  SenderEmail     = 'auth@tindak.muhammedmunir.my'
  SenderName      = 'TINDAK'
  Subject         = 'Kod log masuk TINDAK'
  OtpLength       = 6
  OtpExpSeconds   = 3600
  EmailRatePerHour = 25
  MinOtpRate      = 30
  MinVerifyRate   = 30
  # 12-character SHA-256 fingerprint of the opaque smtp_pass digest the
  # Management API returns, captured after ALPHA-001 was restored and a real
  # OTP was delivered (FINAL-01). A drift detector, not proof of the credential.
  SmtpDigestFp    = $SmtpBaselineFingerprint
  UnverifiedRetentionDays = 7
}

# The approved OTP email body (ALPHA-001 restoration, PD-046). Compared exactly.
$ApprovedBody = @(
  '<h2>Kod log masuk TINDAK</h2>',
  '<p>Kod log masuk anda ialah <strong>{{ .Token }}</strong>.</p>',
  '<p>Masukkan kod ini dalam TINDAK untuk meneruskan.</p>',
  '<p>Jika anda tidak meminta kod ini, abaikan e-mel ini.</p>'
) -join "`n"

# Email OTP is the only approved auth method (PD-054). Any other provider or
# sign-in method turning on is a BLOCK until Product Direction approves it.
$ApprovedEnabledFlags = @('external_email_enabled')
$ProviderFlagPattern = '^(external_[a-z0-9_]+_enabled|saml_enabled|passkey_enabled|oauth_server_enabled|custom_oauth_enabled)$'

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
$Results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$Id, [string]$Status, [string]$Check, [string]$Detail) {
  $Results.Add([pscustomobject]@{ Id = $Id; Status = $Status; Check = $Check; Detail = $Detail })
}

function Test-Check([string]$Id, [bool]$Ok, [string]$FailStatus, [string]$Check, [string]$Detail) {
  if ($Ok) { Add-Result $Id 'PASS' $Check $Detail } else { Add-Result $Id $FailStatus $Check $Detail }
}

function Get-Fingerprint([string]$Value) {
  if ([string]::IsNullOrEmpty($Value)) { return '' }
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))
    return (([BitConverter]::ToString($bytes)) -replace '-', '').Substring(0, 12)
  } finally { $sha.Dispose() }
}

function Read-DotEnv([string]$Path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $values }
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { $values[$matches[1]] = $matches[2].Trim() }
  }
  return $values
}

function Stop-Preflight([string]$Message) {
  Write-Output "PREFLIGHT ERROR: $Message"
  exit 3
}

# Only single SELECT/WITH statements reach the database. Anything else is a bug
# in this script and must never run.
#
# This is a guard against mistakes in this file, not a proof that arbitrary SQL
# is harmless: the queries are constants below. A SELECT can still call a
# function with side effects, so the known ones, and every function in the
# application and auth schemas, are refused by name as well.
function Assert-ReadOnlySql([string]$Sql) {
  $stripped = ($Sql -replace "'[^']*'", "''")
  if ($stripped -notmatch '^\s*(select|with)\b') { throw 'refusing non-SELECT SQL' }
  if ($stripped.TrimEnd().TrimEnd(';') -match ';') { throw 'refusing multi-statement SQL' }
  if ($stripped -match '\b(insert|update|delete|merge|alter|drop|create|grant|revoke|truncate|comment|call|do|copy|vacuum|lock|set|reset)\b') {
    throw 'refusing SQL containing a write or session keyword'
  }
  if ($stripped -match '\b(set_config|pg_terminate_backend|pg_cancel_backend|nextval|setval|pg_advisory_\w+|lo_\w+|dblink\w*|pg_reload_conf|pg_rotate_logfile|pg_notify|http\w*|net\.\w+)\s*\(') {
    throw 'refusing SQL calling a function with side effects'
  }
  if ($stripped -match '\b(public|auth|storage|cron|vault)\.\w+\s*\(') {
    throw 'refusing SQL calling an application or platform function'
  }
}

$Sql = @{
  Rls = @'
select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       (select count(*) from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname) as policies,
       (select count(*) from information_schema.role_table_grants g
          where g.table_schema = 'public' and g.table_name = c.relname and g.grantee = 'anon') as anon_grants
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
  and c.relname in ('memories', 'memory_entities', 'reputation_usage')
order by c.relname
'@
  Unverified = @'
select count(*) as candidates
from auth.users u
where u.email_confirmed_at is null
  and u.last_sign_in_at is null
  and coalesce(u.is_anonymous, false) = false
  and u.created_at < now() - make_interval(days => __DAYS__)
  and not exists (select 1 from public.memories m where m.user_id = u.id)
  and not exists (select 1 from public.memory_entities e where e.user_id = u.id)
  and not exists (select 1 from public.reputation_usage r where r.user_id = u.id)
  and not exists (select 1 from auth.sessions s where s.user_id = u.id)
'@
}
$Sql.Unverified = $Sql.Unverified.Replace('__DAYS__', [string]$Expected.UnverifiedRetentionDays)

# --------------------------------------------------------------------------
# Inputs: live API, or saved fixtures
# --------------------------------------------------------------------------
$clientEnvPath = Join-Path $RepoRoot 'mobile\.env.client'

if ($FixtureDir) {
  function Import-Fixture([string]$Name) {
    $p = Join-Path $FixtureDir $Name
    if (-not (Test-Path -LiteralPath $p)) { Stop-Preflight "fixture missing: $Name" }
    foreach ($item in (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json)) { $item }
  }
  $ProjectRef = (Import-Fixture 'project.json').id
  $Project    = Import-Fixture 'project.json'
  $Auth       = Import-Fixture 'auth.json'
  $ApiKeys    = @(Import-Fixture 'api-keys.json')
  $Functions  = @(Import-Fixture 'functions.json')
  $Secrets    = @(Import-Fixture 'secrets.json')
  $RlsRows    = @(Import-Fixture 'sql-rls.json')
  $Unverified = Import-Fixture 'sql-unverified.json'
  $Legacy     = Import-Fixture 'legacy.json'
  $clientEnvPath = Join-Path $FixtureDir 'client.env'
  $Mode = 'FIXTURE'
} else {
  $envValues = Read-DotEnv (Join-Path $RepoRoot 'supabase\.env')
  $token = $envValues['SUPABASE_ACCESS_TOKEN']
  if (-not $token) { Stop-Preflight 'SUPABASE_ACCESS_TOKEN not found in supabase/.env' }

  $linked = Join-Path $RepoRoot 'supabase\.temp\linked-project.json'
  if (-not (Test-Path -LiteralPath $linked)) { Stop-Preflight 'supabase/.temp/linked-project.json not found (run supabase link)' }
  $ProjectRef = (Get-Content -LiteralPath $linked -Raw | ConvertFrom-Json).ref
  if ($ProjectRef -notmatch '^[a-z0-9]{20}$') { Stop-Preflight 'project ref in linked-project.json is not valid' }

  $headers = @{ Authorization = "Bearer $token" }
  # Windows PowerShell 5.1 hands a JSON array back as one Object[] instead of
  # enumerating it. Emitting each element flattens that one level, and leaves a
  # single JSON object unchanged.
  function Get-Api([string]$Path) {
    try {
      $response = Invoke-RestMethod -Method Get -Uri "https://api.supabase.com$Path" -Headers $headers
      foreach ($item in $response) { $item }
    }
    catch {
      $code = $null
      if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
      Stop-Preflight "Management API GET failed: HTTP $code"
    }
  }
  function Invoke-ReadOnlySql([string]$Query) {
    Assert-ReadOnlySql $Query
    try {
      $response = Invoke-RestMethod -Method Post -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" `
        -Headers $headers -ContentType 'application/json' -Body (@{ query = $Query } | ConvertTo-Json)
      foreach ($item in $response) { $item }
    } catch {
      $code = $null
      if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
      Stop-Preflight "read-only SQL failed: HTTP $code"
    }
  }

  $Project    = Get-Api "/v1/projects/$ProjectRef"
  $Auth       = Get-Api "/v1/projects/$ProjectRef/config/auth"
  $ApiKeys    = @(Get-Api "/v1/projects/$ProjectRef/api-keys")
  $Functions  = @(Get-Api "/v1/projects/$ProjectRef/functions")
  $Secrets    = @(Get-Api "/v1/projects/$ProjectRef/secrets")
  $Legacy     = Get-Api "/v1/projects/$ProjectRef/api-keys/legacy"
  $RlsRows    = @(Invoke-ReadOnlySql $Sql.Rls)
  $Unverified = @(Invoke-ReadOnlySql $Sql.Unverified)[0]
  $Mode = 'LIVE'
}

function Get-AuthValue([string]$Name) {
  $prop = $Auth.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $null }
  return $prop.Value
}

# --------------------------------------------------------------------------
# A - automated checks
# --------------------------------------------------------------------------

# A01 project reachable and running (a paused project is a total outage)
Test-Check 'A01' ($Project.status -eq 'ACTIVE_HEALTHY') 'BLOCK' 'project status' "status=$($Project.status)"

# A02-A04 custom SMTP
$smtpHost = [string](Get-AuthValue 'smtp_host')
$smtpPort = [string](Get-AuthValue 'smtp_port')
$smtpUser = [string](Get-AuthValue 'smtp_user')
Test-Check 'A02' (($smtpHost -eq $Expected.SmtpHost) -and ($smtpPort -eq $Expected.SmtpPort) -and ($smtpUser -eq $Expected.SmtpUser)) 'BLOCK' `
  'custom SMTP host/port/user' "host=$smtpHost port=$smtpPort user=$smtpUser"

$senderEmail = [string](Get-AuthValue 'smtp_admin_email')
$senderName = [string](Get-AuthValue 'smtp_sender_name')
Test-Check 'A03' (($senderEmail -eq $Expected.SenderEmail) -and ($senderName -eq $Expected.SenderName)) 'BLOCK' `
  'sender' "$senderName <$senderEmail>"

$smtpPass = [string](Get-AuthValue 'smtp_pass')
Test-Check 'A04' (-not [string]::IsNullOrEmpty($smtpPass)) 'BLOCK' 'SMTP password present' "set=$(-not [string]::IsNullOrEmpty($smtpPass))"

# A05 SMTP credential drift. The value is never shown, only whether it moved.
$digestMatches = (Get-Fingerprint $smtpPass) -eq $Expected.SmtpDigestFp
$smtpPass = $null
Test-Check 'A05' $digestMatches 'BLOCK' 'SMTP credential unchanged since approved baseline' `
  $(if ($digestMatches) { 'matches baseline' } else { 'CHANGED - BLOCK until B03 real OTP passes and PD approves a new baseline' })

# A06-A09 OTP email templates
$subjectMagic = [string](Get-AuthValue 'mailer_subjects_magic_link')
$subjectConfirm = [string](Get-AuthValue 'mailer_subjects_confirmation')
Test-Check 'A06' (($subjectMagic -eq $Expected.Subject) -and ($subjectConfirm -eq $Expected.Subject)) 'BLOCK' `
  'OTP email subjects' "magic_link='$subjectMagic' confirmation='$subjectConfirm'"

$bodyMagic = [string](Get-AuthValue 'mailer_templates_magic_link_content')
$bodyConfirm = [string](Get-AuthValue 'mailer_templates_confirmation_content')
$approvedFp = Get-Fingerprint $ApprovedBody
Test-Check 'A07' (((Get-Fingerprint $bodyMagic) -eq $approvedFp) -and ((Get-Fingerprint $bodyConfirm) -eq $approvedFp)) 'BLOCK' `
  'OTP email bodies exactly match approved copy' "magic_link=$((Get-Fingerprint $bodyMagic) -eq $approvedFp) confirmation=$((Get-Fingerprint $bodyConfirm) -eq $approvedFp)"

$tokenRe = '\{\{\s*\.Token\s*\}\}'
$linkRe = 'ConfirmationURL|TokenHash|RedirectTo|SiteURL'
$templatesSafe = ($bodyMagic -match $tokenRe) -and ($bodyConfirm -match $tokenRe) -and ($bodyMagic -notmatch $linkRe) -and ($bodyConfirm -notmatch $linkRe)
Test-Check 'A08' $templatesSafe 'BLOCK' 'OTP templates carry the code and no sign-in link' `
  "token=$(($bodyMagic -match $tokenRe) -and ($bodyConfirm -match $tokenRe)) link=$(($bodyMagic -match $linkRe) -or ($bodyConfirm -match $linkRe))"

$customSubjects = Get-AuthValue 'mailer_subjects_custom_contents'
$customTemplates = Get-AuthValue 'mailer_templates_custom_contents'
function Get-Flag($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $p = $Object.PSObject.Properties[$Name]
  if ($null -eq $p) { return $false }
  return [bool]$p.Value
}
$customOk = (Get-Flag $customSubjects 'MAILER_SUBJECTS_MAGIC_LINK') -and (Get-Flag $customSubjects 'MAILER_SUBJECTS_CONFIRMATION') -and `
            (Get-Flag $customTemplates 'MAILER_TEMPLATES_MAGIC_LINK_CONTENT') -and (Get-Flag $customTemplates 'MAILER_TEMPLATES_CONFIRMATION_CONTENT')
Test-Check 'A09' $customOk 'BLOCK' 'OTP templates marked custom (not platform default)' "custom=$customOk"

# A10-A12 OTP and rate limits
$otpLength = [int](Get-AuthValue 'mailer_otp_length')
$otpExp = [int](Get-AuthValue 'mailer_otp_exp')
Test-Check 'A10' (($otpLength -eq $Expected.OtpLength) -and ($otpExp -eq $Expected.OtpExpSeconds)) 'BLOCK' `
  'OTP length / expiry' "length=$otpLength exp=$otpExp"

$emailRate = [int](Get-AuthValue 'rate_limit_email_sent')
if ($emailRate -eq $Expected.EmailRatePerHour) { Add-Result 'A11' 'PASS' 'email rate per hour' "rate=$emailRate" }
elseif ($emailRate -lt $Expected.EmailRatePerHour) { Add-Result 'A11' 'BLOCK' 'email rate per hour' "rate=$emailRate (below approved $($Expected.EmailRatePerHour))" }
else { Add-Result 'A11' 'WARN' 'email rate per hour' "rate=$emailRate (above approved $($Expected.EmailRatePerHour); needs PD approval)" }

$otpRate = [int](Get-AuthValue 'rate_limit_otp')
$verifyRate = [int](Get-AuthValue 'rate_limit_verify')
Test-Check 'A12' (($otpRate -ge $Expected.MinOtpRate) -and ($verifyRate -ge $Expected.MinVerifyRate)) 'WARN' `
  'OTP / verify rate' "otp=$otpRate verify=$verifyRate"

# A13-A17 sign-in behaviour
Test-Check 'A13' (([bool](Get-AuthValue 'external_email_enabled')) -and -not ([bool](Get-AuthValue 'disable_signup'))) 'BLOCK' `
  'email sign-in on, sign-up allowed' "email=$(Get-AuthValue 'external_email_enabled') disable_signup=$(Get-AuthValue 'disable_signup')"
Test-Check 'A14' ((-not [bool](Get-AuthValue 'mailer_autoconfirm')) -and -not ([bool](Get-AuthValue 'mailer_allow_unverified_email_sign_ins'))) 'BLOCK' `
  'email must be verified by code' "autoconfirm=$(Get-AuthValue 'mailer_autoconfirm') allow_unverified=$(Get-AuthValue 'mailer_allow_unverified_email_sign_ins')"
Test-Check 'A15' (-not [bool](Get-AuthValue 'external_anonymous_users_enabled')) 'BLOCK' `
  'anonymous sign-in off' "anonymous=$(Get-AuthValue 'external_anonymous_users_enabled')"
Test-Check 'A16' (-not [bool](Get-AuthValue 'security_captcha_enabled')) 'BLOCK' `
  'captcha off (app sends no captcha token)' "captcha=$(Get-AuthValue 'security_captcha_enabled')"
$hooksOn = @('hook_send_email_enabled', 'hook_before_user_created_enabled', 'hook_custom_access_token_enabled') |
  Where-Object { [bool](Get-AuthValue $_) }
Test-Check 'A17' (@($hooksOn).Count -eq 0) 'BLOCK' 'auth hooks that can bypass SMTP or break sign-in are off' `
  $(if (@($hooksOn).Count -eq 0) { 'none enabled' } else { 'enabled: ' + ($hooksOn -join ',') })

# A18 no unapproved auth provider or sign-in method (PD-054: email OTP only)
$unapproved = @($Auth.PSObject.Properties | Where-Object {
  $_.Name -match $ProviderFlagPattern -and $ApprovedEnabledFlags -notcontains $_.Name -and [bool]$_.Value
} | ForEach-Object { $_.Name })
Test-Check 'A18' ($unapproved.Count -eq 0) 'BLOCK' 'no unapproved auth provider enabled' `
  $(if ($unapproved.Count -eq 0) { 'email OTP only' } else { 'enabled without approval: ' + ($unapproved -join ',') })

# A19 site_url (PD-054: localhost accepted as WARN for the OTP-only flow)
$siteUrl = [string](Get-AuthValue 'site_url')
Test-Check 'A19' (($siteUrl -match '^https://') -and ($siteUrl -notmatch 'localhost|127\.0\.0\.1')) 'WARN' `
  'site_url is a real HTTPS URL' "site_url=$siteUrl (PD-054: accepted temporarily)"

# A20 the app build points at this project with a key the project still has
$client = Read-DotEnv $clientEnvPath
$clientUrlOk = ($client['SUPABASE_URL'] -eq "https://$ProjectRef.supabase.co")
$publishable = @($ApiKeys | Where-Object { $_.type -eq 'publishable' } | ForEach-Object { [string]$_.api_key })
$clientKeyOk = ($client['SUPABASE_ANON_KEY'] -and ($publishable -contains $client['SUPABASE_ANON_KEY']))
$client = $null
Test-Check 'A20' ($clientUrlOk -and $clientKeyOk) 'BLOCK' 'mobile/.env.client URL and publishable key match the project' `
  "url_match=$clientUrlOk key_present_in_project=$([bool]$clientKeyOk)"
$publishable = $null

# A21 legacy JWT keys (url-check still depends on them)
Test-Check 'A21' ([bool]$Legacy.enabled) 'WARN' 'legacy JWT keys enabled (url-check dependency)' "enabled=$($Legacy.enabled)"

# A22 url-check deployed; Web Risk key absent is expected (PD-047), never a block
$urlCheck = @($Functions | Where-Object { $_.slug -eq 'url-check' })
$urlCheckActive = $false
if ($urlCheck.Count -eq 1) { $urlCheckActive = ($urlCheck[0].status -eq 'ACTIVE') }
$webRiskSecret = @($Secrets | Where-Object { $_.name -eq 'WEB_RISK_API_KEY' }).Count -gt 0
if ($urlCheckActive -and -not $webRiskSecret) {
  Add-Result 'A22' 'INFO' 'url-check deployed, Web Risk key absent' 'expected under PD-047'
} else {
  Add-Result 'A22' 'WARN' 'url-check / Web Risk state' "url_check_active=$urlCheckActive web_risk_key_present=$webRiskSecret"
}

# A23 RLS still on, policy counts unchanged, anon has no table access
$expectedPolicies = @{ memories = 3; memory_entities = 2; reputation_usage = 0 }
$rlsProblems = New-Object System.Collections.Generic.List[string]
foreach ($t in $expectedPolicies.Keys) {
  $row = @($RlsRows | Where-Object { $_.table_name -eq $t })
  if ($row.Count -ne 1) { $rlsProblems.Add("$t missing"); continue }
  if (-not [bool]$row[0].rls_enabled) { $rlsProblems.Add("$t rls off") }
  if ([int]$row[0].policies -ne $expectedPolicies[$t]) { $rlsProblems.Add("$t policies=$($row[0].policies)") }
  if ([int]$row[0].anon_grants -ne 0) { $rlsProblems.Add("$t anon_grants=$($row[0].anon_grants)") }
}
Test-Check 'A23' ($rlsProblems.Count -eq 0) 'BLOCK' 'RLS on, policy counts 3/2/0, no anon table grants' `
  $(if ($rlsProblems.Count -eq 0) { 'catalog matches (fixture not run)' } else { $rlsProblems -join '; ' })

# A24 AUTH-R01 candidates: counted, never deleted
$candidates = [int]$Unverified.candidates
Test-Check 'A24' ($candidates -eq 0) 'WARN' "unverified OTP users older than $($Expected.UnverifiedRetentionDays) days with no data" `
  "candidates=$candidates (AUTH-R01: manual, CEO-approved cleanup only)"

# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
$blocks = @($Results | Where-Object { $_.Status -eq 'BLOCK' }).Count
$warns = @($Results | Where-Object { $_.Status -eq 'WARN' }).Count

Write-Output ("PREFLIGHT AUTH  {0}  mode={1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Mode)
foreach ($r in $Results) { Write-Output ("{0}  {1,-5}  {2} :: {3}" -f $r.Id, $r.Status, $r.Check, $r.Detail) }
Write-Output ''
Write-Output 'MANUAL (CEO) - required before distribution:'
Write-Output '  B01  Resend: domain tindak.muhammedmunir.my is Verified                       BLOCK if not'
Write-Output '  B02  Resend: key tindak-m5b-rotated present with Sending access               BLOCK if not'
Write-Output '  B03  One real OTP: arrives from TINDAK, subject correct, 6 digits, accepted   BLOCK if not'
Write-Output '  B04  Resend: SMTP key "Last used" updated after B03                           WARN if not'
Write-Output '  B05  Onboarding at most 5 testers per hour (B03 counts toward the 25/hour)'
Write-Output ''
Write-Output ("SUMMARY  blocks={0} warns={1}" -f $blocks, $warns)
if ($blocks -gt 0) {
  Write-Output 'RESULT   NO-GO'
  exit 2
}
Write-Output 'RESULT   automated checks clear - GO only after B01-B03 pass'
exit 0
