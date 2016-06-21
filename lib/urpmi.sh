#! /bin/sh -e
urpmi.removemedia -a
urpmi.addmedia --distrib --all-media --mirrorlist http://mirrors.mageia.org/api/mageia.$MGARELEASE.$ARCH.list
perl -pne 's%(.*testing.*) {\n%\1 {\n  ignore\n%i' -i /etc/urpmi/urpmi.cfg
#remove distrib-coffee line from mirrors cache
#perl -pne 'undef $/; s% +{(?:\n +.(?:country|proximity|longitude|arch|version|zone|latitude).[^,]+,){7}\n +.url.[^,]+distrib-coffee[^,]+,(?:\n +.(?:type|proximity_corrected).[^,]+,){2}\n%%' -i /var/cache/urpmi/mirrors.cache
