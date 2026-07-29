param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = "C:\Program Files\PureBasic\Compilers\pbcompiler.exe"
$cliSource = Join-Path $projectDirectory "Main.pb"
$guiSource = Join-Path $projectDirectory "MainGui.pb"
$buildDirectory = Join-Path $projectDirectory "build"
$cliOutput = Join-Path $buildDirectory "ManBaseValidator.exe"
$guiOutput = Join-Path $buildDirectory "ManBaseValidatorGUI.exe"
$sqliteDirectory = Join-Path $projectDirectory "vendor\sqlite"
$sqliteSource = Join-Path $sqliteDirectory "sqlite3.c"
$sqliteObject = Join-Path $sqliteDirectory "sqlite3.obj"
$sqliteLibrary = Join-Path $sqliteDirectory "sqlite3.lib"

if (-not (Test-Path -LiteralPath $compiler)) {
    $compilerCommand = Get-Command pbcompiler.exe -ErrorAction SilentlyContinue
    if ($null -eq $compilerCommand) {
        throw "PureBasic x64 compiler not found."
    }
    $compiler = $compilerCommand.Source
}

New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null

if (-not (Test-Path -LiteralPath $sqliteSource)) {
    throw "Vendored SQLite amalgamation not found: $sqliteSource"
}

if (-not (Test-Path -LiteralPath $sqliteLibrary) -or
    (Get-Item -LiteralPath $sqliteLibrary).LastWriteTimeUtc -lt
    (Get-Item -LiteralPath $sqliteSource).LastWriteTimeUtc) {
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vsWhere)) {
        throw "Visual Studio C++ build tools are required to build SQLite with FTS5."
    }
    $vsRoot = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsRoot) {
        throw "Visual Studio C++ x64 tools were not found."
    }
    $vcVars = Join-Path $vsRoot "VC\Auxiliary\Build\vcvars64.bat"
    $compileCommand = 'call "{0}" >nul && cl.exe /nologo /c /O2 /MT /utf-8 /DSQLITE_ENABLE_FTS5 /DSQLITE_THREADSAFE=1 /DSQLITE_DQS=0 /Fo"{1}" "{2}" && lib.exe /nologo /OUT:"{3}" "{1}"' -f $vcVars, $sqliteObject, $sqliteSource, $sqliteLibrary
    & cmd.exe /d /c $compileCommand
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$cliArguments = @($cliSource, "/CONSOLE", "/OUTPUT", $cliOutput, "/LINENUMBERING", "/DPIAWARE")
$guiArguments = @($guiSource, "/OUTPUT", $guiOutput, "/LINENUMBERING", "/DPIAWARE")
if ($Configuration -eq "Release") {
    $cliArguments += "/OPTIMIZER"
    $guiArguments += "/OPTIMIZER"
}

& $compiler @cliArguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
& $compiler @guiArguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
Write-Host "Built $cliOutput"
Write-Host "Built $guiOutput"
