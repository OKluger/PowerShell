$DJoinUser = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($TSEnv:OSDJoinAccount))
$DJoinPass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($TSEnv:OSDJoinPassword))
Write-Host "Join user from MDT: $DJoinUser"
Write-Host "Join pass from MDT: *****"

$JoinPass = ConvertTo-SecureString $DJoinPass -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($DJoinUser,$JoinPass)

$OU = $TSEnv:MachineObjectOU
$Domain = $TSEnv:JoinDomain
Write-Host "Cilova OU: $OU"
Write-Host "Cilova domena: $Domain" 

$Result = Add-Computer -DomainName $Domain -OUPath $OU -Credential $Credential -Force -PassThru -Verbose -ErrorAction silentlycontinue
Write-Host $Result