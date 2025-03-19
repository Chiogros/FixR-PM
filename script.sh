#!/usr/bin/bash

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
PKGS_TO_DL_PATH="$WORKDIR/pkgs_to_dl"
PKGS_DL_PATH="$WORKDIR/pkgs"

#############
# Functions #
#############
[ -f "$PKGS_TO_DL_PATH" ] && rm "$PKGS_TO_DL_PATH"

# Follow a mirror and download repomd.xml
[ -f "$REPOMD_FILENAME" ] && rm "$REPOMD_FILENAME"
repo_url="$(wget "$FEDORA_MIRRORS_URL" --metalink | sed -Ez "s/.*(http.*)\/$REPOMD_FILENAME.*/\1/")"

# Download list of packages and files
primary_url="$(grep "$PRIMARY_COMPRESSED_FILENAME" "$REPOMD_FILENAME" | cut -d '"' -f 2)"
wget -B "$repo_url" "$primary_url" -O "$PRIMARY_COMPRESSED_PATH"
gzip -d -f "$PRIMARY_COMPRESSED_PATH" -c >"$PRIMARY_PATH"

# Loop over the binaries
find /usr/bin | while read -r bin; do
	echo "path: $bin"

	# Get package providing binary
	hrefs="$(sqlite "$PRIMARY_PATH" -- "SELECT location_href FROM packages WHERE arch = '$ARCH' AND pkgKey IN (SELECT pkgKey FROM files WHERE name = '$bin')")"

	if [ -n "$hrefs" ]; then
		# Multiple packages may provide same file, print them all
		for href in $hrefs; do
			echo "href: $href"
			echo "$href" >>"$PKGS_TO_DL_PATH"
		done
	else
		echo "href: not found." >&2
	fi
done

# Download packages
echo "Start to download $(wc -l $PKGS_TO_DL_PATH) packages."
while read -r pkg; do
	continue
	wget -B "$repo_url" "$pkg" -P "$PKGS_DL_PATH" -c
done <"$PKGS_TO_DL_PATH"

# Handle RPM
sudo rpm --rebuilddb

# Install packages
for pkg in "$PKGS_DL_PATH"/*.rpm; do
	sudo rpm -i -v --nodeps --justdb "$pkg"
done
