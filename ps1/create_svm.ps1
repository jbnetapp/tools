# ---------------------------------------------------------- #
# Prep ONTAP 9.14.1 Environment for Ransomware worksop       #
# ---------------------------------------------------------- #

# define variables
$cluster_src_ip = "192.168.0.101"
$cluster_dest_ip = "192.168.0.102"

$clusteradmin = "admin"
$clusterpass = "Netapp1!"
$clusterpass = ConvertTo-SecureString $clusterpass -AsPlainText -Force
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $clusteradmin, $clusterpass

$cluster_src = Connect-NcController -Name $cluster_src_ip -Credential $credential -HTTPS 
$cluster_dest = Connect-NcController -Name $cluster_dest_ip -Credential $credential -HTTPS

$cluster_src_name = (Get-NcCluster -Controller $cluster_src).ClusterName
$cluster_dest_name = (Get-NcCluster -Controller $cluster_dest).ClusterName

$domain = "DEMO"
$dnsdomain = "demo.netapp.com"
$domainadmin = "Administrator@"+$domain

$src_svm = "svm0"
$src_aggr = "cluster1_01_SSD_1"
$src_svm_node = "cluster1-01"
$src_svm_ip = "192.168.0.99"
$src_volumes = @("marketing","legal")
$lock_volumes = @("legal")

$dest_svm = "svm0_backup"
$dest_aggr = "cluster2_01_SSD_1"
$dest_svm_node = "cluster2-01"
$dest_svm_ip = "192.168.0.98"

$Style = "unix"
$Lang = "C.UTF-8"
$VolSize = "5g"
$DNS_server = "192.168.0.253"

# clear screen
clear

#-------------------------------------------------------------------------------------------#
# Function to clean-up / destroy all volumes and SVMs                                       #
#-------------------------------------------------------------------------------------------#
function CleanUp {

    # --------------------------------- #
    # Remove old SVMs                   #
    # --------------------------------- #

    $vtemplate = Get-NcVserver -Template 
    $vtemplate.VserverType = "data"
    $vservers = Get-NcVserver -Query $vtemplate

    foreach ($vserver in $vservers) {
    
        Get-NcSnapmirrorDestination -VserverContext $vserver | ForEach-Object { Invoke-NcSnapmirrorRelease -DestinationVserver $_.DestinationVserver -DestinationVolume $_.DestinationVolume -RelationshipId $_.RelationshipId -Confirm:$false}
        Get-NcSnapmirror -SourceVserver $vserver | ForEach-Object { Remove-NcSnapmirror -Source $_.sourcelocation -Destination $_.destinationlocation -Confirm:$false }
        Get-NcVserverPeer -Vserver $vserver | ForEach-Object { Remove-NcVserverPeer -Vserver $_.vserver -PeerVserver $_.PeerVserver -Confirm:$false }

        $volumes = Get-NcVol -Vserver $vserver 

        foreach ($volname in $volumes) {
            if ($volname.Name -ne $vserver.RootVolume ){

                Dismount-Ncvol -Force:$true -VserverContext:$vserver -Confirm:$false $volname | Out-Null
                if (-not ($?)){Write-Output "     |  [Error] Unmount volume: $volname";Write-Output " "; Exit}
                Write-Host -NoNewline "     |  [-] $volname [Unmount]"
            
                Set-NcVol -Offline:$true -VserverContext:$vserver -Confirm:$false $volname | Out-Null
                if (-not ($?)){Write-Output "     |  [Error] Offline volume: $volname";Write-Output " "; Exit}
                Write-Host -NoNewline " + [Offline]"

                Remove-NcVol -VserverContext:$vserver -Confirm:$false $volname | Out-Null
                if (-not ($?)){Write-Output "     |  [Error] Delete volume: $volname";Write-Output " "; Exit}
                Write-Output " + [Delete]"
            }

    }

        Get-NcCifsServer | Remove-NcCifsServer -AdminUsername Administrator -AdminPassword Netapp1! -Confirm:$false| Out-Null
        if (-not ($?)){Write-Output "     |  [Error] Delete CIFS from $vserver";Write-Output " "; Exit}
        write-output "     |  [-] Remove CIFS from $vserver"

        [Void](get-ncvserverpeer | remove-ncvserverpeer -Confirm:$false -ErrorAction SilentlyContinue)

   
        Get-NcSnapmirrorPolicy -Vserver $vserver| ForEach-Object { Remove-NcSnapmirrorPolicy -VserverContext $vserver -Name $_.Name } 
        if (-not ($?)){Write-Output "     |  [Error] Delete SnapMirror Policy for $vserver";Write-Output " "; Exit}
        write-output "     |  [-] Delete SnapMirror Policy for $vserver"
    
        remove-ncvserver $vserver -Confirm:$false | Out-Null
        if (-not ($?)){Write-Output "     |  [Error] Delete $vserver";Write-Output " "; Exit}
        write-output "     |  [-] Delete $vserver"

        # ---------- #
        # Update DNS #
        # ---------- #
        $a_record = Resolve-DnsName -name $vserver -ErrorAction SilentlyContinue
        if ($a_record.IPaddress -ne $null){
            Remove-DnsServerResourceRecord -ComputerName DC1 -Name $vserver -RRType A -ZoneName $dnsdomain -Force
            if (-not ($?)){Write-Output "     |  [Error] Remove DNS entryr";Write-Output " "; Exit}
            write-output "     |  [-] Remove DNS entry"
            Clear-DnsClientCache -Confirm:$false
        }
    }
}


#-------------------------------------------------------------------------------------------#
# Function to setup SVM on $svm_node with $svm_ip address and volumes on $svm_aggr          #
#-------------------------------------------------------------------------------------------#
function BuildUp {

    param ( $svm, $svm_ip, $svm_node, $svm_aggr )
    $svm_root = $svm+"_root"
    $svm = $svm

    # ---------------------------------------------------------- #
    # Create Vserver & Associated Parameters                    #
    # ---------------------------------------------------------- #
    New-NcVserver -Name $svm -RootVolume $svm_root -RootVolumeAggregate $svm_aggr -RootVolumeSecurityStyle $Style -Language $Lang| Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Create $svm";Write-Output " "; Exit}
    Write-Output "     |  [+] Create $svm"

    New-NcNetInterface -Vserver $svm -Name $svm -Role Data -Address $svm_ip -Netmask 255.255.255.0  -Node $svm_node -Port e0f| Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Create and Assign IP: $svm_ip";Write-Output " "; Exit}
    Write-Output "     |  [+] Create and Assign IP: $svm_ip"

    New-ncnetdns -Domains demo.netapp.com -NameServers $DNS_server -VserverContext $svm | Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Set DNS to: $DNS_server";Write-Output " "; Exit}
    Write-Output "     |  [+] Set DNS to: $DNS_server"

    Set-NcVolSize -VserverContext $svm -Name $svm_root -NewSize 1g  | Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Set Vol Size $svm_root = 1g";Write-Output " "; Exit}
    Write-Output "     |  [+] Set Vol Size $svm_root = 1g"

    Remove-NcSnapshotPolicySchedule -Schedule hourly -Name default |Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Remove hourly schedule in default";Write-Output " "; Exit}
    Write-Output "     |  [+] Remove hourly schedule in default"

    Add-NcSnapshotPolicySchedule -Schedule 8hour -Name default -Count 3 -SnapmirrorLabel 8hour |Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Add 8hour schedule to default";Write-Output " "; Exit}
    Write-Output "     |  [+] Add 8hour schedule to default"

  # Set-NcSnapshotPolicySchedule -Name default -Schedule daily -Count 14 | Out-Null
  # if (-not ($?)){Write-Output "     |  [Error] Set Default Snapshot Policy - hourly (24) daily (7)";Write-Output " "; Exit}
  # Write-Output "     |  [+] Set Default Snapshot Policy - hourly (24) daily (7)"

    Add-NcCifsServer -VserverContext $svm -Name $svm -Domain demo.netapp.com -AdminUsername Administrator -AdminPassword Netapp1! | Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Join AD Domain";Write-Output " "; Exit}
    Write-Output "     |  [+] Join AD Domain"

     # ---------- #
     # Update DNS #
     # ---------- #
     $a_record = Resolve-DnsName -name $svm -ErrorAction SilentlyContinue
     if ($a_record.IPaddress -ne $null){
            Remove-DnsServerResourceRecord -ComputerName DC1 -Name $svm -RRType A -ZoneName $dnsdomain -Force
            Add-DnsServerResourceRecordA -ComputerName DC1 -Name $svm -IPv4Address $svm_ip -ZoneName $dnsdomain
            if (-not ($?)){Write-Output "     |  [Error] Adding DNS entry";Write-Output " "; Exit}
            write-output "     |  [+] Adding DNS entry"
            Clear-DnsClientCache -Confirm:$false
      }
      if ($a_record.IPaddress -eq $null){
            Add-DnsServerResourceRecordA -ComputerName DC1 -Name $svm -IPv4Address $svm_ip -ZoneName $dnsdomain
            if (-not ($?)){Write-Output "     |  [Error] Adding DNS entry";Write-Output " "; Exit}
            write-output "     |  [+] Adding DNS entry"
            Clear-DnsClientCache -Confirm:$false
      }
  
    # ------------------------------------ #
    # Create Volumes, CIFS Shares & Mount  #
    # ------------------------------------ #
    
    if ($svm -eq $src_svm) 
    {
        foreach ($vol in $src_volumes) {

            $volname = $svm+"_"+$vol
            $sharename = $vol
            $driveletter = $vol.substring(0,1)

            New-NcVol -VserverContext $svm -Name $volname -JunctionPath /$volname -Aggregate $svm_aggr -Size $VolSize -State online -SpaceReserve none | Out-Null
            if (-not ($?)){Write-Output "     |  [Error] Create Vol: $volname";Write-Output " "; Exit}
            Write-Output "     |  [+] Create Vol: $volname"

            Add-NcCifsShare -VserverContext $svm -Name $sharename -Path /$volname -ShareProperties oplocks,browsable,changenotify,show-previous-versions | Out-Null
            if (-not ($?)){Write-Output "     |  [Error] Create SMB Share: $sharename";Write-Output " "; Exit}
            Write-Output "     |  [+] Create SMB Share: $sharename"

            New-PSDrive -Name $driveletter -PSProvider FileSystem -Root "\\$svm.demo.netapp.com\$sharename" -Scope Global -Persist -ErrorAction SilentlyContinue| Out-Null
            Write-Output "     |  [+] Map drive $driveletter => \\$svm.demo.netapp.com\$sharename"
        }
    }
}



#-------------------------------------------------------------------------------------------#
# Function to setup a "LockVault" relationship betwen $svm_src and $svm_dest      #
#-------------------------------------------------------------------------------------------#
function Protect {

    param ( $svm_src, $svm_dest, $svm_aggr )

    # ---------------------------------------------------------- #
    # Create Vserver & Associated Parameters                    #
    # ---------------------------------------------------------- #
    $ntemplate = Get-NcNode -Template 
    $nodes = Get-NcNode -Query $ntemplate

    Connect-NcController -Name $cluster_dest_ip -Credential $credential -HTTPS | Out-Null

    foreach ($node in $nodes) {
        Set-NcSnaplockComplianceClock -Node $node -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Output "     |  [+] SnapLock [$node] Initialize Compliance Clock"
    }

    New-NcVserverPeer -Vserver $svm_dest -PeerVserver $svm_src -Application "snapmirror" -PeerCluster $cluster_src_name| Out-Null
    if (-not ($?)){Write-Output "     |  [Error] Vserver Peerings";Write-Output " "; Exit}
    Write-Output "     |  [+] Vserver Peering $svm_src + $src_dest"

    New-NcSnapmirrorPolicy -VserverContext $svm_dest -Name LockVault -TransferPriority normal -Restart always -Type vault -IgnoreAccessTime:$false -EnableNetworkCompression:$true -Comment "LockVault Policy" |Out-Null
    if (-not ($?)){Write-Output "     |  [Error] SnapMirror Policy Rule - LockVault";Write-Output " "; Exit}
    Write-Output "     |  [+] SnapMirror Policy Create - LockVault"

    Add-NcSnapmirrorPolicyRule -VserverContext $svm_dest -Name LockVault -SnapmirrorLabel 8hour -RetentionCount 31|Out-Null
    if (-not ($?)){Write-Output "     |  [Error] SnapMirror Policy Rule - LockVault";Write-Output " "; Exit}
    Write-Output "     |  [+] SnapMirror Policy Rule - LockVault"

    New-NcSnapmirrorPolicy -VserverContext $svm_dest -Name Vault -TransferPriority normal -Restart always -Type vault -IgnoreAccessTime:$false -EnableNetworkCompression:$true -Comment "LockVault Policy" |Out-Null
    if (-not ($?)){Write-Output "     |  [Error] SnapMirror Policy Rule - LockVault";Write-Output " "; Exit}
    Write-Output "     |  [+] SnapMirror Policy Create - Vault"

    Add-NcSnapmirrorPolicyRule -VserverContext $svm_dest -Name Vault -SnapmirrorLabel 8hour -RetentionCount 31|Out-Null
    if (-not ($?)){Write-Output "     |  [Error] SnapMirror Policy Rule - LockVault";Write-Output " "; Exit}
    Write-Output "     |  [+] SnapMirror Policy Rule - Vault"

    
    foreach ($vol in $lock_volumes) {
        $dest_volname = $svm_dest+"_lock_"+$vol
        $src_volname = $svm_src+"_"+$vol
        $driveletter = "Y"

        Invoke-NcSsh -Command "vol create -volume $dest_volname -aggregate $svm_aggr -size $volsize -state online -snaplock-type compliance -space-guarantee none -type DP" -Controller $cluster_dest | Out-Null
        if (-not ($?)){Write-Output "     |  [Error] Create DP Vol: $dest_volname";Write-Output " "; Exit}
        Write-Output "     |  [+] Create DP Vol: $dest_volname"

        $snaplock_min = "31 days"
        $snaplock_max = "1 years"
        $snaplock_default = "31 days"
     
        Set-NcSnaplockVolAttr -VserverContext $svm_dest -Volume $dest_volname -MinimumRetentionPeriod $snaplock_min -MaximumRetentionPeriod $snaplock_max -DefaultRetentionPeriod $snaplock_default |Out-Null
        if (-not ($?)){Write-Output "     |  [Error] Set SnapLock Retention to: $snaplock_min";Write-Output " "; Exit}
        Write-Output "     |  [+] Set SnapLock Retention to: $snaplock_min"

        New-NcSnapmirror -SourceVserver $svm_src -SourceVolume $src_volname -DestinationVserver $svm_dest -DestinationVolume $dest_volname -Type vault -Policy LockVault -Schedule 8hour |Out-Null
        if (-not ($?)){Write-Output "     |  [Error] SnapMirror $src_volname -> $dest_volname";Write-Output " "; Exit}
        Write-Host -NoNewline "     |  [+] SnapMirror $src_volname -> $dest_volname [Define]"

        Invoke-NcSnapmirrorInitialize -SourceVserver $svm_src -SourceVolume $src_volname -DestinationVserver $svm_dest -DestinationVolume $dest_volname |Out-Null
        if (-not ($?)){Write-Output "     |  [Error] SnapMirror $src_volname -> $dest_volname";Write-Output " "; Exit}
        Write-Output "+ [Initialize]"
    }

        $reg_volumes = $src_volumes | ForEach-Object { if ($_ -notin $lock_volumes) {$_} }
        foreach ($vol in $reg_volumes) {

        $dest_volname = $dest_svm+"_"+$vol
        $src_volname = $src_svm+"_"+$vol
        $driveletter = "Y"

        Invoke-NcSsh -Command "vol create -volume $dest_volname -aggregate $svm_aggr -size $volsize -state online -space-guarantee none -type DP" -Controller $cluster_dest | Out-Null
        if (-not ($?)){Write-Output "     |  [Error] Create DP Vol: $dest_volname";Write-Output " "; Exit}
        Write-Output "     |  [+] Create DP Vol: $dest_volname"

        New-NcSnapmirror -SourceVserver $svm_src -SourceVolume $src_volname -DestinationVserver $svm_dest -DestinationVolume $dest_volname -Type vault -Policy Vault -Schedule 8hour |Out-Null
        if (-not ($?)){Write-Output "     |  [Error] SnapMirror $src_volname -> $dest_volname";Write-Output " "; Exit}
        Write-Host -NoNewline "     |  [+] SnapMirror $src_volname -> $dest_volname [Define]"

        Invoke-NcSnapmirrorInitialize -SourceVserver $svm_src -SourceVolume $src_volname -DestinationVserver $svm_dest -DestinationVolume $dest_volname |Out-Null
        if (-not ($?)){Write-Output "     |  [Error] SnapMirror $src_volname -> $dest_volname";Write-Output " "; Exit}
        Write-Output "+ [Initialize]"

    }

}

# ---------------------------------- #
# Main                               #
# ---------------------------------- #

# ---------------------------------- #
# connect to src controller          #
# ---------------------------------- #
Write-Output " "
Write-Output "[$cluster_src_name]"
Connect-NcController -Name $cluster_src_ip -Credential $credential -HTTPS | Out-Null
if (-not ($?)){Write-Output "     |  [Error] Invalid ONTAP Cluster Credential - $cluster_src_name ($cluster_src_ip).";Write-Output " "; Exit}
Write-Output "     |"
Write-Output "     |  [+] Connecting to $cluster_src_name ($cluster_src_ip)"
Write-Output "     |"
Write-Output "     ---[Clean-up]"
Write-Output "     |"
CleanUp 
Write-Output "     |     "
Write-Output "     ---[Build-up]"
Write-Output "     |"
Buildup $src_svm $src_svm_ip $src_svm_node $src_aggr 
Write-Output "     |"
Write-Output "     ---[Done]"

# ---------------------------------- #
# connect to dest controller         #
# ---------------------------------- #
Write-Output " "
Write-Output "[$cluster_dest_name] "
Connect-NcController -Name $cluster_dest_name -Credential $credential -HTTPS | Out-Null
if (-not ($?)){Write-Output "     |  [Error] Invalid ONTAP Cluster Credential - $cluster_dest_name ($cluster_dest_ip).";Write-Output " "; Exit}
Write-Output "     |"
Write-Output "     |  [+] Connecting to $cluster_dest_name ($cluster_dest_ip)"
Write-Output "     |"
Write-Output "     ---[Clean-up]"
Write-Output "     |"
CleanUp 
Write-Output "     |     "
Write-Output "     ---[Build-up]"
Write-Output "     |"
Buildup $dest_svm $dest_svm_ip $dest_svm_node $dest_aggr 
Write-Output "     |"
Write-Output "     ---[SnapLock and Replication]"
Write-Output "     |"
Protect $src_svm $dest_svm $dest_aggr
Write-Output "     |"
Write-Output "     ---[Done]"
