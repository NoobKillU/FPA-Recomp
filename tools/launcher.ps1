Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Fancy Pants Adventures'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(520, 360)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

function Add-Label($text, $x, $y, $width = 150) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.Location = New-Object System.Drawing.Point($x, $y)
    $label.Size = New-Object System.Drawing.Size($width, 24)
    $form.Controls.Add($label)
    return $label
}

function Add-TextBox($x, $y, $width) {
    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($x, $y)
    $box.Size = New-Object System.Drawing.Size($width, 24)
    $form.Controls.Add($box)
    return $box
}

function Add-Button($text, $x, $y, $width, $height, $handler) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    $button.Location = New-Object System.Drawing.Point($x, $y)
    $button.Size = New-Object System.Drawing.Size($width, $height)
    $button.Add_Click($handler)
    $form.Controls.Add($button)
    return $button
}

Add-Label 'Game executable' 16 18 130 | Out-Null
$exeBox = Add-TextBox 16 42 385
$defaultExe = Join-Path $PSScriptRoot '..\out\build\win-amd64-release\fpa_recomp.exe'
if (Test-Path -LiteralPath $defaultExe) {
    $exeBox.Text = (Resolve-Path -LiteralPath $defaultExe).Path
} elseif (Test-Path -LiteralPath (Join-Path $PSScriptRoot '..\fpa_recomp.exe')) {
    $exeBox.Text = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\fpa_recomp.exe')).Path
}
Add-Button 'Browse…' 411 40 92 27 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = 'Game executable (fpa_recomp.exe)|fpa_recomp.exe|Executable files (*.exe)|*.exe'
    $dialog.Title = 'Select the recompiled game executable'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $exeBox.Text = $dialog.FileName
        if (-not $gameBox.Text) { $gameBox.Text = Split-Path -Parent $dialog.FileName }
    }
} | Out-Null

Add-Label 'Game files folder' 16 78 150 | Out-Null
$gameBox = Add-TextBox 16 102 385
Add-Button 'Browse…' 411 100 92 27 {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the folder containing the game files'
    $dialog.ShowNewFolderButton = $false
    if ($exeBox.Text -and (Test-Path -LiteralPath $exeBox.Text)) {
        $dialog.SelectedPath = Split-Path -Parent $exeBox.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $gameBox.Text = $dialog.SelectedPath
    }
} | Out-Null
Add-Label 'The folder can be beside the executable or elsewhere.' 16 129 480 | Out-Null

Add-Label 'Resolution' 16 170 110 | Out-Null
$resolutionBox = New-Object System.Windows.Forms.ComboBox
$resolutionBox.Location = New-Object System.Drawing.Point(16, 194)
$resolutionBox.Size = New-Object System.Drawing.Size(145, 26)
$resolutionBox.DropDownStyle = 'DropDownList'
[void]$resolutionBox.Items.AddRange([string[]]@('720p', '1080p', '1440p', '4k', '1280x720'))
$resolutionBox.SelectedItem = '720p'
$form.Controls.Add($resolutionBox)

$fullscreenBox = New-Object System.Windows.Forms.CheckBox
$fullscreenBox.Text = 'Fullscreen'
$fullscreenBox.Location = New-Object System.Drawing.Point(184, 196)
$fullscreenBox.Size = New-Object System.Drawing.Size(120, 24)
$form.Controls.Add($fullscreenBox)

Add-Label 'Controller' 16 232 100 | Out-Null
$inputBox = New-Object System.Windows.Forms.ComboBox
$inputBox.Location = New-Object System.Drawing.Point(16, 256)
$inputBox.Size = New-Object System.Drawing.Size(145, 26)
$inputBox.DropDownStyle = 'DropDownList'
[void]$inputBox.Items.AddRange([string[]]@('SDL (recommended)', 'XInput'))
$inputBox.SelectedIndex = 0
$form.Controls.Add($inputBox)

$asyncBox = New-Object System.Windows.Forms.CheckBox
$asyncBox.Text = 'Async shader compilation'
$asyncBox.Location = New-Object System.Drawing.Point(184, 258)
$asyncBox.Size = New-Object System.Drawing.Size(220, 24)
$asyncBox.Checked = $true
$form.Controls.Add($asyncBox)

$waitBox = New-Object System.Windows.Forms.CheckBox
$waitBox.Text = 'Wait for GPU pipelines (may reduce missing draws)'
$waitBox.Location = New-Object System.Drawing.Point(16, 295)
$waitBox.Size = New-Object System.Drawing.Size(390, 24)
$waitBox.Checked = $false
$form.Controls.Add($waitBox)

$status = Add-Label '' 16 330 320
$launch = Add-Button 'Save settings and launch' 342 324 161 30 {
    $exe = $exeBox.Text.Trim()
    $gameRoot = $gameBox.Text.Trim()
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        [System.Windows.Forms.MessageBox]::Show('Choose a valid fpa_recomp.exe first.', 'Executable not found', 'OK', 'Warning') | Out-Null
        return
    }
    if (-not (Test-Path -LiteralPath $gameRoot -PathType Container)) {
        [System.Windows.Forms.MessageBox]::Show('Choose the folder containing your game files.', 'Game folder not found', 'OK', 'Warning') | Out-Null
        return
    }

    $quote = { param($value) '"' + $value.Replace('\', '\\').Replace('"', '\"') + '"' }
    $inputBackend = if ($inputBox.SelectedIndex -eq 1) { 'xinput' } else { 'sdl' }
    $lines = @(
        "resolution = $(& $quote $resolutionBox.SelectedItem.ToString())"
        "fullscreen = $($fullscreenBox.Checked.ToString().ToLowerInvariant())"
        "input_backend = $(& $quote $inputBackend)"
        "async_shader_compilation = $($asyncBox.Checked.ToString().ToLowerInvariant())"
        "d3d12_pipeline_creation_wait = $($waitBox.Checked.ToString().ToLowerInvariant())"
        'd3d12_pipeline_creation_threads = 2'
        'anisotropic_override = 0'
        'clear_memory_page_state = false'
        'mnk_mode = true'
        'keybind_lstick_up = "Up"'
        'keybind_lstick_down = "Down"'
        'keybind_lstick_left = "Left"'
        'keybind_lstick_right = "Right"'
        'keybind_a = "S"'
        'keybind_x = "A"'
        'keybind_start = "Return"'
    )
    $configPath = Join-Path (Split-Path -Parent $exe) 'fpa_recomp.toml'
    try {
        [System.IO.File]::WriteAllLines($configPath, $lines, [System.Text.UTF8Encoding]::new($false))
        $env:FPA_GAME_ROOT = $gameRoot
        Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) | Out-Null
        $status.Text = 'Settings saved. Game launched.'
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Could not launch', 'OK', 'Error') | Out-Null
    } finally {
        Remove-Item Env:FPA_GAME_ROOT -ErrorAction SilentlyContinue
    }
}

[void]$form.ShowDialog()
