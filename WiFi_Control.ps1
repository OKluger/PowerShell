function Get-WifiNetwork {
 end {
  netsh wlan sh net mode=bssid | % -process {
    if ($_ -match '^SSID (\d+) : (.*)$') {
        $current = @{}
        $networks += $current
        $current.Index = $matches[1].trim()
        $current.SSID = $matches[2].trim()
    } else {
        if ($_ -match '^\s+(.*)\s+:\s+(.*)\s*$') {
            $current[$matches[1].trim()] = $matches[2].trim()
        }
    }
  } -begin { $networks = @() } -end { $networks|% { new-object psobject -property $_ } }
 }
}

function Get-WifiNetworkPS
{
    #[CmdletBinding()] Param ([Parameter(Mandatory=$true)][ValidateSet('Off', 'On')][string]$WifiStatus)
    # https://www.reddit.com/r/sysadmin/comments/9az53e/need_help_controlling_wifi/
    $WifiStatus = "On"
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? {$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'})[0]

    Function Await($WinRtTask, $ResultType)
    {
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }

    [Windows.Devices.Radios.Radio,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
    [Windows.Devices.Radios.RadioAccessStatus,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null
    Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]) | Out-Null
    $radios = Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync())([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
    $wifi = $radios | ? { $_.Kind -eq 'WiFi' }
    [Windows.Devices.Radios.RadioState,Windows.System.Devices,ContentType=WindowsRuntime] | Out-Null

    # necessary since Windows will automatically enable the status of a wifi device when the wired connection is lost
    # Start-Sleep -Seconds 10
    # Await ($wifi.SetStateAsync($WifiStatus)) ([Windows.Devices.Radios.RadioAccessStatus])
    if ($wifi.State -eq "On") {
      [Windows.Devices.WiFi.WiFiAdapter,Windows.System.Devices,Contenttype=WindowsRuntime] | Out-Null
      $Res=Await ([Windows.Devices.WiFi.WiFiAdapter]::FindAllAdaptersAsync())([System.Collections.Generic.IReadOnlyList[Windows.Devices.WiFi.WiFiAdapter]])
      $wifi = $res.NetworkReport.AvailableNetworks | Select-Object -ExpandProperty SecuritySettings -Property ssid, NetworkRssiInDecibelMilliwatts | Sort-Object -Property SSID -Unique
      $wifi | Sort-Object NetworkRssiInDecibelMilliwatts -Descending
    }
}

function ConnectToSSID
{
    param(
        [string]$SSID,
        [string]$PSK
    )
    $guid = New-Guid
    $HexArray = $ssid.ToCharArray() | foreach-object { [System.String]::Format("{0:X}", [System.Convert]::ToUInt32($_)) }
    $HexSSID = $HexArray -join ""
@"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$($SSID)</name>
    <SSIDConfig>
        <SSID>
            <hex>$($HexSSID)</hex>
            <name>$($SSID)</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$($PSK)</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
    <MacRandomization xmlns="http://www.microsoft.com/networking/WLAN/profile/v3">
        <enableRandomization>false</enableRandomization>
        <randomizationSeed>1451755948</randomizationSeed>
    </MacRandomization>
</WLANProfile>
"@ | out-file "$($ENV:TEMP)\$guid.SSID"
return $guid
}

if (Test-Connection 1.1.1.1 -Count 1 -ErrorAction SilentlyContinue)
{
    exit
}
else
{
    [Microsoft.VisualBasic.Interaction]::MsgBox('Internet connection mandatory! Starting WiFi Prompt',('OKCancel,SystemModal,Critical'),'Warning')
}

$WiFiNetworks = Get-WifiNetwork | Select-Object authentication, ssid, signal, 'radio type' | sort signal -desc
###############$WiFiNetworks = Get-WifiNetworkPS | Select-Object Ssid, NetworkRssiInDecibelMilliwatts, NetworkAuthenticationType, NetworkEncryptionType

Add-Type -AssemblyName System.Windows.Forms
Add-type -AssemblyName Microsoft.VisualBasic

$SelectionForm = New-Object System.Windows.Forms.Form
$SelectionForm.Text = "Prepare New MSPD"
$SelectionForm.StartPosition = 'CenterScreen'
$SelectionForm.Size = '620,350'
$SelectionForm.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")

$WifiGrid = New-Object System.Windows.Forms.DataGridView
$WifiGrid.Location = '20, 20'
$WifiGrid.Size = '560,200'
$WifiGrid.ColumnCount = 4
$WifiGrid.Columns[0].Name = "Signal"
$WifiGrid.Columns[1].Name = "SSID"
$WifiGrid.Columns[1].Width = '200'
$WifiGrid.Columns[2].Name = "Radio Type"
$WifiGrid.Columns[3].Name= "Authentication"
$WifiGrid.SelectionMode = "FullROwSelect"
$WifiGrid.ReadOnly = $true
$WifiGrid.AllowUserToAddRows = $false
$WifiGrid.MultiSelect = $false

$Connect = New-Object System.Windows.Forms.Button
$Connect.Location = '20,240'
$Connect.Size = '560,30'
$Connect.Text = "CONNECT!"

#Fill WiFi Networks
$WiFiGrid.Rows.Clear()
$WiFiNetworks | Where-Object -property Authentication -EQ "WPA2-Personal" | foreach{$WifiGrid.Rows.Add($_.signal,$_.ssid,$_.authentication,$_.'radio type')}
###############$WiFiNetworks | Where-Object -property NetworkAuthenticationType -EQ "RsnaPsk" | foreach{$WifiGrid.Rows.Add($_.NetworkRssiInDecibelMilliwatts,$_.ssid,$_.NetworkAuthenticationType)}
$WifiGrid.update()
$WifiGrid.Refresh()

$SelectionForm.Controls.Add($WifiGrid)
$SelectionForm.Controls.Add($Connect)

$Connect.add_Click(
    {
        $SelectedWiFi = $WifiGrid.SelectedRows | Select-Object -ExpandProperty Cells | Where-Object -Property ColumnIndex -EQ 1 | Select-Object -ExpandProperty FormattedValue

        $title = 'Wifi Password Prompt'
        $msg   = "Enter WiFi Password for: $SelectedWiFi"

        $Connect.Text = "Enter WiFi Password!"

        $text = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)

        $Connect.Text = "Trying to connect!"

        if ($text -ne "")
        {
            Write-Host $text
            $guid = ConnectToSSID $SelectedWiFi $text
            netsh wlan add profile filename="$($ENV:TEMP)\$guid.SSID" user=all

            netsh wlan connect ssid="$SelectedWiFi" name="$SelectedWiFi"

            for ($i = 10; $i -gt 0; $i--)
            { 
                Start-Sleep -Seconds 1
                $Connect.Text = "Trying to connect! $i"
            }
            
            $Connect.Text = "Testing Connection..."

            if (Test-Connection 1.1.1.1 -Count 1 -ErrorAction SilentlyContinue)
            {
                $SelectionForm.Close()
            }
            else
            {
                netsh wlan delete profile "$SelectedWiFi"
                [Microsoft.VisualBasic.Interaction]::MsgBox('Connection unsuccessful or no internet connection!',('OkCancel,SystemModal,Critical'),'Warning')
            }

            $Connect.Text = "CONNECT!"
        }
    }
)

$SelectionForm.ShowDialog()
