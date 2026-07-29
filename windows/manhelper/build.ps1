param(
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = "C:\Program Files\PureBasic\Compilers\pbcompiler.exe"
$source = Join-Path $projectDirectory "Main.pb"
$buildDirectory = Join-Path $projectDirectory "build"
$output = Join-Path $buildDirectory "ManHelper.exe"
$icon = Join-Path $projectDirectory "assets\manhelper.ico"
$sqliteDirectory = Join-Path $projectDirectory "..\validator\vendor\sqlite"
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

if (-not (Test-Path -LiteralPath $icon -PathType Leaf)) {
    throw "Application icon not found: $icon"
}

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

$arguments = @($source, "/OUTPUT", $output, "/LINENUMBERING", "/DPIAWARE",
               "/ICON", $icon)
if ($Configuration -eq "Release") {
    $arguments += "/OPTIMIZER"
}

& $compiler @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
Write-Host "Built $output"
