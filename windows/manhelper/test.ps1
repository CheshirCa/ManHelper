$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = "C:\Program Files\PureBasic\Compilers\pbcompiler.exe"
$buildDirectory = Join-Path $projectDirectory "build"
$testSource = Join-Path $projectDirectory "tests\MvpTests.pb"
$testExecutable = Join-Path $projectDirectory "build\MvpTests.exe"
$manHelper = Join-Path $projectDirectory "build\ManHelper.exe"
$database = Join-Path $projectDirectory "..\..\Test_Database\manbase.sqlite"
$userDatabase = Join-Path $projectDirectory ("build\user-migration-" +
                [guid]::NewGuid().ToString("N") + ".sqlite")

$declaredVersion = (Get-Content -LiteralPath (Join-Path $projectDirectory "VERSION") -Raw -Encoding UTF8).Trim()
$versionSource = Get-Content -LiteralPath (Join-Path $projectDirectory "Version.pbi") -Raw -Encoding UTF8
if ($versionSource -notmatch ('#VERSION\s*=\s*"' + [regex]::Escape($declaredVersion) + '"')) {
    throw "VERSION and Version.pbi are not synchronized."
}

if (-not (Test-Path -LiteralPath $database -PathType Leaf)) {
    throw "Test database not found: $database"
}

$sqlite = (Get-Command sqlite3 -ErrorAction SilentlyContinue).Source
if (-not $sqlite) {
    throw "sqlite3 is required for the user database migration fixture."
}
& $sqlite $userDatabase "CREATE TABLE legacy(value TEXT); INSERT INTO legacy VALUES('сохранить'); PRAGMA user_version=0;"
if ($LASTEXITCODE -ne 0) {
    throw "Could not create the user database migration fixture."
}

$databaseHashBefore = (Get-FileHash -LiteralPath $database -Algorithm SHA256).Hash
$databaseWriteTimeBefore = (Get-Item -LiteralPath $database).LastWriteTimeUtc

& (Join-Path $projectDirectory "build.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $compiler $testSource /CONSOLE /OUTPUT $testExecutable
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $testExecutable $database $userDatabase
if ($LASTEXITCODE -ne 0) {
    throw "ManHelper tests failed with exit code $LASTEXITCODE."
}

$userBackupFilter = (Split-Path -Leaf $userDatabase) + ".backup-*"
$userBackups = @(Get-ChildItem -LiteralPath $buildDirectory -Filter $userBackupFilter)
if ($userBackups.Count -ne 1) {
    throw "Expected exactly one user database migration backup."
}
$legacyValue = & $sqlite $userBackups[0].FullName "SELECT value FROM legacy;"
if ($legacyValue -ne "сохранить") {
    throw "The user database backup did not preserve pre-migration data."
}
Remove-Item -LiteralPath $userDatabase -Force
Remove-Item -LiteralPath $userBackups[0].FullName -Force

function Get-PeSubsystem([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.BinaryReader]::new($stream)
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset + 24 + 68
        return $reader.ReadUInt16()
    }
    finally {
        $stream.Dispose()
    }
}

if ((Get-PeSubsystem $manHelper) -ne 2) {
    throw "ManHelper must use the Windows GUI subsystem."
}

$smokeProcess = Start-Process -FilePath $manHelper -ArgumentList "--smoke-test" -Wait -PassThru
if ($smokeProcess.ExitCode -ne 0) {
    throw "ManHelper smoke test failed with exit code $($smokeProcess.ExitCode)."
}

$detailsSmokeProcess = Start-Process -FilePath $manHelper -ArgumentList "--details-smoke-test" -Wait -PassThru
if ($detailsSmokeProcess.ExitCode -ne 0) {
    throw "ManHelper details smoke test failed with exit code $($detailsSmokeProcess.ExitCode)."
}

$databaseHashAfter = (Get-FileHash -LiteralPath $database -Algorithm SHA256).Hash
$databaseWriteTimeAfter = (Get-Item -LiteralPath $database).LastWriteTimeUtc
if ($databaseHashAfter -ne $databaseHashBefore -or
    $databaseWriteTimeAfter -ne $databaseWriteTimeBefore) {
    throw "The read-only test database was modified."
}

Write-Host "All ManHelper tests passed; the system database is unchanged."
