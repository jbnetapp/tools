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
$configHashTable["LINUX_HOSTNAME"]
$configHashTable["LINUX_IP"]

New-ADGroup -Name Unix -GroupScope DomainLocal -OtherAttributes @{'gidnumber'='10001'}
Get-ADGroup Unix -Properties gidNumber

$password = ConvertTo-SecureString "Netapp1!" -AsPlainText -Force

New-ADUser -SamAccountName user1 -UserPrincipalName user1@DEMO.NETAPP.COM -Name user1 -AccountPassword $password -OtherAttributes @{'uid'="user1";'uidNumber'="10001";'gidNumber'="10001";'unixHomeDirectory'='/home/user1';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

New-ADUser -SamAccountName user2 -UserPrincipalName user2@DEMO.NETAPP.COM -Name user2 -AccountPassword $password -OtherAttributes @{'uid'="user2";'uidNumber'="10002";'gidNumber'="10001";'unixHomeDirectory'='/home/user2';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

New-ADUser -SamAccountName user3 -UserPrincipalName user3@DEMO.NETAPP.COM -Name user3 -AccountPassword $password -OtherAttributes @{'uid'="user3";'uidNumber'="10003";'gidNumber'="10001";'unixHomeDirectory'='/home/user3';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

# Add DNS Entry for Kerberos SVM IP
$NFSKerberosName="NFS-" + $configHashTable["SVM1"]
$SVMipAddress = [System.Net.Dns]::GetHostAddresses($configHashTable["SVM1"]).IPAddressToString
$DCname = "DC1." + $configHashTable["DOMAIN"]

$record = Get-DnsServerResourceRecord -ComputerName $DCname -ZoneName $configHashTable["DOMAIN"] -Name $NFSKerberosName -RRType "A" -ErrorAction SilentlyContinue

if ($record) {
    Write-Output "The 'A' record for $NFSKerberosName already exists on $DCname."
} else {
    Write-Output "Create 'A' DNS entry"
	Add-DnsServerResourceRecordA -Name $NFSKerberosName -IPv4Address $SVMipAddress -ZoneName $configHashTable["DOMAIN"] -ComputerName $DCname 
}


$reverseZone = $SVMipAddress.split('.')[2] + "." + $SVMipAddress.split('.')[1] + "." + $SVMipAddress.split('.')[0] + ".in-addr.arpa"
$reverseRecordName = $SVMipAddress.split('.')[3] 
$NFSKerberosNameFQDN=$NFSKerberosName + "." + $configHashTable["DOMAIN"]


$record = Get-DnsServerResourceRecord -ComputerName $DCname -ZoneName $reverseZone -Name $reverseRecordName -RRType "PTR" -ErrorAction SilentlyContinue

# Check if the record exists
if ($record) {
    Write-Output "The 'PTR' record for $recordName exists in the $zoneName zone on $dnsServer."
} else {
    Write-Output "Create a new PTR DNS entry"
	Add-DnsServerResourceRecordPtr -Name $reverseRecordName -PtrDomainName $NFSKerberosNameFQDN -ZoneName $reverseZone -ComputerName $DCname

}

# Add DNS Entry for Kerberos Linux IP
Add-DnsServerResourceRecordA -Name $configHashTable["LINUX_HOSTNAME"] -IPv4Address $configHashTable["LINUX_IP"] -ZoneName $configHashTable["DOMAIN"] -ComputerName $DCname
$reverseZone = $configHashTable["LINUX_IP"].split('.')[2] + "." + $configHashTable["LINUX_IP"].split('.')[1] + "." + $configHashTable["LINUX_IP"].split('.')[0] + ".in-addr.arpa"
$reverseRecordName = $configHashTable["LINUX_IP"].split('.')[3]
$LinuxNameFQDN=$configHashTable["LINUX_HOSTNAME"] + "." + $configHashTable["DOMAIN"]

Add-DnsServerResourceRecordPtr -Name $reverseRecordName -PtrDomainName $LinuxNameFQDN -ZoneName $reverseZone -ComputerName $DCname
