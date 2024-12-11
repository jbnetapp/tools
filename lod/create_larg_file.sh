#!/bin/bash
base64 /dev/urandom | head -c 200000000000 > file.txt
