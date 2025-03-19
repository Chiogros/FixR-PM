# FixR-PM

> for FixRPM, or FixR-Package Manager

Feeling sad after doing a `rm -rf /var/lib/rpm`? FixR gets you covered!

It is a all-in-one shell (non POSIX) script which:
- scan folders where packages usually store files (binaries, config, libraries, ...)
- try to find a corresponding package in your distribution which bring those files
- download the packages
- install the packages _without doing any modification to your files_, only to update RPM database
