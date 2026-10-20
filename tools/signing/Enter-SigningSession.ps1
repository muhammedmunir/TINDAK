<#
TINDAK - release signing session (EAR-4B)

Prepares THIS terminal, and only this terminal, to build a signed release.

  . .\tools\signing\Enter-SigningSession.ps1        <- note the leading dot
  cd mobile
  flutter build apk --release --dart-define-from-file=.env.client
  Exit-SigningSession                               <- or close the terminal

WHAT IT DOES
  - Points TINDAK_SIGNING_PROPERTIES at the signing properties file outside the
    repository (default C:\TindakSigning\signing.properties). That file holds
    only storeFile and keyAlias.
  - Asks for the keystore password with a hidden prompt and places it in
    TINDAK_SIGNING_PASSWORD for this process and the builds it starts.

WHAT IT NEVER DOES
  - It never takes the password as an argument, so the password cannot land in
    shell history.
  - It never writes the password to a file, a log or the console.
  - It is never run by the coding agent: signed builds are the CEO's step.

Without this session, Gradle refuses to build any release artifact. It does not
fall back to the debug key.
#>
param(
  [string]$PropertiesPath = 'C:\TindakSigning\signing.properties'
)

if ($MyInvocation.InvocationName -ne '.') {
  Write-Warning 'Dot-source this script so the session applies to your terminal:  . .\tools\signing\Enter-SigningSession.ps1'
  return
}

if (-not (Test-Path -LiteralPath $PropertiesPath -PathType Leaf)) {
  Write-Warning "Signing properties not found at $PropertiesPath. No session started."
  return
}

$props = @{}
foreach ($line in Get-Content -LiteralPath $PropertiesPath) {
  if ($line -match '^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*(.*)$') { $props[$matches[1]] = $matches[2].Trim() }
}
if ($props.ContainsKey('storePassword') -or $props.ContainsKey('keyPassword')) {
  Write-Warning 'The signing properties file contains a password entry. Passwords must not be stored in that file (PD-056). No session started.'
  return
}
if (-not $props['storeFile'] -or -not (Test-Path -LiteralPath $props['storeFile'] -PathType Leaf)) {
  Write-Warning 'storeFile in the signing properties does not point at an existing keystore. No session started.'
  return
}
if (-not $props['keyAlias']) {
  Write-Warning 'keyAlias is missing from the signing properties. No session started.'
  return
}

$secure = Read-Host -Prompt "Keystore password for alias '$($props['keyAlias'])'" -AsSecureString
if ($secure.Length -eq 0) {
  Write-Warning 'Empty password. No session started.'
  return
}

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $env:TINDAK_SIGNING_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  $secure.Dispose()
}
$env:TINDAK_SIGNING_PROPERTIES = $PropertiesPath

function global:Exit-SigningSession {
  Remove-Item Env:\TINDAK_SIGNING_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:\TINDAK_SIGNING_PROPERTIES -ErrorAction SilentlyContinue
  Write-Output 'Signing session ended for this terminal.'
}

Write-Output "Signing session ready for alias '$($props['keyAlias'])'. It lasts until you run Exit-SigningSession or close this terminal."
