New-VMSwitch -Name "NATSwitch" -SwitchType Internal

New-NetIPAddress -IPAddress 192.168.100.10 -PrefixLength 24 -InterfaceIndex 9
Remove-NetIPAddress -IPAddress 192.168.100.10 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"

New-NetNat -Name 'NATNetwork' -InternalIPInterfaceAddressPrefix 192.168.100.0/24

Get-NetAdapter
Get-VMSwitch
Get-NetNat
Remove-NetNat
Get-NetIPAddress | Where-Object -Property InterfaceAlias -Like "vEthernet (**Switch)"