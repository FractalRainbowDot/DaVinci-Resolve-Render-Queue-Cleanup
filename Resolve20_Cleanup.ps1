# Windows PowerShell 5.1 compatible, ASCII-only source.
# Deletes only directories whose name equals "Batch Renders" within the selected Resolve Projects library.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'DaVinci Resolve 20 - Render Queue Cleanup'
$form.Size = New-Object System.Drawing.Size(790, 455)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = 'Library folder (Resolve Projects):'
$label.Location = New-Object System.Drawing.Point(15, 16)
$label.AutoSize = $true
$form.Controls.Add($label)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(15, 40)
$pathBox.Size = New-Object System.Drawing.Size(645, 25)
$form.Controls.Add($pathBox)

$browse = New-Object System.Windows.Forms.Button
$browse.Text = 'Browse...'
$browse.Location = New-Object System.Drawing.Point(670, 38)
$browse.Size = New-Object System.Drawing.Size(95, 27)
$form.Controls.Add($browse)

$scan = New-Object System.Windows.Forms.Button
$scan.Text = 'Scan'
$scan.Location = New-Object System.Drawing.Point(15, 83)
$scan.Size = New-Object System.Drawing.Size(150, 33)
$form.Controls.Add($scan)

$delete = New-Object System.Windows.Forms.Button
$delete.Text = 'Delete Batch Renders'
$delete.Location = New-Object System.Drawing.Point(175, 83)
$delete.Size = New-Object System.Drawing.Size(205, 33)
$delete.Enabled = $false
$form.Controls.Add($delete)

$info = New-Object System.Windows.Forms.Label
$info.Location = New-Object System.Drawing.Point(15, 130)
$info.Size = New-Object System.Drawing.Size(735, 42)
$info.Text = 'Only exact folders named Batch Renders will be deleted. Close Resolve first.'
$form.Controls.Add($info)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(15, 180)
$logBox.Size = New-Object System.Drawing.Size(750, 205)
$logBox.Multiline = $true
$logBox.ScrollBars = 'Vertical'
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

$script:targets = @()
$script:scannedPath = ''
function LogLine([string]$msg) {
    $logBox.AppendText($msg + [Environment]::NewLine)
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
    $form.Refresh()
}
function ClearTargets {
    $script:targets = @()
    $script:scannedPath = ''
    $delete.Enabled = $false
}
$pathBox.Add_TextChanged({ ClearTargets })
$browse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the Resolve Projects folder'
    if ([IO.Directory]::Exists($pathBox.Text)) { $dialog.SelectedPath = $pathBox.Text }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $pathBox.Text = $dialog.SelectedPath }
    $dialog.Dispose()
})
$scan.Add_Click({
    ClearTargets
    $logBox.Clear()
    $p = $pathBox.Text.Trim().Trim('"')
    if (-not [IO.Directory]::Exists($p)) {
        [System.Windows.Forms.MessageBox]::Show('Folder not found. Paste a local folder path, not a web URL.', 'Invalid path', 'OK', 'Warning') | Out-Null
        return
    }
    try { $p = (Get-Item -LiteralPath $p -ErrorAction Stop).FullName } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Error', 'OK', 'Error') | Out-Null
        return
    }
    if ((Split-Path -Path $p -Leaf) -ne 'Resolve Projects' -or -not (Test-Path -LiteralPath (Join-Path $p 'Users') -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show('Select the Resolve Projects folder containing Users. No deletion performed.', 'Check library', 'OK', 'Warning') | Out-Null
        return
    }
    LogLine ('Scanning: ' + $p)
    try {
        $errors = @()
        $dirs = @(Get-ChildItem -LiteralPath (Join-Path $p 'Users') -Directory -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +errors | Where-Object { $_.Name -eq 'Batch Renders' -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
        if ($errors.Count -gt 0) {
            LogLine ('Scan warnings: ' + $errors.Count + '. Deletion disabled until a complete scan succeeds.')
            return
        }
        $script:targets = $dirs
        $script:scannedPath = $p
        LogLine ('Exact Batch Renders folders found: ' + $dirs.Count)
        LogLine 'Previously renamed/disabled folders are NOT selected.'
        if ($dirs.Count -gt 0) { $delete.Enabled = $true }
    } catch { LogLine ('ERROR: ' + $_.Exception.Message) }
})
$delete.Add_Click({
    if ($script:targets.Count -eq 0 -or $script:scannedPath -ne $pathBox.Text.Trim().Trim('"')) { ClearTargets; return }
    $process = Get-Process -Name Resolve -ErrorAction SilentlyContinue
    if ($process) {
        [System.Windows.Forms.MessageBox]::Show('Close DaVinci Resolve completely before deleting.', 'Resolve is running', 'OK', 'Warning') | Out-Null
        return
    }
    $msg = ('Permanently DELETE ' + $script:targets.Count + ' Batch Renders folders from:' + [Environment]::NewLine + $script:scannedPath + [Environment]::NewLine + [Environment]::NewLine + 'Render jobs/history inside them will be lost. Project.db is not targeted.' + [Environment]::NewLine + 'Continue?')
    if ([System.Windows.Forms.MessageBox]::Show($msg, 'Confirm permanent deletion', 'YesNo', 'Warning', 'Button2') -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $scan.Enabled = $false; $delete.Enabled = $false; $browse.Enabled = $false; $pathBox.Enabled = $false
    $ok = 0; $failed = 0
    foreach ($d in $script:targets) {
        try {
            if ((Split-Path -Leaf $d.FullName) -ne 'Batch Renders') { throw 'Unexpected folder name' }
            if (-not $d.FullName.StartsWith($script:scannedPath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected folder path' }
            # Do not follow a directory symlink/junction if one changed after scan.
            $live = Get-Item -LiteralPath $d.FullName -Force -ErrorAction Stop
            if ($live.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse point detected' }
            Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop
            $ok++
        } catch {
            $failed++
            LogLine ('FAILED: ' + $d.FullName + ' - ' + $_.Exception.Message)
        }
    }
    LogLine ('Done. Deleted: ' + $ok + ' | Failed: ' + $failed)
    ClearTargets
    $scan.Enabled = $true; $browse.Enabled = $true; $pathBox.Enabled = $true
    [System.Windows.Forms.MessageBox]::Show(('Deleted: ' + $ok + '. Failed: ' + $failed + '. Check details in the window.'), 'Finished', 'OK', 'Information') | Out-Null
})
[void]$form.ShowDialog()
