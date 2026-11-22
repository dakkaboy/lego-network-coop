param([string]$GameFolder)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$form = [Windows.Forms.Form]::new()
$form.Text = 'Saga LAN'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = [Drawing.Size]::new(472, 218)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$grid = [Windows.Forms.TableLayoutPanel]::new()
$grid.Dock = 'Fill'
$grid.Padding = [Windows.Forms.Padding]::new(16)
$grid.ColumnCount = 2
$grid.RowCount = 5
[void]$grid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent', 100))
[void]$grid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('AutoSize'))
$form.Controls.Add($grid)

$folderLabel = [Windows.Forms.Label]::new()
$folderLabel.Text = 'Папка игры'
$folderLabel.AutoSize = $true
$grid.Controls.Add($folderLabel, 0, 0)

$folder = [Windows.Forms.TextBox]::new()
$folder.Text = $GameFolder
$folder.AccessibleName = $folderLabel.Text
$folder.Dock = 'Fill'
$grid.Controls.Add($folder, 0, 1)

$browse = [Windows.Forms.Button]::new()
$browse.Text = 'Выбрать'
$browse.AutoSize = $true
$browse.Add_Click({
    $dialog = [Windows.Forms.FolderBrowserDialog]::new()
    try {
        if ($dialog.ShowDialog($form) -eq 'OK') { $folder.Text = $dialog.SelectedPath }
    } finally {
        $dialog.Dispose()
    }
})
$grid.Controls.Add($browse, 1, 1)

$addressLabel = [Windows.Forms.Label]::new()
$addressLabel.Text = 'IPv4 хоста'
$addressLabel.AutoSize = $true
$grid.Controls.Add($addressLabel, 0, 2)

$address = [Windows.Forms.TextBox]::new()
$address.AccessibleName = $addressLabel.Text
$address.Text = '127.0.0.1'
$address.Dock = 'Fill'
$grid.Controls.Add($address, 0, 3)

$actions = [Windows.Forms.FlowLayoutPanel]::new()
$actions.AutoSize = $true
$actions.Padding = [Windows.Forms.Padding]::new(0, 8, 0, 0)
$grid.Controls.Add($actions, 0, 4)
$grid.SetColumnSpan($actions, 2)

$status = [Windows.Forms.Label]::new()
$status.AutoSize = $true
$grid.RowCount = 6
$grid.Controls.Add($status, 0, 5)
$grid.SetColumnSpan($status, 2)

function Start-SagaLan([string]$Role) {
    try {
        $status.Text = ''
        if (-not (Test-Path -LiteralPath $folder.Text -PathType Container)) {
            $status.Text = 'Выберите папку игры.'
            return
        }
        $directory = (Get-Item -LiteralPath $folder.Text -ErrorAction Stop).FullName
        $exe = Join-Path $directory 'LEGOStarWarsSaga.exe'
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
            $status.Text = 'В папке нет LEGOStarWarsSaga.exe.'
            return
        }
        if (-not (Test-Path -LiteralPath (Join-Path $directory 'd3d9.dll') -PathType Leaf)) {
            $status.Text = 'В папке нет d3d9.dll для Saga LAN.'
            return
        }
        $ip = $null
        $hostAddress = $address.Text.Trim()
        if (-not [Net.IPAddress]::TryParse($hostAddress, [ref]$ip) -or
            $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
            $ip.ToString() -ne $hostAddress -or
            $ip.Equals([Net.IPAddress]::Any) -or $ip.GetAddressBytes()[0] -ge 224) {
            $status.Text = 'Введите IPv4-адрес хоста.'
            return
        }
        if ($Role -eq 'host' -and -not [Net.IPAddress]::IsLoopback($ip)) {
            $assigned = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
                ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
                Where-Object { $_.Address.Equals($ip) } |
                Select-Object -First 1
            if (-not $assigned) {
                $status.Text = 'Этот адрес не назначен компьютеру хоста.'
                return
            }
        }

        $start = [Diagnostics.ProcessStartInfo]::new($exe)
        $start.WorkingDirectory = $directory
        $start.UseShellExecute = $false
        $start.EnvironmentVariables['COMPLETE_SAGA_LOCAL_INPUT'] = $Role
        $start.EnvironmentVariables['COMPLETE_SAGA_LAN_ADDRESS'] = $hostAddress
        [Diagnostics.Process]::Start($start).Dispose()
        $status.Text = 'Игра запущена.'
    } catch {
        $status.Text = 'Не удалось запустить игру.'
    }
}

$hostButton = [Windows.Forms.Button]::new()
$hostButton.Text = 'Создать игру'
$hostButton.AutoSize = $true
$hostButton.Add_Click({ Start-SagaLan 'host' })
$actions.Controls.Add($hostButton)

$joinButton = [Windows.Forms.Button]::new()
$joinButton.Text = 'Подключиться'
$joinButton.AutoSize = $true
$joinButton.Add_Click({ Start-SagaLan 'client' })
$actions.Controls.Add($joinButton)

try { [void]$form.ShowDialog() } finally { $form.Dispose() }
