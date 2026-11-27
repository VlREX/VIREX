$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'StudioUpdate.ps1')
function Assert-True($condition, $message) { if (!$condition) { throw $message } }
function Assert-Throws([scriptblock]$operation, [string]$message) {
    try { & $operation | Out-Null } catch { return }
    throw $message
}
$directory = Join-Path ([IO.Path]::GetTempPath()) ('virex-update-' + [guid]::NewGuid())
$payload = [Text.Encoding]::UTF8.GetBytes('inert fixture')
$algorithm = [Security.Cryptography.SHA256]::Create()
try { $hash=[BitConverter]::ToString($algorithm.ComputeHash($payload)).Replace('-','') } finally { $algorithm.Dispose() }
$name = 'VIREX-Test-Studio-2.10.0-Setup.exe'
$asset = @{ name=$name; state='uploaded'; browser_download_url=$studioAssetBase+$name; digest="sha256:$hash"; size=$payload.Length }
$release = @{ tag_name='studio-stable'; draft=$false; prerelease=$false; assets=@($asset) }
try {
    $offer = Select-StudioUpdate $release ([version]'2.9.9')
    Assert-True ($offer.Version -eq '2.10.0') 'Numeric version comparison failed.'
    $previewAsset = $asset.Clone()
    $previewAsset.name = 'VIREX-Test-Studio-3.0.1-Preview-Setup.exe'
    $previewAsset.browser_download_url = 'https://github.com/VlREX/VIREX/releases/download/studio-preview/' + $previewAsset.name
    $previewRelease = @{ tag_name='studio-preview'; draft=$false; prerelease=$true; assets=@($asset,$previewAsset) }
    Assert-True ((Select-StudioUpdate $previewRelease '3.0.0' -Preview).Name -eq $previewAsset.name) 'Preview update asset selection failed.'
    Assert-Throws { Select-StudioUpdate $previewRelease '2.0.0' } 'Stable channel accepted a preview release.'
    Assert-Throws { Select-StudioUpdate $release '2.0.0' -Preview } 'Preview channel accepted a stable release.'
    foreach ($current in @('2.10.0','3.0.0')) { Assert-True ((Select-StudioUpdate $release $current).State -eq 'current') 'Equal or older offer.' }
    foreach ($key in @('draft','prerelease')) {
        $release[$key]=$true
        Assert-Throws { Select-StudioUpdate $release '2.0.0' } "Accepted $key."
        $release[$key]=$false
    }
    foreach ($bad in @(@('digest','sha256:bad'),@('browser_download_url','https://example.org/a.exe'),@('size',0),@('size',129MB),@('state','new'),@('name','unrelated.exe'))) {
        $key,$value=$bad
        $old=$asset[$key]; $asset[$key]=$value
        Assert-Throws { Select-StudioUpdate $release '2.0.0' } "Accepted invalid $key."
        $asset[$key]=$old
    }
    foreach ($case in @('short','over','hash')) {
        $stream=New-Object IO.MemoryStream(,$payload)
        $invalid=$offer.PSObject.Copy()
        switch ($case) {
            'short' { $invalid.Size++ }
            'over'  { $invalid.Size-- }
            'hash'  { $invalid.Hash='0'*64 }
        }
        try { Assert-Throws { Copy-StudioAsset $stream $invalid $directory } "Accepted invalid bytes: $case" } finally { $stream.Dispose() }
        Assert-True (@(Get-ChildItem -LiteralPath $directory).Count -eq 0) 'Failed download left a file.'
    }
    for ($attempt=0; $attempt -lt 2; $attempt++) {
        $stream=New-Object IO.MemoryStream(,$payload)
        try { $path=Copy-StudioAsset $stream $offer $directory } finally { $stream.Dispose() }
        Assert-True ((Get-FileHash -LiteralPath $path).Hash -eq $hash) 'Cache write failed.'
    }
    function Invoke-RestMethod { throw [Net.WebException]::new('offline') }
    Assert-Throws { Get-StudioUpdate '2.0.0' } 'Offline check incorrectly succeeded.'
    Write-Output 'PASS: release selection, numeric versions, invalid metadata, download bounds, digest, retry and offline handling.'
} finally {
    if (Test-Path -LiteralPath $directory) {
        Get-ChildItem -LiteralPath $directory -File | Remove-Item
        [IO.Directory]::Delete($directory)
    }
}
