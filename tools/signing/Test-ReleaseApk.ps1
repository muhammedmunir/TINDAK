<#
TINDAK - release APK verification (EAR-4B)

Proves an APK is signed with TINDAK's stable release identity and nothing else.
Needs no password and no private key: it reads only the public certificate.

  powershell -ExecutionPolicy Bypass -File tools/signing/Test-ReleaseApk.ps1 -ApkPath <path-to-apk>

CHECKS
  S1  apksigner verifies the APK
  S2  signed with APK Signature Scheme v2 or v3
  S3  exactly one signer
  S4  signer is NOT the Android debug certificate
  S5  signer certificate SHA-256 equals the approved release fingerprint
  S6  package is my.tindak.app
  S7  no secret patterns inside the APK (keys, tokens, JWTs, keystores, passwords)
  Reports versionCode, versionName and the APK file SHA-256 for the release record.

Exit 0 = all PASS, 1 = at least one FAIL, 3 = could not run.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ApkPath,
  [string]$AndroidSdk = 'C:\Android\sdk'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

# The approved TINDAK release certificate (tindak-release, CN=TINDAK, O=TINDAK,
# C=MY), created 2026-09-18. Public information: it is embedded in every APK.
$ExpectedSha256 = '85BB8731119AE7DCE7EEFB4F37CEE2916BD26BDF69C458126837FFD8096C67E0'
$ExpectedPackage = 'my.tindak.app'

function Stop-Verify([string]$Message) { Write-Output "VERIFY ERROR: $Message"; exit 3 }

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) { Stop-Verify "APK not found: $ApkPath" }
$buildTools = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
  Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } -Descending | Select-Object -First 1
if (-not $buildTools) { Stop-Verify "no Android build-tools under $AndroidSdk" }
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$aapt2 = Join-Path $buildTools.FullName 'aapt2.exe'
foreach ($tool in $apksigner, $aapt2) { if (-not (Test-Path -LiteralPath $tool)) { Stop-Verify "missing tool: $tool" } }

$results = New-Object System.Collections.Generic.List[object]
function Add-Check([string]$Id, [bool]$Ok, [string]$Check, [string]$Detail) {
  $results.Add([pscustomobject]@{ Id = $Id; Status = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Check = $Check; Detail = $Detail })
}

$ErrorActionPreference = 'Continue'
$verify = & $apksigner verify --verbose --print-certs $ApkPath 2>&1 | ForEach-Object { "$_" }
$verifyExit = $LASTEXITCODE
$badging = & $aapt2 dump badging $ApkPath 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = 'Stop'

Add-Check 'S1' ($verifyExit -eq 0 -and ($verify -match '^Verifies$').Count -gt 0) 'apksigner verifies' "exit=$verifyExit"

$v2 = [bool]($verify -match 'Verified using v2 scheme.*: true')
$v3 = [bool]($verify -match 'Verified using v3 scheme.*: true')
Add-Check 'S2' ($v2 -or $v3) 'signature scheme v2/v3' "v2=$v2 v3=$v3"

$signerCount = @($verify | Where-Object { $_ -match '^Signer #\d+ certificate DN:' }).Count
Add-Check 'S3' ($signerCount -eq 1) 'exactly one signer' "signers=$signerCount"

$dn = (@($verify | Where-Object { $_ -match '^Signer #1 certificate DN:' }) | Select-Object -First 1) -replace '^Signer #1 certificate DN:\s*', ''
Add-Check 'S4' ($dn -and $dn -notmatch 'CN=Android Debug') 'not the debug certificate' "dn=$dn"

$sha = (@($verify | Where-Object { $_ -match '^Signer #1 certificate SHA-256 digest:' }) | Select-Object -First 1) -replace '^Signer #1 certificate SHA-256 digest:\s*', ''
$shaNorm = ($sha -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()
Add-Check 'S5' ($shaNorm -eq $ExpectedSha256) 'release certificate fingerprint' $(if ($shaNorm -eq $ExpectedSha256) { 'matches approved tindak-release' } else { "got $shaNorm" })

$pkgLine = @($badging | Where-Object { $_ -match "^package: name='" }) | Select-Object -First 1
$pkg = [regex]::Match("$pkgLine", "name='([^']+)'").Groups[1].Value
$versionCode = [regex]::Match("$pkgLine", "versionCode='([^']+)'").Groups[1].Value
$versionName = [regex]::Match("$pkgLine", "versionName='([^']+)'").Groups[1].Value
Add-Check 'S6' ($pkg -eq $ExpectedPackage) 'package id' "package=$pkg"

# S7: scan every entry in memory. Obfuscated resource names collide on
# case-insensitive filesystems, so nothing is extracted to disk.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$latin1 = [Text.Encoding]::GetEncoding(28591)
$patterns = [ordered]@{
  'google_api_key'  = 'AIza[0-9A-Za-z_\-]{35}'
  'supabase_pat'    = 'sbp_[0-9a-f]{40}'
  'supabase_secret' = 'sb_secret_[0-9A-Za-z_\-]{10,}'
  'resend_key'      = 're_[0-9A-Za-z]{8}_[0-9A-Za-z]{10,}'
  'jwt'             = 'eyJ[0-9A-Za-z_\-]{10,}\.eyJ[0-9A-Za-z_\-]{10,}\.[0-9A-Za-z_\-]{10,}'
  'postgres_creds'  = 'postgres(ql)?://[^\s:"]+:[^\s@"]+@'
  'private_key'     = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'signing_env'     = 'TINDAK_SIGNING_PASSWORD\s*=\s*\S'
  'keystore_file'   = '(?i)[^\x00-\x1f]{0,60}\.(jks|keystore|p12|pfx|pepk)\b'
}
$hits = @{}
foreach ($k in $patterns.Keys) { $hits[$k] = 0 }
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ApkPath).Path)
try {
  foreach ($entry in $zip.Entries) {
    if ($entry.FullName -match '(?i)\.(jks|keystore|p12|pfx|pepk)$') { $hits['keystore_file']++ }
    if ($entry.Length -eq 0) { continue }
    $stream = $entry.Open()
    $ms = New-Object IO.MemoryStream
    try { $stream.CopyTo($ms) } finally { $stream.Dispose() }
    $text = $latin1.GetString($ms.ToArray())
    $ms.Dispose()
    foreach ($k in $patterns.Keys) {
      if ($k -eq 'keystore_file') { continue }
      $hits[$k] += ([regex]::Matches($text, $patterns[$k])).Count
    }
  }
} finally { $zip.Dispose() }
$secretHits = @($hits.Keys | Where-Object { $hits[$_] -gt 0 })
Add-Check 'S7' ($secretHits.Count -eq 0) 'no secrets inside the APK' $(if ($secretHits.Count -eq 0) { 'clean' } else { 'hits: ' + (($secretHits | ForEach-Object { "$_=$($hits[$_])" }) -join ',') })

Write-Output ("RELEASE APK VERIFY  {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
foreach ($r in $results) { Write-Output ("{0}  {1}  {2} :: {3}" -f $r.Id, $r.Status, $r.Check, $r.Detail) }
Write-Output ''
Write-Output "versionCode=$versionCode versionName=$versionName"
Write-Output ("apk_sha256=" + (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash)
$fails = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
Write-Output ("RESULT  {0}" -f $(if ($fails -eq 0) { 'PASS' } else { "FAIL ($fails)" }))
if ($fails -gt 0) { exit 1 }
exit 0
