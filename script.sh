#!/usr/bin/sh

#############
# Variables #
#############
readonly DEFAULT_WORKDIR=/tmp

readonly ARCH="$(uname -m)"
readonly OS_VERSION="$(grep VERSION_ID /etc/os-release | cut -d '=' -f 2)"

readonly FEDORA_MIRRORS_URL="https://mirrors.fedoraproject.org/metalink?repo=fedora-${OS_VERSION}&arch=${ARCH}"

readonly PRIMARY_NAME="primary"
readonly PRIMARY_FILENAME="$PRIMARY_NAME.sqlite"
readonly PRIMARY_COMPRESSED_FILENAME="$PRIMARY_FILENAME.gz"
readonly REPOMD_FILENAME="repomd.xml"

WORKDIR=$DEFAULT_WORKDIR
PRIMARY_PATH="$WORKDIR/$PRIMARY_FILENAME"
PRIMARY_COMPRESSED_PATH="$WORKDIR/$PRIMARY_COMPRESSED_FILENAME"
REPOMDXML_PATH="$WORKDIR/$REPOMD_FILENAME"

#############
# Functions #
#############
# Follow a mirror and download repomd.xml
[ -f "$REPOMD_FILENAME" ] && rm "$REPOMD_FILENAME"
repo_url="$(wget "$FEDORA_MIRRORS_URL" --metalink | sed -Ez "s/.*(http.*)\/$REPOMD_FILENAME.*/\1/")"

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
