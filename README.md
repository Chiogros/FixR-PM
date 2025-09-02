# FixR-PM

> for FixRPM, or FixR-Package Manager

Feeling sad after doing a `rm -rf /var/lib/rpm`? FixR gets you covered!

It is a all-in-one shell (non POSIX) script which:
- scan folders where packages usually store files (binaries, config, libraries, ...)
- try to find a corresponding package in your distribution which bring those files
- download the packages
- install the packages _without doing any modification to your files_, only to update RPM database

## Getting started

Download FixR script:
```sh
# You may use wget or cul, depending on the one installed on your system
$ wget https://github.com/Chiogros/FixR-PM/raw/refs/heads/main/fixr-pm.sh
$ curl https://github.com/Chiogros/FixR-PM/raw/refs/heads/main/fixr-pm.sh -o fixr-ph.sh
```

Execute FixR:
> [!WARNING]
> While running, it may download from MB to GB of files depending on how many packages you had installed.
> Make sure to move the script to a mounted partition with enough free space.
```sh
$ sudo ./fixr-pm.sh
[...] a lot of output...
```

Refresh system package manager:
> [!NOTE]
> If you encounter error messages about conflicting packages,
> pick any that you may have never installed and remove them (`dnf remove`).
```sh
$ sudo dnf update
```
