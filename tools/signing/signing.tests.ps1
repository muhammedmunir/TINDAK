<#
TINDAK - static and local tests for release signing (EAR-4B)

No keystore password, no private key, no network and no Gradle build. Proves
the repository cannot leak signing material and that the wiring fails closed.

  powershell -ExecutionPolicy Bypass -File tools/signing/signing.tests.ps1
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here '..\..')).Path
$gradlePath = Join-Path $repo 'mobile\android\app\build.gradle.kts'
$sessionPath = Join-Path $here 'Enter-SigningSession.ps1'
$verifyPath = Join-Path $here 'Test-ReleaseApk.ps1'

$failures = New-Object System.Collections.Generic.List[string]
function Check([string]$Name, [bool]$Ok) {
  $label = if ($Ok) { 'ok  ' } else { 'FAIL' }
  Write-Output "$label $Name"
  if (-not $Ok) { $failures.Add($Name) }
}

$ApprovedFingerprint = '85BB8731119AE7DCE7EEFB4F37CEE2916BD26BDF69C458126837FFD8096C67E0'

# --- Gradle wiring ---
$gradle = [IO.File]::ReadAllText($gradlePath)
$gradleCode = [regex]::Replace($gradle, '(?m)//.*$', '')
Check 'gradle: release no longer uses the debug signing config' ($gradleCode -notmatch 'getByName\("debug"\)')
Check 'gradle: password comes only from TINDAK_SIGNING_PASSWORD' ($gradleCode -match 'System\.getenv\("TINDAK_SIGNING_PASSWORD"\)')
Check 'gradle: properties path comes only from TINDAK_SIGNING_PROPERTIES' ($gradleCode -match 'System\.getenv\("TINDAK_SIGNING_PROPERTIES"\)')
Check 'gradle: no password literal' ($gradleCode -notmatch '(storePassword|keyPassword)\s*=\s*"')
Check 'gradle: no keystore path literal' ($gradleCode -notmatch '(?i)(storeFile\s*=\s*file\(\s*")|TindakSigning|\.jks"')
Check 'gradle: release signing config only created when ready' ($gradleCode -match 'if \(releaseSigningReady\)\s*\{\s*create\("release"\)')
Check 'gradle: release build type uses release config or null' ($gradleCode -match 'signingConfig = if \(releaseSigningReady\) signingConfigs\.getByName\("release"\) else null')
Check 'gradle: fail-closed guard throws for release artifacts' (($gradleCode -match 'gradle\.taskGraph\.whenReady') -and ($gradleCode -match 'throw GradleException'))
Check 'gradle: guard covers assemble/bundle/package/sign Release tasks' ($gradleCode -match [regex]::Escape('^(assemble|bundle|package|sign)[A-Za-z]*Release$'))
Check 'gradle: error message never interpolates the password value' ($gradleCode -notmatch '\$\{?releaseSigningPassword\}?(?!\.isNullOrEmpty)')
Check 'gradle: applicationId stays my.tindak.app' ($gradleCode -match 'applicationId = "my\.tindak\.app"')
Check 'gradle: namespace stays my.tindak.app' ($gradleCode -match 'namespace = "my\.tindak\.app"')
Check 'gradle: version still taken from pubspec' (($gradleCode -match 'versionCode = flutter\.versionCode') -and ($gradleCode -match 'versionName = flutter\.versionName'))

# --- repository hygiene ---
Push-Location $repo
try {
  $tracked = @(git ls-files --cached --others --exclude-standard | Where-Object { $_ -match '(?i)\.(jks|keystore|p12|pfx|pem|pepk|der|dpapi)$|(^|/)(key|signing)\.properties$' })
  Check "repo: no keystore, key or signing properties file is tracked or pending ($($tracked.Count))" ($tracked.Count -eq 0)

  foreach ($p in 'mobile/android/signing.properties', 'signing.properties', 'mobile/android/key.properties',
                 'release.jks', 'release.keystore', 'release.p12', 'release.pfx', 'release.pem', 'release.pepk',
                 'release.der', 'keystore-password.dpapi') {
    git check-ignore -q $p
    Check "gitignore: $p is ignored" ($LASTEXITCODE -eq 0)
  }

  $textFiles = @(git ls-files --cached --others --exclude-standard | Where-Object { $_ -notmatch '(?i)\.(png|jpg|jpeg|webp|gif|ico|ttf|otf|jar|apk|aab|so)$' })
  $leaks = New-Object System.Collections.Generic.List[string]
  foreach ($f in $textFiles) {
    $full = Join-Path $repo $f
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    $t = [IO.File]::ReadAllText($full)
    if ($t -match 'TINDAK_SIGNING_PASSWORD\s*=\s*[''"][^''"]+[''"]') { $leaks.Add("$f literal signing password") }
    # This file holds the detector pattern itself, so it is not scanned for it.
    if ($f -notmatch 'signing\.tests\.ps1$' -and $t -match '(?i)-storepass\s+(?!:env)\S') { $leaks.Add("$f keytool -storepass with a value") }
    if ($t -match '(?i)(storePassword|keyPassword)\s*=\s*[^\s$].*') {
      if ($f -notmatch 'signing\.tests\.ps1$' -and $f -notmatch 'Enter-SigningSession\.ps1$' -and $f -notmatch 'build\.gradle\.kts$') { $leaks.Add("$f password property") }
    }
  }
  Check "repo: no signing password written anywhere ($($leaks.Count))" ($leaks.Count -eq 0)
  foreach ($l in $leaks) { Write-Output "     - $l" }
} finally { Pop-Location }

