[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$version = [IO.File]::ReadAllText((Join-Path $project 'VERSION')).Trim()
& (Join-Path $PSScriptRoot 'Build.ps1') -ValidateOnly | Out-Host

# The installer recipe is the runtime file list. Add the source-only files
# explicitly so local reports, caches and developer settings cannot enter a ZIP.
$files = [ordered]@{}
foreach ($line in [IO.File]::ReadLines((Join-Path $PSScriptRoot 'Studio.iss'))) {
    if ($line -match '^Source: "([^"]+)"; DestDir: "\{app\}([^"]*)"') {
        $inputFile = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Matches[1]))
        $destination = ($Matches[2].Trim('\') + '/' + [IO.Path]::GetFileName($inputFile)).TrimStart('/').Replace('\','/')
        $files[$destination] = $inputFile
    }
}
foreach ($relative in @(
    '.gitignore', 'START-VIREX.cmd', 'test_ai_review.py', 'docs/README-HU-1.3.1.txt',
    'packaging/Build.ps1', 'packaging/Build-Portable.ps1', 'packaging/make_icons.py',
    'packaging/Studio.iss', 'packaging/StudioLauncher.cs', 'tests/Desktop.Tests.ps1', 'tests/Update.Tests.ps1'
)) { $files[$relative] = Join-Path $project $relative }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$directory = Join-Path $project 'artifacts\portable'
$null = [IO.Directory]::CreateDirectory($directory)
$destination = Join-Path $directory "VIREX-Test-Studio-$version-Windows.zip"
$partial = Join-Path $directory ([guid]::NewGuid().ToString('N') + '.zip')
try {
    $archive = [IO.Compression.ZipFile]::Open($partial, 'Create')
    try {
        foreach ($entry in $files.GetEnumerator()) {
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $entry.Value, ('VIREX-Test-Studio/' + $entry.Key), 'Optimal')
        }
    } finally { $archive.Dispose() }
    if ([IO.File]::Exists($destination)) {
        [IO.File]::Replace($partial, $destination, [System.Management.Automation.Language.NullString]::Value)
    } else { [IO.File]::Move($partial, $destination) }
} finally {
    if ([IO.File]::Exists($partial)) { [IO.File]::Delete($partial) }
}
Get-FileHash -LiteralPath $destination -Algorithm SHA256
