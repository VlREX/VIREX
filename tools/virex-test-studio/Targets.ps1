$belobugTarget=ConvertTo-RepositoryTarget 'Belobug/VIctory-Belobug-AMD'
$belobugTarget.Branch='a-publier'
$script:customTarget=$null
function Test-LocalTarget { return $combo.SelectedItem.Mode -eq 'local' }
function Test-WorkspaceTarget { return $combo.SelectedItem.Mode -ne 'pinned' }
function Get-SelectedRepository {
    if ($combo.SelectedItem.Mode -eq 'belobug') { return $belobugTarget }
    return $script:customTarget
}

function Update-TargetControls {
    $local = Test-LocalTarget
    $workspace = Test-WorkspaceTarget
    $ckFull.Enabled = !$workspace
    $ckWarp.Enabled = !$workspace
    if ($workspace) {
        $ckTest.Text = 'Munkaterület-tesztek'
        $ckBench.Enabled = $false
        $ckBench.Checked = $false
        if ($local) {
            $openSource.Text = 'Projektmappa tallózása…'
            $revision.Text = if ($script:localProject) { $script:localProject } else { 'Válaszd ki a Cargo.toml fájlt tartalmazó mappát.' }
        } else {
            $target=Get-SelectedRepository
            $openSource.Text = if ($combo.SelectedItem.Mode -eq 'belobug') { 'Repó megnyitása' } else { 'GitHub-cím megadása…' }
            $revision.Text = if ($target) { "$($target.Name)$([Environment]::NewLine)Ág: $($target.Branch)" } else { 'Add meg a tesztelendő GitHub-repót.' }
        }
    } else {
        $p = $combo.SelectedItem.Preset
        $ckTest.Text = 'Célzott tesztek'
        $ckBench.Enabled = [bool]$p.Bench
        $ckBench.Checked = [bool]$p.Bench
        $openSource.Text = 'Commit megnyitása'
        $revision.Text = "$($p.Branch)$([Environment]::NewLine)$($p.Sha.Substring(0,12))"
    }
    $tip.SetToolTip($revision,$(if ($workspace) { $revision.Text } else { $p.Sha }))
    $welcomeName.Text=if ($workspace -and !$local -and $target) { $target.Name.Split('/')[-1] } elseif ($local -and $localProject) { Split-Path -Leaf $localProject } elseif (!$workspace) { $p.Crate } else { 'Projekt kiválasztása' }
    $welcomeDetail.Text=$revision.Text
}

function Set-LocalProject([string]$directory) {
    $manifest = Join-Path $directory 'Cargo.toml'
    if (!(Test-Path -LiteralPath $manifest -PathType Leaf)) { throw 'A kiválasztott mappából hiányzik a Cargo.toml.' }
    $script:localProject = (Get-Item -LiteralPath $directory).FullName
    Update-TargetControls
}

function Add-WorkspaceCargoSteps([string]$cargo, [string]$directory) {
    $lock = if (Test-Path -LiteralPath (Join-Path $directory 'Cargo.lock') -PathType Leaf) { ' --locked' } else { '' }
    Add-Step 'Cargo version' $cargo '--version'
    if ($ckCheck.Checked) { Add-Step 'Workspace check' $cargo "check --workspace$lock" }
    if ($ckTest.Checked) {
        for ($pass=1; $pass -le $script:machine.Repeat; $pass++) {
            Add-Step "Workspace tests ($pass/$($script:machine.Repeat))" $cargo "test --workspace$lock -- --nocapture" 'tests'
        }
    }
    if ($ckClippy.Checked) { Add-Step 'Clippy / warnings denied' $cargo "clippy --workspace --all-targets$lock -- -D warnings" }
}

function Confirm-StudioRun([string]$message) {
    return [Windows.Forms.MessageBox]::Show($form,$message,'Helyi futtatás jóváhagyása','YesNo','Question') -eq 'Yes'
}

$combo.Add_SelectedIndexChanged({ Update-TargetControls })
$combo.SelectedIndex = 0
$openSource.Add_Click({
    try {
        if (Test-LocalTarget) {
            $dialog = New-Object Windows.Forms.FolderBrowserDialog
            try {
                $dialog.Description = 'Válaszd ki a Cargo.toml fájlt tartalmazó mappát.'
                $dialog.ShowNewFolderButton = $false
                if ($localProject) { $dialog.SelectedPath=$localProject }
                if ($dialog.ShowDialog($form) -eq 'OK') { Set-LocalProject $dialog.SelectedPath }
            } finally { $dialog.Dispose() }
        } elseif ($combo.SelectedItem.Mode -eq 'github') {
            Add-Type -AssemblyName Microsoft.VisualBasic
            $address=[Microsoft.VisualBasic.Interaction]::InputBox('GitHub HTTPS-cím vagy tulajdonos/repó','Tesztelendő repó',$(if ($customTarget) {$customTarget.Origin} else {''}))
            if ($address.Trim()) { $script:customTarget=ConvertTo-RepositoryTarget $address; Update-TargetControls }
        } elseif ($combo.SelectedItem.Mode -eq 'belobug') {
            Start-Process 'https://github.com/Belobug/VIctory-Belobug-AMD'
        } else {
            Start-Process "https://github.com/VlREX/VIREX/commit/$($combo.SelectedItem.Preset.Sha)"
        }
    } catch { [Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'Tesztcél') | Out-Null }
})
