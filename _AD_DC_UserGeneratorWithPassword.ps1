Add-Type -AssemblyName System.web #Password generator prerequisity

#Measure-Command -Expression {

#Name variables (multiple values)
$First = "Petr","Vlastimil","Josef","Karel","Jiri","Ondrej","Pavel","Adam","Vaclav","Libor","Zdenek","Krystof","Frantisek","Andrej"
#Surname variables (multiple values)
$Last = "Novak","Kluger","Vomacka","Skopek","Klaus","Novotny","Stafek","Lala","Peroutka","Zeman","Ovcacek","Babis","Kalousek","Feri"
#Department Variables (multiple values)
$Dept = "Uctarna","IT","Vedeni","Vyroba"

$message  = 'Generate ADUser'
$question = 'This script will generate ADUser with these accordingly to user settings!!!'
$choices  = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
    Write-Host 'Script confirmed' -ForegroundColor Green
} else {
    Write-Host 'Script cancelled' -ForegroundColor Red
    exit
}

###START OF MAIN CODE###START OF MAIN CODE###START OF MAIN CODE###START OF MAIN CODE###START OF MAIN CODE###START OF MAIN CODE###START OF MAIN CODE###START OF MAIN CODE###
$UsrCount = Read-Host -Prompt 'How many users?'

if ($Domain = Get-ADOrganizationalUnit -Filter 'Name -like "Domain Controllers"' | Select-Object -ExpandProperty DistinguishedName){$Domain = $Domain.Substring(22)}
else 
{
    Write-Host "No Domain Detected" -ForegroundColor Red
    exit
}

if (!(Get-ADOrganizationalUnit -Filter 'Name -like "Generated_Users"')) {New-ADOrganizationalUnit -Name "Generated_Users" -ProtectedFromAccidentalDeletion 0}

For ($i=1; $i -le $UsrCount; $i++)
{
    $Var++
    Try
    {
        $RanFirst = Get-Random -Minimum 0 -Maximum $First.Count
        $RanLast = Get-Random -Minimum 0 -Maximum $Last.Count
        $RanDept = Get-Random -Minimum 0 -Maximum $Dept.Count

        $Name = $First[$RanFirst] + ' ' + $Last[$RanLast]
        if (Get-ADUser -filter {Name -eq $Name})
        {
            $x=1
            DO
            {
                $Name = $First[$RanFirst]+$x + ' ' + $Last[$RanLast]
                $x++
            }
            until(!(Get-ADUser -filter {Name -eq $Name}))
        }

        $UserID = $First[$RanFirst].Substring(0,$First.Length-($first.Length-1)) + $Last[$RanLast]
        if (Get-ADUser -filter {SamAccountName -eq $UserID})
        {
            $x=2
            DO
            {
                $UserID = $First[$RanFirst].Substring(0,$First.Length-($first.Length-$x)) + $Last[$RanLast]
                $x++
            }
            until(!(Get-ADUser -filter {SamAccountName -eq $UserID}) -or ($x -ge $First.Length-1))
        }
        $UPN =('{0}@Firma.cz') -f $UserID

        $DisName = $Name
        $pass = [System.Web.Security.Membership]::GeneratePassword(8,2)

        New-ADUser -GivenName $First[$RanFirst] -Surname $Last[$RanLast] -Department $Dept[$RanDept] `
                    -Name $Name -SamAccountName $UserID -AccountPassword $(ConvertTo-SecureString $pass -AsPlainText -Force)`
                    -UserPrincipalName $UPN -DisplayName $DisName -Enabled $true -Description ("Password:"+" "+$pass) `
                    -Path ("OU=Generated_Users" + ", " + $Domain) -ChangePasswordAtLogon 1
        
        Get-ADUser -filter {SamAccountName -eq $UserID} -Properties DistinguishedName,Enabled,GivenName,Name,ObjectClass,ObjectGUID,SamAccountName,SID,Surname,UserPrincipalName,Description `
                    | Export-Csv -Path $($env:USERPROFILE.ToString() + "\Desktop\NewADUsers.csv") -Append -NoTypeInformation -Encoding UTF8

        $UserID + ' as ' + $Name + '; Department: ' + $Dept[$RanDept]
        
    }
    Catch { (Write-Host Error Occured Creating $UserID as $Name !!! -ForegroundColor Red) + ($i--)}
}

$message  = 'Generated User move'
$question = 'Move generated ADUser to department OU accordingly???'
$choices  = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
    Write-Host 'Script confirmed' -ForegroundColor Green
} else {
    Write-Host 'Script cancelled' -ForegroundColor Red
    exit
}

Write-Host "Enter Path of where to move generated ADUser (like OU=Company_Users,DC=company,DC=com)" -ForegroundColor Yellow
$OUPath = Read-Host -Prompt 'Enter path'

###START OF SECONDARY CODE###START OF SECONDARY CODE###START OF SECONDARY CODE###START OF SECONDARY CODE###START OF SECONDARY CODE###START OF SECONDARY CODE###START OF SECONDARY CODE
$UNames = get-aduser -Filter * -SearchBase ("OU=Generated_users" +"," + $Domain) | Select-Object -ExpandProperty DistinguishedName

if ($UNames -eq $null)
{
    Write-Host "No generated Users for moving!!!" -ForegroundColor Red
}
else
{
    try
    {
        foreach ($UName in $UNames)
        {
            #$Jmeno
            $UDept = Get-ADUser -Identity $UName -Properties * | Select-Object -ExpandProperty Department
            
            if (!(Get-ADOrganizationalUnit -Filter 'Name -like $UDept')) {New-ADOrganizationalUnit -Name $UDept -Path $OUPath -ProtectedFromAccidentalDeletion 0}
            #$Dept 
            Move-ADObject -Identity $UName -TargetPath ("OU=" + $UDept +"," + $OUPath)
        }
    }
    Catch {Write-Host ("Error running the script!!!" + "`n`n" + $PSItem) -ForegroundColor Red}
}