function ConvertTo-RepositoryTarget([string]$address) {
    $value = $address.Trim().TrimEnd('/')
    if ($value.StartsWith('https://github.com/', [StringComparison]::OrdinalIgnoreCase)) { $value = $value.Substring(19) }
    if ($value.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) { $value = $value.Substring(0,$value.Length-4) }
    if ($value -notmatch '^([A-Za-z0-9][A-Za-z0-9-]{0,38})/([A-Za-z0-9_.-]{1,100})$' -or $Matches[2] -in @('.','..')) {
        throw 'Adj meg egy GitHub HTTPS-címet vagy egy tulajdonos/repó nevet.'
    }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { $id=[BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($value.ToLowerInvariant()))).Replace('-','').Substring(0,24) }
    finally { $algorithm.Dispose() }
    return @{ Name=$value; Origin="https://github.com/$value.git"; Branch='HEAD'; CacheId=$id; Sha=$null }
}

function Add-RepositorySteps($target, [string]$git) {
    $null = [IO.Directory]::CreateDirectory($workDir)
    if (!(Test-Path -LiteralPath (Join-Path $workDir '.git'))) {
        if (@(Get-ChildItem -LiteralPath $workDir -Force).Count) { throw "A tesztmappa nem üres: $workDir" }
        Add-Step 'Clone repository' $git "clone -- $($target.Origin) ."
    }
    Add-Step 'Protect local changes' $git 'status --porcelain --untracked-files=normal' 'clean'
    Add-Step 'Verify repository origin' $git 'remote get-url origin' 'remote'
    Add-Step 'Fetch selected revision' $git "fetch --no-tags origin $($target.Branch)"
    Add-Step 'Switch to fetched revision' $git 'switch --detach FETCH_HEAD'
    Add-Step 'Record checked out commit' $git 'rev-parse HEAD' 'workspacehead'
}
