param(
    [string]$OutputDirectory,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$windowsDirectory = Split-Path -Parent $projectDirectory
$workspaceDirectory = Split-Path -Parent $windowsDirectory

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectDirectory "dist"
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

$version = (Get-Content -LiteralPath (Join-Path $projectDirectory "VERSION") -Raw -Encoding UTF8).Trim()
$packageName = "ManHelper-$version-windows-x64"
$stagingDirectory = Join-Path $OutputDirectory $packageName
$archivePath = Join-Path $OutputDirectory "$packageName.zip"
$applicationPath = Join-Path $projectDirectory "build\ManHelper.exe"
$databasePath = Join-Path $workspaceDirectory "Test_Database\manbase.sqlite"

if (-not $SkipTests) {
    & (Join-Path $projectDirectory "test.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    & (Join-Path $windowsDirectory "validator\test.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
else {
    & (Join-Path $projectDirectory "build.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path -LiteralPath $applicationPath -PathType Leaf)) {
    throw "Application executable not found: $applicationPath"
}
if (-not (Test-Path -LiteralPath $databasePath -PathType Leaf)) {
    throw "Validated man database not found: $databasePath"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputPrefix = $OutputDirectory.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
                [System.IO.Path]::DirectorySeparatorChar
$resolvedStaging = [System.IO.Path]::GetFullPath($stagingDirectory)
if (-not $resolvedStaging.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe staging directory: $resolvedStaging"
}

if (Test-Path -LiteralPath $resolvedStaging) {
    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
}
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
New-Item -ItemType Directory -Path $resolvedStaging | Out-Null

Copy-Item -LiteralPath $applicationPath -Destination (Join-Path $resolvedStaging "ManHelper.exe")
Copy-Item -LiteralPath $databasePath -Destination (Join-Path $resolvedStaging "manbase.sqlite")
Copy-Item -LiteralPath (Join-Path $projectDirectory "LICENSE") -Destination (Join-Path $resolvedStaging "LICENSE.txt")
Copy-Item -LiteralPath (Join-Path $projectDirectory "PORTABLE_README_RU.txt") -Destination (Join-Path $resolvedStaging "README_RU.txt")
Copy-Item -LiteralPath (Join-Path $projectDirectory "PORTABLE_README_EN.txt") -Destination (Join-Path $resolvedStaging "README_EN.txt")
Copy-Item -LiteralPath (Join-Path $projectDirectory "settings.example.ini") -Destination (Join-Path $resolvedStaging "settings.example.ini")

$packagedApplication = Join-Path $resolvedStaging "ManHelper.exe"
$smokeProcess = Start-Process -FilePath $packagedApplication -ArgumentList "--smoke-test" -Wait -PassThru
if ($smokeProcess.ExitCode -ne 0) {
    throw "Packaged ManHelper smoke test failed with exit code $($smokeProcess.ExitCode)."
}
$detailsSmokeProcess = Start-Process -FilePath $packagedApplication -ArgumentList "--details-smoke-test" -Wait -PassThru
if ($detailsSmokeProcess.ExitCode -ne 0) {
    throw "Packaged ManHelper details smoke test failed with exit code $($detailsSmokeProcess.ExitCode)."
}

$hashLines = Get-ChildItem -LiteralPath $resolvedStaging -File |
    Sort-Object Name |
    ForEach-Object {
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($_.Name)"
    }
Set-Content -LiteralPath (Join-Path $resolvedStaging "SHA256SUMS.txt") -Value $hashLines -Encoding UTF8

Compress-Archive -LiteralPath $resolvedStaging -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host "Packaged $archivePath"
Write-Host "SHA256 $archiveHash"
