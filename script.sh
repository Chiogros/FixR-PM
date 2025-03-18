#!/usr/bin/sh

readonly DEFAULT_WORKDIR=/tmp
readonly FILELIST_DB="$DEFAULT_WORKDIR/filelists.sqlite"
readonly ARCH="$(uname -m)"
readonly OS_VERSION="$(grep VERSION_ID /etc/os-release | cut -d '=' -f 2)"

WORKDIR=$DEFAULT_WORKDIR

# Loop over the binaries
find /usr/bin | while read -r bin; do
	echo "Name: $bin"

	# Look for package ID related to binary name
	sqlite "$FILELIST_DB" -- "SELECT pkgKey FROM files WHERE name = '$bin'" | while read -r pkgKey; do

		# Get package name providing binary
		href="$(sqlite "$FILELIST_DB" -- "SELECT location_href FROM packages WHERE pkgKey = $pkgKey AND arch = '$ARCH'")"

		if [ -n "$href" ]; then
			echo "href: $href"
		else
			echo "No package found for arch or not from any repository." >&2
		fi
	done
done

# rpm --rebuilddb
