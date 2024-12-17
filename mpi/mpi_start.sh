#!/bin/bash
set -o vi
export OMPI_MCA_btl=^openib
export OMPI_MCA_fs_ufs_lock_algorithm=1
mpirun -np 48 ./parallel_io_perf $HID 10240 100000 ./datafile1
du -hs ./datafile1 
rm ./datafile1
