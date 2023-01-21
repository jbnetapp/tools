LIB=-lsocket -lnsl
INCLUDE=

CARG=-g 

all:httpget

main.o:main.c httpget.h
	gcc $(CARG) $(INCLUDE) -c -o main.o main.c


httpget.o:httpget.c httpget.h
	gcc $(CARG) $(INCLUDE) -c -o httpget.o httpget.c

httpget:httpget.o main.o
#	gcc $(CARG) $(INCLUDE) -o httpget httpget.o main.o $(LIB)
	gcc $(CARG) $(INCLUDE) -o httpget httpget.o main.o 
clean:
	-rm *.o httpget
