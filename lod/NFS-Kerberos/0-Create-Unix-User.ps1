#############################################################################################
## PowerShell Script
## Release 0.1
#############################################################################################

New-ADGroup -Name Unix -GroupScope DomainLocal -OtherAttributes @{'gidnumber'='10001'}
Get-ADGroup Unix -Properties gidNumber

$password = ConvertTo-SecureString "Netapp1!" -AsPlainText -Force

New-ADUser -SamAccountName user1 -UserPrincipalName user1@DEMO.NETAPP.COM -Name user1 -AccountPassword $password -OtherAttributes @{'uid'="user1";'uidNumber'="10001";'gidNumber'="10001";'unixHomeDirectory'='/home/user1';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

New-ADUser -SamAccountName user2 -UserPrincipalName user2@DEMO.NETAPP.COM -Name user2 -AccountPassword $password -OtherAttributes @{'uid'="user2";'uidNumber'="10002";'gidNumber'="10001";'unixHomeDirectory'='/home/user2';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1

New-ADUser -SamAccountName user3 -UserPrincipalName user3@DEMO.NETAPP.COM -Name user3 -AccountPassword $password -OtherAttributes @{'uid'="user3";'uidNumber'="10003";'gidNumber'="10001";'unixHomeDirectory'='/home/user3';'loginShell'='/bin/bash'} -Enabled 1 -PasswordNeverExpires 1
