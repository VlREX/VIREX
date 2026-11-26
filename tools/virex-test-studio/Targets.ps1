$belobugTarget=ConvertTo-RepositoryTarget 'Belobug/VIctory-Belobug-AMD'
$belobugTarget.Branch='a-publier'
$script:customTarget=$null
$script:revisionTarget=$null
function Test-LocalTarget { return $combo.SelectedItem.Mode -eq 'local' }
function Test-WorkspaceTarget { return $combo.SelectedItem.Mode -ne 'pinned' }
function Get-SelectedRepository {
    if ($combo.SelectedItem.Mode -eq 'belobug') { return $belobugTarget }
    if ($combo.SelectedItem.Mode -eq 'revision') { return $script:revisionTarget }
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
            $openSource.Text = if ($combo.SelectedItem.Mode -eq 'belobug') { 'Repó megnyitása' } elseif ($combo.SelectedItem.Mode -eq 'revision') { 'PR Manager megnyitása' } else { 'GitHub-cím megadása…' }
            $revision.Text = if ($target) { "$($target.Name)$([Environment]::NewLine)Ág: $($target.Branch)" } else { 'Add meg a tesztelendő GitHub-címet.' }
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
        } elseif ($combo.SelectedItem.Mode -eq 'revision') {
            $tabs.SelectedTab=$prTab
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

# PR Manager never starts a build or uploads anything on its own.
$prTab=New-ReviewPage $tabs 'PR Manager'
$prPanel=New-Object Windows.Forms.Panel
$prPanel.Dock='Fill'; $prPanel.AutoScroll=$true
$prTab.Controls.Add($prPanel)
$prLayout=New-Stack $prPanel 'TopDown' $false
$prLayout.AutoSize=$true; $prLayout.AutoSizeMode='GrowAndShrink'
$prLayout.Padding=New-Object Windows.Forms.Padding(16,12,10,12)
$null=New-Caption $prLayout 'PR / fejlesztői ág / commit tesztelése' 13 $fg $true
$prHint=New-Caption $prLayout 'Illeszd be a GitHub-linket. A Studio lekéri a kiválasztott revíziót, és rögzíti a tényleges SHA-t. A PR headet teszteli, nem a merge eredményét.' 9 $muted
$prHint.MaximumSize=New-Object Drawing.Size(360,0)
$prAddress=New-Object Windows.Forms.TextBox
$prAddress.Width=360; $prAddress.MaxLength=400; $prLayout.Controls.Add($prAddress)
$prSelect=New-Action $prLayout 'Tesztcél betöltése' '#245B58' 190
$prLink=New-Action $prLayout 'Belobug PR-lista' '#29414E' 190
$prStatus=New-Caption $prLayout 'Nincs kiválasztott revízió.' 9 $cyan
$prStatus.MaximumSize=New-Object Drawing.Size(360,0)
$prLink.Add_Click({ Start-Process 'https://github.com/Belobug/VIctory-Belobug-AMD/pulls' })
$prSelect.Add_Click({
    if ($script:runState -eq 'RUNNING' -or $script:updateWorker -or $script:unsafeState) { return }
    try {
        $target=ConvertTo-RevisionTarget $prAddress.Text
        $script:revisionTarget=$target
        $choice=@($combo.Items | Where-Object { $_.Mode -eq 'revision' })[0]
        $combo.SelectedItem=$choice
        Update-TargetControls
        $prStatus.Text="Betöltve: $($target.Name) - $($target.Branch)"
        $foot.Text='A kiválasztott revízió teszteléséhez kattints a Futtatás gombra.'
    } catch { $prStatus.Text=$_.Exception.Message }
})
