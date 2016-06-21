#! /bin/sh -e

# Clear config
cat /dev/null > root.conf

# Append every config parameters
for i in `cat config/*.conf | perl -pne 'undef $_ if /^#/; s/=.*$//'`; do
	eval echo ${i}=\$$i | tee -a root.conf
done
