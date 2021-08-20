Import-Module -Name ActiveDirectory
#RSAT download https://www.microsoft.com/en-us/download/details.aspx?id=45520

$PCname = "*" # HOSTN* "-like" is being used so wildcard char is accepted
$DC = "DC01"     # DomainController
$AdminUser = "Domain\User" # Administrative user account
$ParalelLimit = 32

$Computers = Get-ADComputer -Filter "name -like '$PCname'" -Server $DC -Credential $AdminUser
#Get-ADComputer -Filter 'operatingsystem -notlike "*server*" -and enabled -eq "true"' -Properties Name,Operatingsystem,OperatingSystemVersion,IPv4Address,LastLogonDate | Sort-Object -Property Operatingsystem, LastLogonDate | Select-Object -Property Name,Operatingsystem,OperatingSystemVersion,IPv4Address,LastLogonDate

$DomainCompData = $null
$InvokeError = $null
$Time = $null

$Time = Measure-Command {
    $DomainCompData = Invoke-Command -ScriptBlock{
        
        try
        {
            $SecureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
            #$SecureBoot = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" | Select-Object -ExpandProperty UEFISecureBootEnabled   
        }
        catch
        {
            $SecureBoot = $false
        }

        $TPMver = Get-CimInstance -Namespace "root\CIMV2\Security\MicrosoftTpm" -ClassName Win32_Tpm | Select-Object Specversion
        #$TPMver = Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftTpm" -Class Win32_Tpm | Select-Object Specversion
        ######$TPMver = Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" | select-object *
        ######wmic /namespace:\\root\CIMV2\Security\MicrosoftTpm path Win32_Tpm get /value

        $WinInfo = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property Caption,Version,BuildNumber,OSArchitecture 
        #$WinInfo = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -Property Caption,Version,BuildNumber,OSArchitecture
        #systeminfo /fo csv | ConvertFrom-Csv | Select-Object -Property 'OS Name', 'OS Version', 'System Type', 'Domain', 'Logon Server'
        #wmic os get Caption,Version,BuildNumber,OSArchitecture

        $TPMverM = $TPMver.Specversion.Split(",")[0]
        $OSArch = $WinInfo.OSArchitecture -split ('\D+')
        
                        
        $PCinfo = New-Object PSObject

        $PCinfo | Add-Member NoteProperty "Hostname" $env:COMPUTERNAME
        $PCinfo | Add-Member NoteProperty "SecureBoot" $SecureBoot
        $PCinfo | Add-Member NoteProperty "TPM Version" $TPMverM
        #$PCinfo | Add-Member NoteProperty "TPM Version" $TPMver.Specversion
        $PCinfo | Add-Member NoteProperty "OS Name" $WinInfo.'Caption'
        $PCinfo | Add-Member NoteProperty "OS Version" $WinInfo.'Version'
        #$PCinfo | Add-Member NoteProperty "OS System Type" $WinInfo.'OSArchitecture'
        $PCinfo | Add-Member NoteProperty "OS System Type" $OSArch[0]
        $PCinfo | Add-Member NoteProperty "OS Build" $WinInfo.'BuildNumber'


        return $PCinfo
    } -ComputerName $Computers.Name -ErrorAction SilentlyContinue -ErrorVariable InvokeError -ThrottleLimit $ParalelLimit
}

Write-Host "It took $Time" -ForegroundColor Green
Write-Host "Tryed remotely on $($Computers.Count) Computers" -ForegroundColor Yellow
Write-Host "Succesfully recieved data from $($DomainCompData.Count) Computers" -ForegroundColor Green
Write-Host "With $($InvokeError.Count) errors. For error details use object 'InvokeError'" -ForegroundColor Red

Write-Host "Succesfully from:" -ForegroundColor Green
$DomainCompData | Select-Object -ExpandProperty Hostname

Write-Host "Unsuccesfully from:" -ForegroundColor Yellow
$InvokeError | Where-Object -Property CategoryInfo -Like "*PSRemotingTransportException*" | Select-Object -ExpandProperty TargetObject

$DomainCompData | Out-GridView
