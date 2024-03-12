$cluster_src_hostname = "cluster1.demo.netapp.com"
$cluster_dest_hostname = "cluster2.demo.netapp.com"
$vserver_src_name = "svm1_cluster1"


$clusteradmin = "admin"
$clusterpass = "Netapp1!"
$clusterpass = ConvertTo-SecureString $clusterpass -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $clusteradmin, $clusterpass

#
# Check Cluster Connectoin
#
$cluster_src = Connect-NcController -Name $cluster_src_hostname -Credential $credential 
if (-not ($?)){Write-Output "     |  [Error] Invalid ONTAP Cluster Credential - $cluster_dest_name ($cluster_src_hostname).";Write-Output " "; Exit}

$cluster_dest = Connect-NcController -Name $cluster_dest_hostname -Credential $credential
if (-not ($?)){Write-Output "     |  [Error] Invalid ONTAP Cluster Credential - $cluster_dest_name ($cluster_dest_hostname).";Write-Output " "; Exit}

$cluster_src


#
# Check VSERVER setup 
#
$vserver_src = Get-NcVserver -Controller $cluster_src -Name $vserver_src_name
if (-not ($vserver_src)){Write-Output "     |  [Error] SVM ($vserver_src_name) Not found on ($cluster_src_hostname).";Write-Output " "; Exit}

$cifs_src_hostname=$vserver_src.CIFS.Name
if (-not ($cifs_src_hostname)){Write-Output "     |  [Error] SVM No CIFS ($vserver_src_name).";Write-Output " "; Exit}

$domain=$vserver_src.CIFS.AdDomain.Fqdn
if (-not ($domain)){Write-Output "     |  [Error] SVM No CIFS domain ($vserver_src_name).";Write-Output " "; Exit}

$cifs_src_hostname
$domain


$cifs_src_ad = Get-ADComputer -Properties * $cifs_src_hostname
if (-not ($cifs_src_ad)){Write-Output "     |  [Error] ADComuter not found ($cifs_src_hostname).";Write-Output " "; Exit}

#
# Create AD User 1 for Unix 
# 
$username= "user1"
$uid= "10001"
$gid= "10001"
try { 
	$user=Get-ADuser $username -ErrorVariable ErrorVar
} Catch {
	New-ADUser -SamAccountName $username -UserPrincipalName $username@$domain -Name $username -OtherAttributes @{'uid'="$username";'uidNumber'="$uid";'gidNumber'="$gid"} -Enabled 1 -PasswordNeverExpires 1 -AccountPassword $clusterpass
	if (-not ($?)){Write-Output "     |  [Error] Failed to create $user.";Write-Output " "; Exit}
}

#
# Create AD User 2 Unix
# 
$username= "user2"
$uid= "10002"
$gid= "10002"
try { 
	$user=Get-ADuser $username -ErrorVariable ErrorVar
} Catch {
	New-ADUser -SamAccountName $username -UserPrincipalName $username@$domain -Name $username -OtherAttributes @{'uid'="$username";'uidNumber'="$uid";'gidNumber'="$gid"} -Enabled 1 -PasswordNeverExpires 1 -AccountPassword $clusterpass
	if (-not ($?)){Write-Output "     |  [Error] Failed to create $user.";Write-Output " "; Exit}
}


#
# Setup LDAP
#
# ldap client create -client-config ldapclient1 
# -ldap-servers dc1.demo.netapp.com 
# -schema AD-IDMU 
# -port 389 
# -query-timeout 3 
# -min-bind-level anonymous 
# -base-dn "DC=demo,DC=netapp,DC=com" 
# -base-scope subtree 
# -user-scope subtree 
# -group-scope subtree 
# -netgroup-scope subtree 
# -use-start-tls false 
# -is-netgroup-byhost-enabled false 
# -netgroup-byhost-scope subtree 
# -session-security none 
# -referral-enabled false 
# -group-membership-filter "" 
# -ldaps-enabled false 
# -bind-dn administrator@demo.netapp.com

$IP_AD = "192.168.0.253"
$out=New-NcLdapClient -VserverContext $vserver_src -Controller $cluster_src -Name "ldapclient1"  -Schema "AD-IDMU" -AdDomain $domain -PreferredAdServers $IP_AD -TcpPort 389 -QueryTimeout 3 -MinBindLevel "anonymous" -BindDn "administrator@demo.netapp.com" -BindPassword $clusterpass -BaseDn "DC=demo,DC=netapp,DC=com" -BaseScope "subtree" -UserScope "subtree"   -GroupScope "subtree" -NetGroupScope "subtree" -IsNetgroupByHostEnabled $false -NetgroupByHostScope "subtree" -SessionSecurity "none" -Confirm:$false  -ONTAPI -ErrorVariable ErrorVar

# 
# ldap create -vserver svm1_cluster1 -client-config ldapclient1 -skip-config-validation false
# 
#$out=New-NcLdapConfig -VserverContext $vserver_src -Controller $cluster_src -ClientConfig "ldapclient1" -SkipConfigValidation $false -ONTAPI -ErrorVariable ErrorVar
$out=New-NcLdapConfig -VserverContext $vserver_src -Controller $cluster_src -ClientConfig "ldapclient1" -ClientEnabled $true -ONTAPI -ErrorVariable ErrorVar


#
# vserver services name-service ns-switch modify -vserver svm1_cluster1 -database passwd -sources files,ldap
# vserver services access-check authentication show-ontap-admin-unix-creds -node cluster1-01 -vserver svm1_cluster1 -unix-user-name user1
#     User Id: 10001
#     Group Id: 10001
#     Home Directory:
#     Login Shell:





