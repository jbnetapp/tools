#
# Functions
#
FUNCTIONS_VERSION=1.0

clean_and_exit(){
	[ -f "$TMPFILE" ] && rm -f $TMPFILE
        echo $1 ; [ $2 -ne 0 ] && exit $2
}

check_ssh_keyhost(){
	cluster_name=$1
	[ -z "$cluster_name" ] && return 
	[ ! -d "$HOME/.ssh" ] && mkdir $HOME/.ssh
	SSH_Name=`cat $HOME/.ssh/known_hosts  | awk -v cluster_name=$cluster_name '{if ( $1 == cluster_name ) print $1}'|tr -d '\r'`
	[ -z "$SSH_Name" ] &&  ssh-keyscan $cluster_name >> $HOME/.ssh/known_hosts 
}

check_linux_bin(){
	which lsof > /dev/null 2>&1 ; [ $? -ne 0 ] && clean_and_exit "Error lsof not available: Please install the pacakge"  255
	which sshpass > /dev/null 2>&1 ; [ $? -ne 0 ] && clean_and_exit "Error sshpass not available: Please install the pacakge"  255
	which multipath  > /dev/null 2>&1 ; [ $? -ne 0 ] && clean_and_exit "Error unable to run multipath" 255
	which rescan-scsi-bus.sh > /dev/null 2>&1  ; [ $? -ne 0 ] && clean_and_exit "Error: rescan-scsi-bus.sh not available" 255
}

check_netapp_linux_bin(){
	which sanlun ; [ $? -ne 0 ] && clean_and_exit "ERROR: sanlun not available" 0
}

check_mediator() {
 	mediator_port=`lsof -n |grep uwsgi |grep TCP |grep "*:$MEDIATOR_PORT" | awk '{ print $9}' | uniq`
	[ "$mediator_port" != "*:${MEDIATOR_PORT}" ] && clean_and_exit "Error Mediator not running or used a bad port number" 255
}

check_var(){
[ -z "$TMPFILE" ] && clean_and_exit "Error variable not defined: TMPFILE" 255
[ -z "$PASSWD" ] && clean_and_exit "Error variable not defined: PASSWD" 255
[ -z "$TIMEOUT" ] && clean_and_exit "Error variable not defined: TIMEOUT" 255
[ -z "$LMASK" ] && clean_and_exit "Error variable not defined: LMASK" 255
[ -z "$ROUTER" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$DOMAIN" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$NAME_SERVER" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$CIFS_USER" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$S3_USER" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$SVM_S3" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$SVM_S3_IP0" ] && clean_and_exit "Error variable not defined: ROUTER" 255
[ -z "$SVM_S3_IP1" ] && clean_and_exit "Error variable not defined: ROUTER" 255
}
