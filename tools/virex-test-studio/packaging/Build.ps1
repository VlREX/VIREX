[CmdletBinding()]
param([switch]$ValidateOnly, [string]$Compiler, [switch]$Preview)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$version = [IO.File]::ReadAllText((Join-Path $project 'VERSION')).Trim()
if ($version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$' -or
    @($version.Split('.') | Where-Object { [long]$_ -gt 65535 }).Count) { throw 'Invalid Windows product version.' }
$launcherDir = Join-Path $project 'artifacts\launcher'
$null = [IO.Directory]::CreateDirectory($launcherDir)
$launcher = Join-Path $launcherDir 'VIREX-Test-Studio.exe'
$csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
if (!(Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
& $csc /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll "/win32icon:$(Join-Path $project 'assets\studio.ico')" "/out:$launcher" (Join-Path $PSScriptRoot 'StudioLauncher.cs') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Windows launcher compilation failed.' }
$recipe = Join-Path $PSScriptRoot 'Studio.iss'
foreach ($line in [IO.File]::ReadLines($recipe)) {
    if ($line -match '^Source: "([^"]+)"' -and !(Test-Path -LiteralPath (Join-Path $PSScriptRoot $Matches[1]) -PathType Leaf)) {
        throw "Missing package input: $line"
    }
}
if ($ValidateOnly) { Write-Output "Validated launcher and installer inputs for $version."; return }
if (!$Compiler) {
    $command = Get-Command ISCC.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { $Compiler = $command.Source }
    else {
        $Compiler = @( "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe" ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
}
if (!$Compiler) { throw 'Install Inno Setup 6 or provide -Compiler with the path to ISCC.exe.' }
$defines = @("/DStudioVersion=$version")
$previewSuffix = ''
if ($Preview) {
    $defines += '/DStudioPreview'
    $previewSuffix = '-Preview'
}
& $Compiler @defines $recipe | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
$setup = Join-Path $project "artifacts\installer\VIREX-Test-Studio-$version$previewSuffix-Setup.exe"
Get-FileHash -LiteralPath $setup -Algorithm SHA256
