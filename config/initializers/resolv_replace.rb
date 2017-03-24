
# This fixes a bug in older versions of glibc, where name resolution under high load sometimes fails.
# http://blog.gregburek.com/2015/02/22/dns-eglibc-and-resolv-replace-on-heroku/
require 'resolv-replace'
