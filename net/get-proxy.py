# Require this python module
# python3 -m pip install requests-toolbelt
import argparse
import getpass
import sys
import configparser
import json
import os
import requests
import requests.auth

parser = argparse.ArgumentParser()
parser.add_argument("-d", "--debug", dest='debug', help="debug mode", action="store_true")
parser.add_argument("-u", "--url", dest='url', help="url")
parser.add_argument("--proxy-auth", "--pa", dest='proxy_auth', help="proxies auth (none,basic(n),digest(n)")
parser.add_argument("--proxy-server", "--pserver", dest='pserver', help="proxies server")
parser.add_argument("--proxy-port", "--pport", dest='pport', help="proxies port")
parser.add_argument("--proxy-login", "--plogin", dest='plogin', help="proxies login")
parser.add_argument("--proxy-passwd", "--ppasswd", dest='ppasswd', help="proxies login")
args = parser.parse_args()


if args.plogin:
     plogin=args.plogin
else:
     plogin="blanchet"

if args.ppasswd:
     ppasswd=args.ppasswd
else:
     ppasswd="Netapp1!"

if args.pserver:
     pserver=args.pserver
else:
     pserver="proxy.netapp.com"

if args.pport:
     pport=args.pport
else:
     pport="3128"

proxy_status="UNKNOWN"

if args.url:
    URL=args.url
else:
    exit(1)
if args.proxy_auth:
    #######################################################################################
    if ( args.proxy_auth == "none" ):
         proxy_status="TRUE: WITH NO AUTHENTICATION"
         print("AUTH = NONE")
         proxies = {
             "http" :"http://{}:{}".format(pserver,pport),
             "https":"http://{}:{}".format(pserver,pport),
         }
         try:
              r = requests.get(URL, proxies=proxies)
              print(r.text)
              print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)
    #######################################################################################
    if ( args.proxy_auth == "basic1" ):
         # OK This Basic Methode Work 
         from requests.auth import HTTPProxyAuth
         proxy_status="TRUE: WITH BASIC 1 AUTHENTICATION"
         print("AUTH = BASIC 1")
         proxies = { 
              'http':'http://{}:{}@{}:{}'.format(plogin,ppasswd,pserver,pport), 
              'https':'http://{}:{}@{}:{}'.format(plogin,ppasswd,pserver,pport), 
         }
         try:
              r = requests.get(URL, proxies=proxies)
              print(r.text)
              print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)

    if ( args.proxy_auth == "basic2" ):
         # FAILED 
         from requests.auth import HTTPProxyAuth
         proxy_status="TRUE: WITH BASIC 2 AUTHENTICATION"
         print("AUTH = BASIC")
         proxies = { 
             "http":"http://{}:{}".format(pserver,pport),
             "https":"http://{}:{}".format(pserver,pport),
         }
         try:
              auth = HTTPProxyAuth(plogin, ppasswd)
              r = requests.get(URL, proxies=proxies, auth=auth)
              print(r.text)
              print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)

    #######################################################################################
    if ( args.proxy_auth == "digest1" ):
         # FAILED
         from requests.auth import HTTPDigestAuth
         proxy_status="TRUE: WITH DIGEST 1 AUTHENTICATION"
         print("AUTH = DIGEST")
         proxies = {
             "http":"http://{}:{}".format(pserver,pport),
             "https":"http://{}:{}".format(pserver,pport),
         }
         try:
             auth = HTTPDigestAuth(plogin, ppasswd)
             r = requests.get(URL, proxies=proxies, auth=auth)
             print(r.text)
             print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)

    if ( args.proxy_auth == "digest2" ):
         # FAILED 
         from requests.auth import HTTPDigestAuth
         proxy_status="TRUE: WITH DIGEST 2 AUTHENTICATION"
         print("AUTH = DIGEST")
         proxies = { 
              'http':'http://{}:{}@{}:{}'.format(plogin,ppasswd,pserver,pport), 
              'https':'http://{}:{}@{}:{}'.format(plogin,ppasswd,pserver,pport), 
         }
         try:
              auth = HTTPDigestAuth(plogin, ppasswd)
              r = requests.get(URL, proxies=proxies, auth=auth)
              print(r.text)
              print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)

    if ( args.proxy_auth == "digest3" ):
         # OK with SQID BUT BUG with HTTPS
         # https://toolbelt.readthedocs.io/en/latest/authentication.html#httpproxydigestauth
         # https://github.com/requests/toolbelt/issues/136
         from requests_toolbelt.auth.http_proxy_digest import HTTPProxyDigestAuth
         proxy_status="TRUE: WITH DIGEST 1 AUTHENTICATION"
         print("AUTH = DIGEST")
         proxies = {
             "http":"http://{}:{}".format(pserver,pport),
             "https":"http://{}:{}".format(pserver,pport),
         }
         try:
              auth = HTTPProxyDigestAuth(plogin, ppasswd)
              r = requests.get(URL, proxies=proxies, auth=auth)
              print(r.text)
              print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)

    #######################################################################################
    if ( args.proxy_auth == "full" ):
         # OK with SQID BUT BUG with HTTPS
         # https://toolbelt.readthedocs.io/en/latest/authentication.html#guessproxyauth 
         # https://github.com/requests/toolbelt/issues/136
         from requests_toolbelt.auth.guess import GuessProxyAuth 
         proxy_status="TRUE: WITH FULL AUTHENTICATION"
         print("AUTH = BASIC")
         proxies = { 
             "http":"http://{}:{}".format(pserver,pport),
         #BUG   "https":"http://{}:{}".format(pserver,pport),
         }
         try:
              auth = GuessProxyAuth(None, None,plogin,ppasswd)
              r = requests.get(URL, proxies=proxies, auth=auth)
              print(r.text)
              print(r.status_code)
         except BaseException as e:
              print("ERROR: {}".format(e))
              exit(1)

else:
    proxy_status="FALSE"
    proxies={} 
    auth={}
    r = requests.get(URL,proxies=proxies,auth=auth)
    print(r.text)
    print(r.status_code)

print("PROXY = [{}]".format(proxy_status))
