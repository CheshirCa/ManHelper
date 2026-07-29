param(
    [string]$Database = (Join-Path $PSScriptRoot "..\..\Test_Database\manbase.sqlite")
)

$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = "C:\Program Files\PureBasic\Compilers\pbcompiler.exe"
$testSource = Join-Path $projectDirectory "tests\UtilsTests.pb"
$testExecutable = Join-Path $projectDirectory "build\UtilsTests.exe"
$validator = Join-Path $projectDirectory "build\ManBaseValidator.exe"
$validatorGui = Join-Path $projectDirectory "build\ManBaseValidatorGUI.exe"
$jsonReport = Join-Path $projectDirectory "build\integration-report.json"
$databaseInfoBefore = Get-Item -LiteralPath $Database -ErrorAction SilentlyContinue
$declaredVersion = (Get-Content -LiteralPath (Join-Path $projectDirectory "VERSION") -Raw -Encoding UTF8).Trim()
$versionSource = Get-Content -LiteralPath (Join-Path $projectDirectory "Version.pbi") -Raw -Encoding UTF8
if ($versionSource -notmatch ('#CLIENT_VERSION\s*=\s*"' + [regex]::Escape($declaredVersion) + '"')) {
    throw "VERSION and Version.pbi are not synchronized."
}

& (Join-Path $projectDirectory "build.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $compiler $testSource /CONSOLE /OUTPUT $testExecutable
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $testExecutable
if ($LASTEXITCODE -ne 0) { throw "PureBasic unit tests failed with exit code $LASTEXITCODE." }

& $validator --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "--version failed."
}

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

if ((Get-PeSubsystem $validator) -ne 3) {
    throw "CLI executable is not a Windows console subsystem application."
}
if ((Get-PeSubsystem $validatorGui) -ne 2) {
    throw "GUI executable must use the Windows GUI subsystem."
}

& $validatorGui --smoke-test
if ($LASTEXITCODE -ne 0) {
    throw "GUI smoke test failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $Database)) {
    throw "Integration database not found: $Database"
}

$databaseInfoBefore = Get-Item -LiteralPath $Database
& $validator --database $Database --report $jsonReport --format json | Out-Null
$validatorExit = $LASTEXITCODE
if ($validatorExit -notin @(0, 2, 3)) {
    throw "Validator failed unexpectedly with exit code $validatorExit."
}
$report = Get-Content -LiteralPath $jsonReport -Raw -Encoding UTF8 | ConvertFrom-Json
if ($report.status -notin @("VALID", "VALID_WITH_WARNINGS", "INVALID", "INCOMPATIBLE")) {
    throw "Unknown report status: $($report.status)"
}
if ($report.status -notin @("VALID", "VALID_WITH_WARNINGS")) {
    throw "The supplied Linux Builder database is not usable: $($report.status)"
}
if ($report.counts.pages -lt 1) {
    throw "Integration report contains no pages."
}
$databaseInfoAfter = Get-Item -LiteralPath $Database
if ($databaseInfoAfter.Length -ne $databaseInfoBefore.Length -or
    $databaseInfoAfter.LastWriteTimeUtc -ne $databaseInfoBefore.LastWriteTimeUtc) {
    throw "Validator changed the source database."
}

$missingPath = Join-Path $projectDirectory "build\missing.sqlite"
& $validator --database $missingPath --format json | Out-Null
if ($LASTEXITCODE -ne 2) {
    throw "Missing-file test expected exit code 2, got $LASTEXITCODE."
}
if (Test-Path -LiteralPath $missingPath) {
    throw "Read-only open created a missing database file."
}

$notSqlitePath = Join-Path $projectDirectory "build\not-sqlite.sqlite"
Set-Content -LiteralPath $notSqlitePath -Value "This is not SQLite." -Encoding UTF8
& $validator --database $notSqlitePath --format json | Out-Null
if ($LASTEXITCODE -ne 2) {
    throw "Non-SQLite test expected exit code 2, got $LASTEXITCODE."
}

$sqliteCommand = Get-Command sqlite3.exe -ErrorAction SilentlyContinue
if ($null -eq $sqliteCommand) {
    throw "sqlite3.exe is required for the incompatible-schema fixture."
}
$incompatiblePath = Join-Path $projectDirectory "build\incompatible.sqlite"
if (Test-Path -LiteralPath $incompatiblePath) {
    Remove-Item -LiteralPath $incompatiblePath
}
& $sqliteCommand.Source $incompatiblePath "CREATE TABLE meta(key TEXT PRIMARY KEY,value TEXT NOT NULL); INSERT INTO meta VALUES('database_format','1'),('schema_version','999'),('text_encoding','UTF-8'),('unicode_normalization','NFC'),('fts_version','FTS5 unicode61'),('minimum_client_version','99.0.0');"
if ($LASTEXITCODE -ne 0) {
    throw "Could not create incompatible-schema fixture."
}
& $validator --database $incompatiblePath --format json | Out-Null
if ($LASTEXITCODE -ne 3) {
    throw "Incompatible-schema test expected exit code 3, got $LASTEXITCODE."
}

$cyrillicDirectory = Join-Path $projectDirectory "build\тест-пути"
New-Item -ItemType Directory -Force -Path $cyrillicDirectory | Out-Null
$cyrillicDatabase = Join-Path $cyrillicDirectory "база.sqlite"
Copy-Item -LiteralPath $Database -Destination $cyrillicDatabase -Force
& $validator --database $cyrillicDatabase --format json | Out-Null
if ($LASTEXITCODE -notin @(0, 2, 3)) {
    throw "Cyrillic-path validation failed unexpectedly with exit code $LASTEXITCODE."
}

Write-Host "All validator tests passed. Database status: $($report.status)"
