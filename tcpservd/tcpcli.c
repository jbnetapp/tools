/*
 * jblanche (c)
 *
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>
#include <netdb.h>

char *vers="3.0";

int s;				/* connected socket descriptor */
int return_error = 1;		/* Return value used in case or error */
struct hostent *hp;		/* pointer to host info for remote host */
struct servent *sp;		/* pointer to service information */

long timevar;			/* contains time returned by time() */
char *ctime();			/* declare time formatting routine */

struct sockaddr_in myaddr_in;	/* for local socket address */
struct sockaddr_in peeraddr_in;	/* for peer socket address */


int debflg = 0;
int rtflg = 0;
main(argc, argv)
int argc;
char *argv[];
{
	int addrlen, i, j;
	char buf[10];
	char *netibuf;          /* Data telnet */
        int  netibufsize;
        int  sendsize;
        int  len;
        int hflg = 0;
        int servflg = 0;
        int errflg = 0;
        int c;
	char *hostname;
	char *service = NULL;
 	extern char *optarg;
 	extern int optind;


        while ((c = getopt(argc, argv, "hdr:s:")) != EOF)
           switch (c) {
           case 'h':
                 hflg++;
                 break;
           case 'd':
                 debflg++;
                 break;
           case 's':
		 service = optarg;
                 servflg++;
                 break;
	   case 'r':
		 return_error = atoi(optarg); 
                 break;
           case '?':
                 errflg++;
                 break;
           }


        if (errflg) {
           (void)fprintf(stderr,
              "usage: %s [-hd] -h for server  help\n",argv[0]);
           exit (2);
            }

 	for ( ; optind < argc; optind++)
		hostname=argv[optind];

        if (hflg){
            printf("NAME\n\t%s - simple tcp client Vers %s\n\n",argv[0],vers);
            printf("SYNOPSYS\n\t%s [-hd] server_hostname\n\n",argv[0]);
            printf("OPTIONS\n\tThe following options are supported\n");
            printf("\t-h\tHelp\n");
            printf("\t-d\tprint debug informations\n");
            printf("\t-r\treturn value in case or error (default is 1)\n");
            printf("\t-s\tchoose /etc/services tcp name\n");
            printf("\thostname\t<TCP_server_hostname>\n");
            exit (0);
            }

	if ( hostname == NULL ) {
           (void)fprintf(stderr,
              "usage: %s [-hd] server -h for help\n",argv[0]);
           exit (2);
	   }	

	if ( debflg )
        	printf("DEB: Connect to [%s]\n", hostname);


	if ( ! servflg ) {
		service="tcpservd";
        } 

        if (!(netibuf = (char *)malloc(BUFSIZ))){
           fprintf(stderr, "netibuf malloc failed\n");
           exit(return_error);
           }
        netibufsize = BUFSIZ;
        bzero(netibuf, BUFSIZ);

	memset ((char *)&myaddr_in, 0, sizeof(struct sockaddr_in));
	memset ((char *)&peeraddr_in, 0, sizeof(struct sockaddr_in));

	peeraddr_in.sin_family = AF_INET;
	hp = gethostbyname (hostname);
	if (hp == NULL) {
		fprintf(stderr, "%s: %s not found in /etc/hosts\n",
				argv[0], hostname);
		exit(return_error);
	}
	peeraddr_in.sin_addr.s_addr = ((struct in_addr *)(hp->h_addr))->s_addr;
	sp = getservbyname (service , "tcp");
	if (sp == NULL) {
		fprintf(stderr, "%s not found in /etc/services\n",
				service);
		exit(return_error);
	}
	peeraddr_in.sin_port = sp->s_port;

	s = socket (AF_INET, SOCK_STREAM, 0);
	if (s == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to create socket\n", argv[0]);
		exit(return_error);
	}
	if (connect(s, &peeraddr_in, sizeof(struct sockaddr_in)) == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to connect to remote\n", argv[0]);
		exit(return_error);
	}
	/* Get the Prompt */
        bzero(netibuf, BUFSIZ);
        len = recv(s, netibuf, netibufsize, 0) ;
	/* Send getstatus */
        strcpy(netibuf,"getstatus\r\n");
	if ( debflg ) printf("DEB: Send [%s] Request \n",netibuf);
	sendsize=strlen(netibuf);
        if (send(s, netibuf, sendsize, 0) != sendsize){
           fprintf(stderr, "%s: unable to send datan", argv[0]);
           exit(return_error); 
           }
        bzero(netibuf, BUFSIZ);
        len = recv(s, netibuf, netibufsize, 0) ;
	/* Test the Reply */
	if ( debflg ) printf("DEB: RECV:[%s]\n",netibuf);
	if (!strstr(netibuf,"RPLY")) rtflg++;
	/* Get the Prompt */
        bzero(netibuf, BUFSIZ);
        len = recv(s, netibuf, netibufsize, 0) ;
	/* Send quit Request */
	if ( debflg ) printf("DEB: Send quit Request\n");
        strcpy(netibuf,"quit\r\n");
	sendsize=strlen(netibuf);
        if (send(s, netibuf, sendsize, 0) != sendsize){
           fprintf(stderr, "%s: unable to send datan", argv[0]);
           exit(return_error); 
           }
        bzero(netibuf, BUFSIZ);
        len = recv(s, netibuf, netibufsize, 0) ;
	/* Test the Reply */
	if ( debflg ) printf("DEB: RECV [%s]\n",netibuf);
	/* if (!strstr(netibuf,"quit")) rtflg++; */

	if (shutdown(s, 1) == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to shutdown socket\n", argv[0]);
		exit(return_error);
	}
	if (rtflg){
		if ( debflg ) printf("DEB:Error Return %d\n",return_error);
		exit(return_error);
	}else{
		if ( debflg ) printf("DEB:OK Return 0\n");
		exit(0);
	}
}
