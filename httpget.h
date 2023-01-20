/** 
 * this lib get a file from an http server
 */

#ifndef HTTPGET_H
#define HTTPGET_H

#include <sys/types.h>

#define BUFFER_SIZE 256 /* initial buffer size */
#define URL_MAX_LENGTH 2048 /*maximum url length*/

#ifndef BUFFER_TYPE
#define BUFFER_TYPE
/**
 * Buffer, contains data, and its size
 * Allocated memory for data is >= size
 */
typedef struct {
   size_t size; /* buffer content size */
   char* data; /* buffer data */
} buffer;
#endif
/**
 * retrieve a file thru http get, via a proxy, in a buffer
 * @param proxyHost http proxy host name
 * @param proxyPort http proxy TCP port
 * @param host http server host name
 * @param port http server TCP port
 * @param path http path of the file to retrieve
 * @return a buffer containing the file
 */
buffer* httpProxyGet(char* proxyHost,int proxyPort,char* host,int port,
char* path);

/**
 * retrieve a file thru http get in a buffer
 * @param host http server host name
 * @param port http server TCP port
 * @param path http path of the file to retrieve (must begin with /)
 * @return a buffer containing the file
 */
buffer* httpGet(char* host,int port,char* path);

/**
 * read from s until no more data is available
 * @param s file descriptor to read from
 * @return a buffer containing the data
 */
buffer * readAll(int s);

/**
 * read exactly len bytes from s
 * @param s file descriptor to read from
 * @param len number on byte to read
 * @return a buffer containing the data
 */
buffer * readExact(int s,size_t len);

#endif
