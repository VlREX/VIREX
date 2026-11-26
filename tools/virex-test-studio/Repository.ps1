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

# Accept only explicit GitHub PR, branch and full commit URLs. No arbitrary Git arguments.
function ConvertTo-RevisionTarget([string]$address) {
    $value=$address.Trim().TrimEnd('/')
    if ($value -cnotmatch '^https://github\.com/([A-Za-z0-9][A-Za-z0-9-]{0,38})/([A-Za-z0-9_.-]{1,100})/(pull|tree|commit)/(.+)($target, [string]$git) {
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
) {
        throw 'GitHub PR-, branch- vagy teljes commit-link szükséges.'
    }
    $owner,$repository,$kind,$ref=$Matches[1],$Matches[2],$Matches[3],$Matches[4]
    $target=ConvertTo-RepositoryTarget "$owner/$repository"
    $target.SourceUrl=$value
    switch ($kind) {
        'pull' {
            if ($ref -cnotmatch '^[1-9][0-9]{0,9}($target, [string]$git) {
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
) { throw 'Érvénytelen PR-szám.' }
            $target.Branch="refs/pull/$ref/head"
            $target.Name += " PR #$ref"
        }
        'tree' {
            if ($ref -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]{0,200}($target, [string]$git) {
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
 -or $ref.Contains('..') -or $ref.Contains('//') -or $ref.EndsWith('.') -or @($ref.Split('/') | Where-Object { $_.StartsWith('.') -or $_.EndsWith('.lock',[StringComparison]::OrdinalIgnoreCase) }).Count) {
                throw 'Érvénytelen vagy nem támogatott ág neve.'
            }
            $target.Branch="refs/heads/$ref"
            $target.Name += " / $ref"
        }
        'commit' {
            if ($ref -cnotmatch '^[0-9a-fA-F]{40}($target, [string]$git) {
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
) { throw 'Teljes, 40 jegyű commit SHA szükséges.' }
            $target.Branch=$ref.ToLowerInvariant()
            $target.ExpectedSha=$target.Branch
            $target.Name += ' @ '+$target.Branch.Substring(0,12)
        }
    }
    return $target
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
