#!/bin/bash -x

# This script copies all the necessary scripts to their locations in /etc or wherever.
# Run me as root (sudo ~deploy/etc/bootstrap.sh)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p /etc/varnish
cp varnish_default.vcl /etc/varnish/default.vcl
cp 503.html /etc/varnish/
pidof `which varnishd` && service varnish reload

# This will require a restart of varnish to take effect. I'm not doing that
# here so you can re-run this script on running instances without bothering
# anything.
cp varnish /etc/default/varnish
