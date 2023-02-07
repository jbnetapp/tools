#!/bin/bash
set -x
RANDOM=$$
for dir in {1..10};
  do
    mkdir -p Top_Dir_$dir/Sub_Dir_${dir}{1..10} ;
    subdir=(Sub_Level_{1..10})
    printf -v pathv '/%s' "${subdir[@]%/}"
    mkdir -p Top_Dir_$dir$pathv
    DIRS=`find Top_Dir_$dir/Sub_* -type d`;
    for sub_dir in $DIRS;
      do
        echo "Dir - $dir; Sub_Dir - $sub_dir";
          for count in {1..10};
            do
              rand=$RANDOM
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.pdf bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.jpg bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.png bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.txt bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.html bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.mp4 bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.doc bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.gif bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
              cmd="dd if=src_file of=$sub_dir/test_file_$rand.$count.xyz bs=4k count=256 iflag=fullblock "
              echo "CMD - $cmd";
              $cmd 2> /dev/null
          done
          echo "Imput random [$1] [$2]" 
          if [ -z "$2" ] ; then
                R=1
          else
		echo Random $2 
                DIFF=$(($2-$1+1))
                R=$(($(($RANDOM%$DIFF))+$1))
          fi
          echo "Press CTRL+C to stop. The dataset creation will continue after $R seconds.."
          sleep $R;
        done
    done
