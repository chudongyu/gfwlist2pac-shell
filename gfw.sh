#! /bin/zsh

# Generated by gfwlist2pac
# created by @clowwindy via python
# modified by @cube via native zsh
# https://github.com/cuber/gfwlist2pac

# url
XLDURL="https://publicsuffix.org/list/effective_tld_names.dat"
GFWURL="https://autoproxy-gfwlist.googlecode.com/svn/trunk/gfwlist.txt"

# socks5 proxy ssh -D, shadowsocks or others
PROXY="127.0.0.1:7070"

# curl & openssl cli command path
CURL=/usr/bin/curl
CURLOPT=(-s -x socks5://$PROXY)
OPENSSL=/usr/bin/openssl

# get current dirname
DIR=$(cd $(dirname $0); pwd)

# load util functions
source $DIR/util.sh
typeset -A XLD
typeset -A UNIQ
for i in $($CURL $CURLOPT $XLDURL | grep -v -e '^\s*$' -e '^/'); do XLD[$i]=1; done

# output pac file
PAC=$1
if [ -z $PAC ]; then  
  echo "Usage. ./gfw.sh [filename.pac]"
  echo "  Eg. ./gfw.sh release/proxy.pac"
  echo "  The proxy.pac will be generated to release/proxy.pac"
  exit 1
fi

# make sure pac dirname exists
PACDIR=$(dirname $PAC)
if [ ! -d $PACDIR ]; then mkdir -p $PACDIR; fi

cat > $PAC <<EOF
// Generated by gfwlist2pac
// created by @clowwindy via python
// modified by @cube via native zsh
// https://github.com/cuber/gfwlist2pac
var domains = {
EOF

cat $DIR/custom.txt \
  | grep -v '^\s*$' \
  | sed -e s'/^\s*//'g -e s'/\s*$//'g \
  | valid

$CURL $CURLOPT $GFWURL \
  | $OPENSSL base64 -d \
  | urldecode \
  | grep -v \
      -e 'google' \
      -e '^\s*$' \
      -e '^[\[!]' \
  | sed \
      -e s'/^[@|]*//'g \
      -e s'/^http[s]*:\/\///'g \
      -e s'/\/.*$//'g \
      -e s'/\*.*$//'g \
      -e s'/^\s*//'g \
      -e s'/\s*$//'g \
      -e s'/^\.//'g 2>/dev/null \
  | grep \
      -e '\.' \
  | grep -v \
      -e '^\s*$' \
      -e '^!' \
  | valid

DOMAINS=()
for i in ${(k)UNIQ}; do DOMAINS+=("  '$i': 1"); done
echo ${(j:,\n:)DOMAINS} >> $PAC

cat >> $PAC <<EOF
} // end of domains

// proxy failover
var proxy  = 'SOCKS5 $PROXY; SOCKS $PROXY; DIRECT;'
var direct = 'DIRECT;'

// function of proxy router
function FindProxyForURL(url, host) {
  // restrict all google related domains to proxy
  if (/google/i.test(host)) return proxy;
  // recursive detection domains
  do {
    if (domains.hasOwnProperty(host)) return proxy;
    off  = host.indexOf('.') + 1;
    host = host.slice(off);
  } while (off >= 1);
  return direct;
}
EOF

exit 0
