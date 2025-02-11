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

try {
    $groupObject = Get-ADGroup Unix -ErrorAction Stop 
    Write-Output "Unix Group already exists on"
} catch {
   New-ADGroup -Name Unix -GroupScope DomainLocal -OtherAttributes @{'gidnumber'='10001'}
   Get-ADGroup Unix -Properties gidNumber
}

$password = ConvertTo-SecureString "Netapp1!" -AsPlainText -Force


try {
    $userObject = Get-ADUser -Identity user1 -ErrorAction Stop
    Write-Output "user1 already exists on"
} catch {
    Write-Output "user1 create"
    New-ADUser -SamAccountName user1 -UserPrincipalName user1@DEMO.NETAPP.COM -Name user1 -AccountPassword $password -OtherAttributes @{'uid'="user1";'uidNumber'="10001";'gidNumber'="10001";'unixHomeDirectory'='/home/user1';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1
}

try {
    $userObject = Get-ADUser -Identity user2 -ErrorAction Stop
    Write-Output "user2 already exists on"
} catch {
    Write-Output "user2 create"
    New-ADUser -SamAccountName user2 -UserPrincipalName user2@DEMO.NETAPP.COM -Name user2 -AccountPassword $password -OtherAttributes @{'uid'="user2";'uidNumber'="10002";'gidNumber'="10001";'unixHomeDirectory'='/home/user2';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1
}

try {
    $userObject = Get-ADUser -Identity user3 -ErrorAction Stop
    Write-Output "user3 already exists on"
} catch {
    Write-Output "user3 create"
    New-ADUser -SamAccountName user3 -UserPrincipalName user3@DEMO.NETAPP.COM -Name user3 -AccountPassword $password -OtherAttributes @{'uid'="user3";'uidNumber'="10003";'gidNumber'="10001";'unixHomeDirectory'='/home/user3';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1
}

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


$ptrRecords = Get-DnsServerResourceRecord -ComputerName $DCname -ZoneName $reverseZone -Name $reverseRecordName -RRType "PTR" -ErrorAction SilentlyContinue
$matchingRecord = $ptrRecords | Where-Object { $_.RecordData.PtrDomainName -eq $NFSKerberosNameFQDN + "." }

if ($matchingRecord) {
    Write-Output "The 'PTR' record for $reverseRecordName exists in the $reverseZone zone on $DCname."
} else {
    Write-Output "Create a new PTR DNS entry"
	Add-DnsServerResourceRecordPtr -Name $reverseRecordName -PtrDomainName $NFSKerberosNameFQDN -ZoneName $reverseZone -ComputerName $DCname
}

# Add DNS Entry for Kerberos Linux IP
$record = Get-DnsServerResourceRecord -ComputerName $DCname -ZoneName $configHashTable["DOMAIN"] -Name $configHashTable["LINUX_HOSTNAME"] -RRType "A" -ErrorAction SilentlyContinue
if ($record) {
    $hostname=$configHashTable["LINUX_HOSTNAME"]
    Write-Output "The 'A' record for $hostname already exists on $DCname."
} else {
    Write-Output "Create 'A' DNS entry"
    Add-DnsServerResourceRecordA -Name $configHashTable["LINUX_HOSTNAME"] -IPv4Address $configHashTable["LINUX_IP"] -ZoneName $configHashTable["DOMAIN"] -ComputerName $DCname
}

$reverseZone = $configHashTable["LINUX_IP"].split('.')[2] + "." + $configHashTable["LINUX_IP"].split('.')[1] + "." + $configHashTable["LINUX_IP"].split('.')[0] + ".in-addr.arpa"
$reverseRecordName = $configHashTable["LINUX_IP"].split('.')[3]
$LinuxNameFQDN=$configHashTable["LINUX_HOSTNAME"] + "." + $configHashTable["DOMAIN"]

$ptrRecords = Get-DnsServerResourceRecord -ComputerName $DCname -ZoneName $reverseZone -Name $reverseRecordName -RRType "PTR" -ErrorAction SilentlyContinue
$matchingRecord = $ptrRecords | Where-Object { $_.RecordData.PtrDomainName -eq $linuxNameFQDN + "." }
if ($matchingRecord) {
    Write-Output "The 'PTR' record for $reverseRecordName exists in the $reverseZone zone on $DCname."
} else {
    Write-Output "Create a new PTR DNS entry"
    Add-DnsServerResourceRecordPtr -Name $reverseRecordName -PtrDomainName $LinuxNameFQDN -ZoneName $reverseZone -ComputerName $DCname
}
