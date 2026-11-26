# Update worker for Windows PowerShell 5.1. No Windows Forms dependencies.
$studioChannel = 'studio-stable'
$studioReleaseUrl = 'https://api.github.com/repos/VlREX/VIREX/releases/tags/studio-stable'
$studioAssetBase = 'https://github.com/VlREX/VIREX/releases/download/studio-stable/'
$studioMaxBytes = 128MB

function Select-StudioUpdate($Release, [version]$Installed) {
    if ($Release.tag_name -cne $studioChannel -or $Release.draft -ne $false -or $Release.prerelease -ne $false) {
        throw 'A kiadási csatorna adatai érvénytelenek.'
    }
    $candidates = foreach ($asset in $Release.assets) {
        if ($asset.state -ne 'uploaded') { continue }
        if ($asset.name -cnotmatch '^VIREX-Test-Studio-((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))-Setup\.exe$') { continue }
        [pscustomobject]@{ Version = [version]$Matches[1]; Asset = $asset }
    }
    $latest = $candidates | Sort-Object Version -Descending | Select-Object -First 1
    if (!$latest) { throw 'A stabil kiadáshoz még nincs Windows-telepítő.' }
    if ($latest.Version -le $Installed) { return [pscustomobject]@{ State='current' } }
    $asset = $latest.Asset
    if ($asset.browser_download_url -cne ($studioAssetBase + $asset.name) -or
        $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$' -or
        [long]$asset.size -le 0 -or [long]$asset.size -gt $studioMaxBytes) {
        throw 'A kiadás címe, mérete vagy SHA-256 azonosítója érvénytelen.'
    }
    [pscustomobject]@{ State='available'; Version=$latest.Version.ToString(); Name=$asset.name
        Url=$asset.browser_download_url; Hash=$asset.digest.Substring(7); Size=[long]$asset.size }
}

function Get-StudioUpdate([version]$Installed) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $release = Invoke-RestMethod -Uri $studioReleaseUrl -Headers @{Accept='application/vnd.github+json'} -UserAgent "VIREX-Test-Studio/$Installed" -TimeoutSec 20 -ErrorAction Stop
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            return [pscustomobject]@{ State='unpublished' }
        }
        throw
    }
    Select-StudioUpdate $release $Installed
}

function Copy-StudioAsset([IO.Stream]$InputStream, $Update, [string]$Directory) {
    $null = [IO.Directory]::CreateDirectory($Directory)
    $final = Join-Path $Directory $Update.Name
    $part = Join-Path $Directory ([guid]::NewGuid().ToString('N') + '.part')
    $output = $null
    try {
        $output = [IO.File]::Open($part, 'CreateNew', 'Write', 'None')
        $buffer = New-Object byte[] 65536
        while (($count = $InputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            if ($output.Length + $count -gt $Update.Size) { throw 'A letöltés túllépte a kiadás méretét.' }
            $output.Write($buffer, 0, $count)
        }
        if ($output.Length -ne $Update.Size) { throw 'A letöltés hiányos. Próbáld újra.' }
        $output.Dispose()
        $output = $null
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $part).Hash -ne $Update.Hash) {
            throw 'Az SHA-256 ellenőrzés sikertelen. Próbáld újra a letöltést.'
        }
        if ([IO.File]::Exists($final)) {
            [IO.File]::Replace($part, $final, [System.Management.Automation.Language.NullString]::Value)
        } else {
            [IO.File]::Move($part, $final)
        }
        return $final
    } finally {
        if ($output) { $output.Dispose() }
        if ([IO.File]::Exists($part)) { [IO.File]::Delete($part) }
    }
}

function Receive-StudioUpdate($Update, [string]$Directory) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $request = [Net.HttpWebRequest]::Create($Update.Url)
    $request.UserAgent = 'VIREX-Test-Studio'
    $request.Timeout = 20000
    $request.ReadWriteTimeout = 30000
    $response = $request.GetResponse()
    try {
        $hostName = $response.ResponseUri.DnsSafeHost
        if ($response.ResponseUri.Scheme -ne 'https' -or
            ($hostName -ne 'github.com' -and $hostName -notlike '*.githubusercontent.com')) {
            throw 'Ismeretlen letöltési kiszolgáló.'
        }
        $source = $response.GetResponseStream()
        try { Copy-StudioAsset $source $Update $Directory } finally { $source.Dispose() }
    } finally { $response.Dispose() }
}
