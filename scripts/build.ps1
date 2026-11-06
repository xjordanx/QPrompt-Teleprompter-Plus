# SPDX-License-Identifier: GPL-3.0-only
# Intelliprompter: Windows build for the QPrompt fork (MSVC 2022 + Qt 6 + Ninja).
#
#   pwsh scripts/build.ps1                 # configure (if needed) + build + deploy
#   pwsh scripts/build.ps1 -Step build     # incremental build only
#   pwsh scripts/build.ps1 -Step configure -Gamepad
#
# Output: build\release (build tree), build\install\bin\QPrompt.exe (runnable, Qt runtime deployed).

[CmdletBinding()]
param(
    [ValidateSet('all', 'configure', 'build', 'deploy')]
    [string]$Step = 'all',
    [string]$QtDir = 'C:\Qt\6.12.0\msvc2022_64',
    [string]$QtTools = 'C:\Qt\Tools',
    [ValidateSet('Release', 'RelWithDebInfo', 'Debug')]
    [string]$Config = 'Release',
    [switch]$Gamepad
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $repo 'build\release'
$installDir = Join-Path $repo 'build\install'

function Import-MsvcEnvironment {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw 'vswhere.exe not found; is Visual Studio 2022 installed?' }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'No Visual Studio with the C++ x64 toolset found.' }
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    # Run vcvars in cmd and copy the resulting environment into this session.
    cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
    }
}

function Invoke-Checked([string]$exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "$exe failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path (Join-Path $QtDir 'lib\cmake\Qt6'))) { throw "Qt not found at $QtDir" }
Import-MsvcEnvironment
$env:PATH = "$QtTools\CMake_64\bin;$QtTools\Ninja;$env:PATH"

$doConfigure = $Step -eq 'configure' -or ($Step -eq 'all' -and -not (Test-Path (Join-Path $buildDir 'CMakeCache.txt')))
if ($doConfigure) {
    Invoke-Checked cmake @('-G', 'Ninja', '-S', $repo, '-B', $buildDir,
        "-DCMAKE_BUILD_TYPE=$Config",
        "-DCMAKE_PREFIX_PATH=$QtDir",
        "-DCMAKE_INSTALL_PREFIX=$installDir",
        '-DQPROMPT_BUNDLE_HUNSPELL_DICTIONARIES=OFF',
        "-DINTELLIPROMPTER_GAMEPAD=$(if ($Gamepad) { 'ON' } else { 'OFF' })")
}
if ($Step -in 'all', 'build') {
    Invoke-Checked cmake @('--build', $buildDir)
}
if ($Step -in 'all', 'deploy') {
    Invoke-Checked cmake @('--install', $buildDir)
    Invoke-Checked (Join-Path $QtDir 'bin\windeployqt.exe') @(
        $(if ($Config -eq 'Debug') { '--debug' } else { '--release' }),
        '--qmldir', (Join-Path $repo 'src'), '--no-translations',
        (Join-Path $installDir 'bin\QPrompt.exe'))
    Write-Host "Ready: $(Join-Path $installDir 'bin\QPrompt.exe')"
}
