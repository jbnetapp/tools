# This script Establishes an iSCSI connection between the Windows host and the ONTAP storage system.

$TargetPortalAddresses = @("192.168.0.140","192.168.0.141","192.168.0.142","192.168.0.143")
$iSCSIAddress = "192.168.0.5"

Foreach ($TargetPortalAddress in $TargetPortalAddresses) {
  New-IscsiTargetPortal -TargetPortalAddress $TargetPortalAddress -TargetPortalPortNumber 3260 -InitiatorPortalAddress $iSCSIAddress }

#Establish iSCSI connection
Foreach($TargetPortalAddress in $TargetPortalAddresses) {
  Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled $true -TargetPortalAddress $TargetPortalAddress -InitiatorPortalAddress $iSCSIAddress -IsPersistent $true }

Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR