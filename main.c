#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <X11/Xlib.h>

#include "httpget.h"

/**
 * Write usage info
 * @param pn this program name
 */
void usage(char* pn){
   fprintf(stderr,"Usage:\n  %s <server> <port> <path>\nor\n"
      "  %s <proxy> <proxy port> <server> <port> <path>\n"
      "NOTE: path must begin with /\n",pn,pn);
   exit(99);
}

/**
 * main  :entry point
 * @param argc number of command line argument
 * @param argv command line arguments
 */
int main(int argc,char** argv){
   buffer * b;
   int fd;
   XImage * img;

   if (argc==4){
      b=httpGet(argv[1],atoi(argv[2]),argv[3]);
   }else if (argc==6){
      b=httpProxyGet(argv[1],atoi(argv[2]),argv[3],atoi(argv[4]),argv[5]);
   }else{
      usage(argv[0]);
   }
   printf("%s\n",b->data);
}
