#############################################################################################
## PowerShell Script
## Release 0.1
#############################################################################################

$configFilePath = "Setup.conf"
$configContent = Get-Content -Path $configFilePath | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne "" }
$configHashTable = @{}

foreach ($line in $configContent) {
    # Split the line into key and value based on the '=' character
    $key, $value = $line -split '='

    # Trim any whitespace from the key and value
    $key = $key.Trim()
    $value = $value.Trim()

    # Add the key-value pair to the hashtable
    $configHashTable[$key] = $value
}
$configHashTable["SVM1"]
$configHashTable["DOMAIN"]

New-ADGroup -Name Unix -GroupScope DomainLocal -OtherAttributes @{'gidnumber'='10001'}
Get-ADGroup Unix -Properties gidNumber

$password = ConvertTo-SecureString "Netapp1!" -AsPlainText -Force

New-ADUser -SamAccountName user1 -UserPrincipalName user1@DEMO.NETAPP.COM -Name user1 -AccountPassword $password -OtherAttributes @{'uid'="user1";'uidNumber'="10001";'gidNumber'="10001";'unixHomeDirectory'='/home/user1';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

New-ADUser -SamAccountName user2 -UserPrincipalName user2@DEMO.NETAPP.COM -Name user2 -AccountPassword $password -OtherAttributes @{'uid'="user2";'uidNumber'="10002";'gidNumber'="10001";'unixHomeDirectory'='/home/user2';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

New-ADUser -SamAccountName user3 -UserPrincipalName user3@DEMO.NETAPP.COM -Name user3 -AccountPassword $password -OtherAttributes @{'uid'="user3";'uidNumber'="10003";'gidNumber'="10001";'unixHomeDirectory'='/home/user3';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

# Add DNS Entry for Kerberos IP (Mut be validated)
$NFSKerberosName="NFS-" + $configHashTable["SVM1"]
$SVMipAddress = [System.Net.Dns]::GetHostAddresses($configHashTable["SVM1"]).IPAddressToString
$DCname = "DC1." + $configHashTable["DOMAIN"]
Add-DnsServerResourceRecordA -Name $NFSKerberosName -IPv4Address $SVMipAddress -ZoneName $configHashTable["DOMAIN"] -ComputerName $DCname 
$reverseZone = $SVMipAddress.split('.')[2] + "." + $SVMipAddress.split('.')[1] + "." + $SVMipAddress.split('.')[0] + ".in-addr.arpa"
$reverseRecordName = $SVMipAddress.split('.')[3] 
Add-DnsServerResourceRecordPtr -Name $reverseRecordName -PtrDomainName $NFSKerberosName -ZoneName $reverseZone -ComputerName $DCname 