# --- session helper ---
$session = [IO.File]::ReadAllText($sessionPath)
$sessionCode = [regex]::Replace($session, '(?s)<#.*?#>', '')
Check 'session: password read with a hidden prompt' ($sessionCode -match 'Read-Host[^\r\n]*-AsSecureString')
Check 'session: no password parameter' ($sessionCode -notmatch '(?i)\[string\]\$\w*password')
Check 'session: never writes to a file or exports the secret' ($sessionCode -notmatch '(?i)\b(Set-Content|Add-Content|Out-File|Export-Clixml|ConvertFrom-SecureString|Tee-Object|Start-Transcript)\b')
Check 'session: never prints the password' ($sessionCode -notmatch '(?i)Write-(Output|Host)[^\r\n]*TINDAK_SIGNING_PASSWORD')
Check 'session: refuses a properties file that holds a password' ($sessionCode -match "ContainsKey\('storePassword'\)")
Check 'session: provides Exit-SigningSession' ($sessionCode -match 'function global:Exit-SigningSession')

# --- session helper: refusal paths (no prompt reached) ---
$work = Join-Path ([IO.Path]::GetTempPath()) ('tindak-signing-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $clean = "Remove-Item Env:\TINDAK_SIGNING_PASSWORD,Env:\TINDAK_SIGNING_PROPERTIES -ErrorAction SilentlyContinue;"
  function Invoke-Session([string]$Body) {
    $script = Join-Path $work ([guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($script, "$clean`n$Body`n'PW_SET=' + [bool]`$env:TINDAK_SIGNING_PASSWORD")
    (& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script 2>&1 | Out-String)
  }

  $out = Invoke-Session "& '$sessionPath'"
  Check 'session: refuses when not dot-sourced' (($out -match 'Dot-source') -and ($out -match 'PW_SET=False'))

  $out = Invoke-Session ". '$sessionPath' -PropertiesPath '$work\missing.properties'"
  Check 'session: refuses a missing properties file' (($out -match 'not found') -and ($out -match 'PW_SET=False'))

  [IO.File]::WriteAllText("$work\withpw.properties", "storeFile=$($work -replace '\\','/')/x.jks`nkeyAlias=a`nstorePassword=nope`n")
  $out = Invoke-Session ". '$sessionPath' -PropertiesPath '$work\withpw.properties'"
  Check 'session: refuses properties containing a password' (($out -match 'must not be stored') -and ($out -match 'PW_SET=False'))

  [IO.File]::WriteAllText("$work\nostore.properties", "storeFile=$($work -replace '\\','/')/absent.jks`nkeyAlias=a`n")
  $out = Invoke-Session ". '$sessionPath' -PropertiesPath '$work\nostore.properties'"
  Check 'session: refuses a keystore that does not exist' (($out -match 'does not point at an existing keystore') -and ($out -match 'PW_SET=False'))
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force
}

# --- verifier ---
$verify = [IO.File]::ReadAllText($verifyPath)
$fp = [regex]::Match($verify, "\`$ExpectedSha256 = '([0-9A-F]{64})'").Groups[1].Value
Check 'verifier: expects the approved tindak-release fingerprint' ($fp -eq $ApprovedFingerprint)
Check 'verifier: expects package my.tindak.app' ($verify -match "\`$ExpectedPackage = 'my\.tindak\.app'")
Check 'verifier: rejects the debug certificate' ($verify -match 'CN=Android Debug')

# --- all signing scripts parse and are ASCII (Windows PowerShell 5.1) ---
foreach ($p in $sessionPath, $verifyPath, $MyInvocation.MyCommand.Path) {
  $errs = $null
  $null = [Management.Automation.PSParser]::Tokenize([IO.File]::ReadAllText($p), [ref]$errs)
  $name = Split-Path -Leaf $p
  Check "script: $name parses" (@($errs).Count -eq 0)
  Check "script: $name is ASCII" (@([IO.File]::ReadAllBytes($p) | Where-Object { $_ -gt 127 }).Count -eq 0)
}

Write-Output ''
if ($failures.Count -gt 0) {
  Write-Output "FAILED: $($failures.Count)"
  $failures | ForEach-Object { Write-Output "  - $_" }
  exit 1
}
Write-Output 'ALL SIGNING TESTS PASSED'
exit 0
