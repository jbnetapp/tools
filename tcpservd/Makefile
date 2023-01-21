CC = gcc
#CFLG = -lsocket -lnsl
all: tcpservd tcpcli
tcpservd:tcpservd.c
	@echo "Make tcpservd"
	$(CC) $(CFLG) tcpservd.c -o tcpservd
tcpcli:tcpcli.c
	@echo "Make tcpcli"
	$(CC) $(CFLG) tcpcli.c -o tcpcli
clean:
	rm tcpservd;rm tcpcli;
