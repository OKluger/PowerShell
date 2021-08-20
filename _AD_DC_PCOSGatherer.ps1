#Get-ADObject (Get-ADRootDSE).schemaNamingContext -Property objectVersion #AD Schema Version
#Get-ADDomain | fl Name,DomainMode
#Get-ADForest | fl Name,ForestMode

$Computers = Get-ADComputer -Filter 'operatingsystem -notlike "*server*" -and enabled -eq "true"' -Properties Name,Operatingsystem,OperatingSystemVersion,IPv4Address,LastLogonDate | Sort-Object -Property Operatingsystem, LastLogonDate | Select-Object -Property Name,Operatingsystem,OperatingSystemVersion,IPv4Address,LastLogonDate
$Win10 = $Computers | Where-Object -Property Operatingsystem -Like "*Windows 10*"
$Win8 = $Computers | Where-Object -Property Operatingsystem -Like "*Windows 8*"
$Win7 = $Computers | Where-Object -Property Operatingsystem -Like "*Windows 7*"
$WinXP = $Computers | Where-Object -Property Operatingsystem -Like "*Windows XP*"

Write-Host "Computers in AD: $($Computers.Count)" -ForegroundColor Green
Write-Host "Win10: $($Win10.Count)" -ForegroundColor Green
Write-Host "Win8: $($Win8.Count)" -ForegroundColor Green
Write-Host "Win7: $($Win7.Count)" -ForegroundColor Green
Write-Host "WinXP: $($WinXP.Count)" -ForegroundColor Green