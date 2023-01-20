#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <netdb.h>
#include <arpa/telnet.h>
#include <syslog.h>

int s;				/* connected socket descriptor */
int ls;				/* listen socket descriptor */

struct hostent *hp;		/* pointer to host info for remote host */
struct servent *sp;		/* pointer to service information */

long timevar;			/* contains time returned by time() */
char *ctime();			/* declare time formatting routine */

struct linger linger;		/* allow a lingering, graceful close; */
				/* used when setting SO_LINGER */

struct sockaddr_in myaddr_in;	/* for local socket address */
struct sockaddr_in peeraddr_in;	/* for peer socket address */

char *servbyname;

main(argc, argv)
int argc;
char *argv[];
{
	int addrlen;

	memset ((char *)&myaddr_in, 0, sizeof(struct sockaddr_in));
	memset ((char *)&peeraddr_in, 0, sizeof(struct sockaddr_in));

	myaddr_in.sin_family = AF_INET;
	myaddr_in.sin_addr.s_addr = INADDR_ANY;

        if (argv[1] == NULL ) {
                servbyname = "mytelnetd" ;
        } else {
                servbyname = argv[1] ;
        }

	sp = getservbyname ( servbyname , "tcp");
	if (sp == NULL) {
		fprintf(stderr, "%s: example not found in /etc/services\n",
				servbyname);
		exit(1);
	}
	myaddr_in.sin_port = sp->s_port;

	ls = socket (AF_INET, SOCK_STREAM, 0);
	if (ls == -1) {
		perror(argv[0]);
		fprintf(stderr, "%s: unable to create socket\n", argv[0]);
		exit(1);
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

	switch (fork()) {
	case -1:		/* Unable to fork, for some reason. */
		perror(argv[0]);
		fprintf(stderr, "%s: unable to fork daemon\n", argv[0]);
		exit(1);

	case 0:			/* The child process (daemon) comes here. */
		close(stdin);
		close(stderr);
		signal(SIGCLD, SIG_IGN);
		for(;;) {
			addrlen = sizeof(struct sockaddr_in);
			s = accept(ls, &peeraddr_in, &addrlen);
			if ( s == -1) exit(1);
			switch (fork()) {
			case -1:	/* Can't fork, just exit. */
				exit(1);
			case 0:		/* Child process comes here. */
				server();
				exit(0);
			default:	
				close(s);
			}

		}

	default:		/* Parent process comes here. */
		exit(0);
	}
}

server()
{
	int reqcnt = 0;		/* keeps count of number of requests */
	char *netibuf;		/* Data telnet */
	char *inet_ntoa();
	char *hostname;		/* points to the remote host's name string */
	int len, len1;
	int netibufsize ;

        if (!(netibuf = (char *)malloc(BUFSIZ)))
           syslog(LOG_ERR, "netibuf malloc failed\n");
        netibufsize = BUFSIZ;
        bzero(netibuf, BUFSIZ);

	close(ls);

	hp = gethostbyaddr ((char *) &peeraddr_in.sin_addr,
				sizeof (struct in_addr),
				peeraddr_in.sin_family);

	if (hp == NULL) {
		hostname = inet_ntoa(peeraddr_in.sin_addr);
	} else {
		hostname = hp->h_name;	/* point to host's name */
	}
	time (&timevar);
	
	printf("Startup from %s port %u at %s",
		hostname, ntohs(peeraddr_in.sin_port), ctime(&timevar));

	linger.l_onoff  =1;
	linger.l_linger =1;
	if (setsockopt(s, SOL_SOCKET, SO_LINGER, &linger,
					sizeof(linger)) == -1) {
errout:		printf("Connection with %s aborted on error\n", hostname);
		exit(1);
	}
        /* send login */
	len = recv(s, netibuf, netibufsize, 0) ;
	if (len == -1) goto errout; 
	strcpy(netibuf,"login:");
	if (send(s, netibuf, netibufsize, 0) != netibufsize) 
           goto errout;
        /* send passwd */
	len = recv(s, netibuf, netibufsize, 0) ;
	if (len == -1) goto errout; 
	strcpy(netibuf,"passwd:");
	if (send(s, netibuf, netibufsize, 0) != netibufsize) 
           goto errout;

    while (!strstr(netibuf,"QUIT")) {
	   printf("netibuf:[%s]",netibuf);
           bzero(netibuf, BUFSIZ);
	   len = recv(s, netibuf, netibufsize, 0) ;
	   if (len == -1) goto errout; 
	   reqcnt++;
	   if (send(s, netibuf, netibufsize, 0) != netibufsize) {
             goto errout;
           }
	}
	close(s);

	time (&timevar);
	printf("Completed %s port %u, %d requests, at %s\n",
		hostname, ntohs(peeraddr_in.sin_port), reqcnt, ctime(&timevar));
}
