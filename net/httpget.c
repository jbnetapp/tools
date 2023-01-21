/**
 * this lib get a file from an http server
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <fcntl.h>
#include <string.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

#include "httpget.h"

/**
 * retrieve a file thru http get, via a proxy, in a buffer
 * @param proxyHost http proxy host name
 * @param proxyPort http proxy TCP port
 * @param host http server host name
 * @param port http server TCP port
 * @param path http path of the file to retrieve
 * @return a buffer containing the file
 */
buffer* httpProxyGet(char* proxyHost,int proxyPort
   ,char* host,int port,char* path)
   {
   char* path2;
   path2=(char*)malloc(URL_MAX_LENGTH);
   sprintf(path2,"http://%s:%d""%s",host,port,path);
   return httpGet(proxyHost,proxyPort,path2);
}


/**
 * retrieve a file thru http get, in a buffer
 * @param host http server host name
 * @param port http server TCP port
 * @param path http path of the file to retrieve
 * @return a buffer containing the file
 */

buffer* httpGet(char* host,int port,char* path){
   int r;  /* return code */
   int s;  /* socket */
   FILE * S; /* socket (FILE version)*/
   struct sockaddr_in addr; /*address*/
   struct hostent* ent; /* for host address search */
   char temp[256];/*header parsing buffer*/
   char* header;/*header name*/
   char* headerVal;/*header value*/
   int retCode;/*http return code*/
   size_t length;/* Content length*/
   buffer * b; /*Result buffer*/

   if ((s = socket (AF_INET, SOCK_STREAM, 0))==-1){
      printf("Unable to open socket; exiting\n");
      exit(0);
   };
   addr.sin_family = AF_INET;
   ent=gethostbyname(host);
   memcpy(&addr.sin_addr,ent->h_addr,ent->h_length);
   addr.sin_port = htons(port);

   r=connect(s,(struct sockaddr*)&addr,sizeof(struct sockaddr_in));
   if (r==-1){
      perror("Connection failed :");
      exit(1);
   }

   S=fdopen(s,"r+");

   fprintf(S,"GET %s HTTP/1.1\r\n",path);
   fprintf(S,"User-Agent: httpGet\r\n");
   fprintf(S,"Host: %s,host");
   fprintf(S,"Accept: image/jpeg\r\n");
   fprintf(S,"\r\n");
   fflush(S);
   
   fgets(temp,256,S);
   sscanf(temp,"%s %d",&headerVal,&retCode);
   if (retCode!=200){
      fprintf(stderr,"HTTP Error : %d\n",retCode);
      exit(2);
   }
   fgets(temp,256,S);
   length=-1;
   while(strlen(temp)>2){
      header=strtok(temp,":");
      headerVal=strtok(NULL,":");
      if (strcasecmp(header,"Content-Length")==0){
	 sscanf(headerVal,"%d",&length);
      }

      fgets(header,256,S);
   }
   if (length<0){
      printf("Reading variable length content\n");
      b= readAll(s);
   }else{
      printf("Reading fixed length content [%d]\n",length);
      b= readExact(s,length);
   }
   close(s);
   return b;
}

/**
 * read exactly len bytes from s
 * @param s file descriptor to read from
 * @param len number on byte to read
 * @return a buffer containing the data
 */
buffer * readExact(int s,size_t len){
   long flags;
   size_t r;
   buffer *b;

   flags = fcntl (s, F_GETFL);
   fcntl (s, F_SETFL, flags & ~O_NONBLOCK);

   b=(buffer*) malloc(sizeof(buffer));
   b->data=(char *)malloc(len);
   b->size=0;

   while (b->size<len){
      printf("%d bytes read          \r",b->size);
      r=read(s,b->data+b->size,len-b->size);
      b->size+=(r>0?r:0);
   }
   printf("%d bytes read          \n",b->size);
   return b;
}

/**
 * read from s until no more data is available
 * @param s file descriptor to read from
 * @return a buffer containing the data
 */
buffer * readAll(int s){
   long flags;
   buffer * b;
   size_t r0,r1; /*counter*/

   flags = fcntl (s, F_GETFL);
   fcntl (s, F_SETFL, flags & ~O_NONBLOCK);

   b=(buffer*) malloc(sizeof(buffer));
   b->size=BUFFER_SIZE;
   b->data=(char *)malloc(b->size);

   r0=0;
   while ((r1=read(s,b->data+r0,b->size-r0))>0){
      printf("read=%d\n",r1);
      r0+=r1;
      if (r0==b->size){
         b->size*=2;
         printf("growing buffer to %d\n",b->size);
         b->data=(char*)realloc(b->data,b->size);
      }
   }

   b->size=r0+1;
   ((char*)(b->data))[b->size]='\0';

   printf("$ %s",b->data);
   return b;
}

