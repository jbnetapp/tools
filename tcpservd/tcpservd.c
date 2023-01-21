/* 
 * jblanche (c) 
 *
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <netdb.h>
#include <arpa/telnet.h>
#include <syslog.h>
#include <time.h>

char *vers="1.0_0";

int i, j, k, er;
time_t t0, t1;

int s;				/* connected socket descriptor */
int ls;				/* listen socket descriptor */
int debflg = 0;
int badflg = 0;
int keepflg = 0;
int cli_id = 0;

enum STATUS{
	BAD,
        GOOD	
};

enum STATUS tcpservd_status=BAD;

void server(void);

struct hostent *hp;		/* pointer to host info for remote host */
struct servent *sp;		/* pointer to service information */

long timevar;			/* contains time returned by time() */
char *ctime();			/* declare time formatting routine */

struct linger linger;		/* allow a lingering, graceful close; */
				/* used when setting SO_LINGER */

struct sockaddr_in myaddr_in;	/* for local socket address */
struct sockaddr_in peeraddr_in;	/* for peer socket address */


main(argc, argv)
int argc;
char *argv[];
{

	int addrlen;
        int one = 0xffffffff;
        int c;
        extern char *optarg;
        extern int optind;
        int hflg = 0;
        int reuseflg = 0; 
        int errflg = 0;
	int servflg = 0;
        char *service = NULL;

        while ((c = getopt(argc, argv, "hdkrbs:")) != EOF)
           switch (c) {
           case 'h':
                 hflg++;
              break;
           case 'd':
                 debflg++;
              break;
           case 'k':
                 keepflg++;
              break;
           case 'r':
                 reuseflg++;
              break;
           case 'b':
                 badflg++;
              break;
 	   case 's':
              	service = optarg;
		servflg++;
		if (debflg)
              		printf("DEB:service name = %s\n", service);
              break;

           case '?':
              errflg++;
           }
        if (errflg) {
           (void)fprintf(stderr,
              "usage: %s [-hdkrb] -h for help\n",argv[0]);
           exit (2);
            }

	if (hflg){
            printf("NAME\n\t%s - simple tcp server Vers %s\n\n",argv[0],vers);
            printf("SYNOPSYS\n\t%s [ -hdkr]\n\n",argv[0]);
            printf("OPTIONS\n\tThe following options are supported\n");
            printf("\t-h\tHelp\n");
            printf("\t-d\tprint debug informations\n");
            printf("\t-r\tenable local address reuse (SO_REUSEADDR)\n");
            printf("\t-k\tenable keep connection alive (SO_KEEPALIVE)\n");
            printf("\t-b\tReturn string BAD instead of quit to quit client\n");
            printf("\t-s\tchoose /etc/services tcp name\n");
            exit (0);
            }


	if (! servflg){
		service="tcpservd";
	}

	memset ((char *)&myaddr_in, 0, sizeof(struct sockaddr_in));
	memset ((char *)&peeraddr_in, 0, sizeof(struct sockaddr_in));

	myaddr_in.sin_family = AF_INET;
	myaddr_in.sin_addr.s_addr = INADDR_ANY;
	sp = getservbyname (service, "tcp");
	if (sp == NULL) {
		fprintf(stderr, "%s not found in /etc/services\n",
				service);
		exit(1);
	}
	myaddr_in.sin_port = sp->s_port;

	ls = socket (AF_INET, SOCK_STREAM, 0);
	if (ls == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to create socket\n", argv[0]);
		exit(1);
	}
        if (reuseflg){
                if (debflg)
                      printf("DEB_MAIN>>SO_REUSEADDR on main socket\n");
	        if (setsockopt(ls, SOL_SOCKET, SO_REUSEADDR,
                                              (char *)&one, sizeof(one)) != 0) {
                      perror("Connection with %s aborted on error\n");
                      exit(1);
                }
	}

	if (bind(ls, &myaddr_in, sizeof(struct sockaddr_in)) == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to bind address\n", argv[0]);
		exit(1);
	}
	if (listen(ls, 5) == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to listen on socket\n", argv[0]);
		exit(1);
	}
	setpgrp();
	if (debflg)
            printf("DEB_MAIN>>SERVER BIND on local port %u\n"
                                                    ,ntohs(myaddr_in.sin_port));

	for(;;) {
		addrlen = sizeof(struct sockaddr_in);
		if (debflg)
			printf("DEB_MAIN>> accept\n");
		s = accept(ls, &peeraddr_in, &addrlen);
		if(debflg)
		if ( s == -1) exit(1);
		if (debflg )
			printf("DEB_MAIN>> New server id [%d]\n");
		server();
		}
}
void server(void)
{
	int reqcnt = 0;		/* keeps count of number of requests */
        int on  = 1;
	char *netibuf;		/* Data telnet */
        char *tmpbuf;
	char *inet_ntoa();
	char *hostname;		/* points to the remote host's name string */
	char localname[1024];	/* points to the remote host's name string */
	int len, len1;
	int netibufsize ;
        int tmpbufsize ;
	FILE *S; /* socket (FILE version)*/

	/* malloc tmpbuf */
        if (!(tmpbuf = (char *)malloc(BUFSIZ)))
               syslog(LOG_ERR, "tmpbuf malloc failed\n");
        tmpbufsize = BUFSIZ;
        bzero(tmpbuf, BUFSIZ);

        if (!(netibuf = (char *)malloc(BUFSIZ)))
           syslog(LOG_ERR, "netibuf malloc failed\n");

        netibufsize = BUFSIZ;
        bzero(netibuf, BUFSIZ);

	hp = gethostbyaddr ((char *) &peeraddr_in.sin_addr,
				sizeof (struct in_addr),
				peeraddr_in.sin_family);

	if (hp == NULL) {
		hostname = inet_ntoa(peeraddr_in.sin_addr);
	} else {
		hostname = hp->h_name;
	}

        if(debflg){
                printf("DEB>>NEW CLIENT: from %s port %u\n",
                                         hostname, ntohs(peeraddr_in.sin_port));
        }

	linger.l_onoff  =1;
	linger.l_linger =1;
      
        if (keepflg){ 
           if (debflg)
              printf("DEB>>SO_KEEPALIVE option on accpet socket\n");
           if (setsockopt(s, SOL_SOCKET, SO_KEEPALIVE,(char *)&on,
                                        sizeof(on)) == -1) {
              printf("setsockopt error SO_KEEPALIVE\n");
	      close(s); /* ABM */
              return ;  /* ABM */
           }
        } 
	if (setsockopt(s, SOL_SOCKET, SO_LINGER, &linger,
					sizeof(linger)) == -1) {
errout:		printf("Connection with %s aborted on error\n", hostname);
		close(s); /* ABM */
		return ; /* ABM */
	}

 	/* Prompt */
    	S=fdopen(s,"r+");
   	fprintf(S,">",localname);
 	fflush(S);

        while (!strstr(netibuf,"quit")) {
           bzero(netibuf, BUFSIZ);
	   len = recv(s, netibuf, netibufsize, 0) ;
	   if (len == -1) goto errout; 
	   reqcnt++;
	   if (debflg)
              printf("DEB>>GET_CMD: %s\n",netibuf);
           if (badflg && strstr(netibuf,"quit")){
  	      strcpy(tmpbuf,"setbad");
	      if (send(s, tmpbuf, 1024, 0) != netibufsize) {
                goto errout;
              }
              bzero(tmpbuf, BUFSIZ);
           }
           else
             if (strstr(netibuf,"help")){
	   	if (debflg)
              	  printf("DEB>>help: fdopen\n");
		S=fdopen(s,"r+");
		fprintf(S,"Wellcome to tcpservd %s online help\n",vers);
		fprintf(S,"----------------------------\n");
		fprintf(S,"getstatus  :\tSend request to tcpservd.\n");
		fprintf(S,"           :\tIf tcpservd is in Bad Status: return Bad\n");
		fprintf(S,"           :\tIf tcpservd is in Good Status: return Good\n");
		fprintf(S,"           :\t\n");
		fprintf(S,"version    :\tGet the tcpservd server version\n");
		fprintf(S,"hostname   :\tGet the hostname where tcpservd run\n");
		fprintf(S,"setbad     :\tPut tcpservd in setbad  STATE (bad state)\n");
		fprintf(S,"setgood    :\tPut tcpservd in setgood STATE (normal)\n");
		fprintf(S,"startloop  :\tStart a loop for performance tests\n");
		fprintf(S,"quit       :\texit tcpservd client\n");
		fprintf(S,"\r\n");
	 	fflush(S);
	   	if (debflg)
              	  printf("DEB>>help: fclose\n");
             }else
		if (strstr(netibuf, "hostname" )){
		/* Get the hostname */	
		if ( (gethostname(localname,1024)) != 0 ){
			strcpy(localname,"hostname ERROR");
		}
		S=fdopen(s,"r+");
		fprintf(S,"hostname:[%s]\n",localname);
	 	fflush(S);
	   	if (debflg)
              	  printf("DEB>>help: fclose\n");
	
	     }else 
		 if (strstr(netibuf,"setbad")){
			tcpservd_status=BAD;
  	      		strcpy(tmpbuf,"Status is setbad\n");
	      		if (send(s, tmpbuf, 1024, 0) != netibufsize) {
                		goto errout;
              		}
              		bzero(tmpbuf, BUFSIZ);
             }else 
		if (strstr(netibuf,"setgood")){
			tcpservd_status=GOOD;
  	      		strcpy(tmpbuf,"Status is setgood\n");
	      		if (send(s, tmpbuf, 1024, 0) != netibufsize) {
                		goto errout;
              		}
              		bzero(tmpbuf, BUFSIZ);
             }else 
		if (strstr(netibuf,"version")){
                        /*
			strcpy(tmpbuf,vers);
			strcat(tmpbuf,"\n");
	      		if (send(s, tmpbuf, 1024, 0) != netibufsize) {
                		goto errout;
              		}
           		bzero(tmpbuf, BUFSIZ); 
                        */
	 		S=fdopen(s,"r+");
			fprintf(S,"version:[%s]\n",vers);
	 		fflush(S);
	    		if (debflg)
				printf("DEB>>help: fclose\n");
             }else 
		if (strstr(netibuf,"getstatus")){
			if ( tcpservd_status == GOOD ){
				strcpy(tmpbuf,"GOOD\n");
			}else{
				strcpy(tmpbuf,"BAD\n");
			}
	      		if (send(s, tmpbuf, 1024, 0) != netibufsize) {
                		goto errout;
              		}
              		bzero(tmpbuf, BUFSIZ);
             }else 
		if (strstr(netibuf, "startloop" )){
		S=fdopen(s,"r+");
		fprintf(S,"START_LOOP_WAIT\n");
	 	fflush(S);
    		t0=time((time_t) NULL);
    		for (i=0; i<1000; i++) {
      			for (j=0; j<1000; j++) {
        			for (k=0; k<1000; k++) { k+=10; }
      			}
    		}
    		t1=time((time_t) NULL);
    		fprintf(S,"END_LOOP: %d seconds \n", t1-t0);
	 	fflush(S);

             }else{
	   	if (debflg)
              	    printf("DEB>> ECHO CMD: %s\n",netibuf);
	        if (send(s, netibuf, netibufsize, 0) != netibufsize) {
                    goto errout;
                }
	     }

 	/* Prompt */
    	S=fdopen(s,"r+");
   	fprintf(S,">",localname);
 	fflush(S);
	}
        if (debflg){
           printf("DEB>>CLOSE CLIENT connection\n\n");
           printf("DEB>>\n");
           }
	close(s);
}
