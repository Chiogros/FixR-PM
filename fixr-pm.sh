#!/usr/bin/bash

#############
# Variables #
#############
readonly DEFAULT_WORKDIR=/tmp

readonly PRIMARY_NAME="primary"
readonly PRIMARY_FILENAME="$PRIMARY_NAME.sqlite"
readonly PRIMARY_COMPRESSED_FILENAME="$PRIMARY_FILENAME.compressed"
readonly REPOMD_FILENAME="repomd.xml"
declare -ar COMMON_PKG_FILES_PATH=("/usr" "/etc")

ARCH="$(uname -m)"
REPO_URLS="$(dnf -q repo info --enabled | grep "Base URL" | grep -Eo 'http[^ ]+' | sed 's/\/$//')"

WORKDIR="$DEFAULT_WORKDIR"
PRIMARY_PATH="$WORKDIR/$PRIMARY_FILENAME"
PRIMARY_COMPRESSED_PATH="$WORKDIR/$PRIMARY_COMPRESSED_FILENAME"
REPOMD_PATH="$WORKDIR/$REPOMD_FILENAME"
PKGS_LIST_PATH="$WORKDIR/pkgs_list"
PKGS_DL_PATH="$WORKDIR/pkgs"

#############
# Functions #
#############

echo -n >"$PKGS_LIST_PATH"

for repo_url in $REPO_URLS; do

	# Follow a mirror and download repomd.xml.
	[ -f "$REPOMD_PATH" ] && rm "$REPOMD_PATH"
	repomd_url="${repo_url}/repodata/repomd.xml"
	wget "${repomd_url}" -O "$REPOMD_PATH"

	# Download list of packages and files
	primary_url="$(grep "$PRIMARY_FILENAME" "$REPOMD_PATH" | cut -d '"' -f 2)"
	[ -z "$primary_url" ] && continue
	wget "${repo_url}/$primary_url" -O "$PRIMARY_COMPRESSED_PATH"

	# Uncompressed data
	case "$(file $PRIMARY_COMPRESSED_PATH)" in
	*bzip2*) bzip2 -d "$PRIMARY_COMPRESSED_PATH" -c >"$PRIMARY_PATH" ;;
	*gzip*) gzip -d -f "$PRIMARY_COMPRESSED_PATH" -c >"$PRIMARY_PATH" ;;
	*)
		echo "Unsupported filetype:" >&2
		file "$PRIMARY_COMPRESSED_PATH" >&2
		continue
		;;
	esac

	# Loop over each directory
	for common_path in "${COMMON_PKG_FILES_PATH[@]}"; do

		# Loop over each file
		find "$common_path" 2>/dev/null | while read -r bin; do

			#echo "path: $bin"

			# Get package providing file
			hrefs="$(sqlite "$PRIMARY_PATH" -- "SELECT location_href FROM packages WHERE (arch = '$ARCH' or arch = 'noarch') AND pkgKey IN (SELECT pkgKey FROM files WHERE name = '$bin')")"

			if [ -n "$hrefs" ]; then
				# Print all packages providing file
				for href in $hrefs; do
					echo "href: $href"
					echo "${repo_url}/$href" >>"$PKGS_LIST_PATH"
				done
			else
				#echo "href: not found." >&2
				echo -n
			fi
		done
	done
done

# Multiple files may be brought by a single package, clean list to avoid useless requests.
sort -u -o "$PKGS_LIST_PATH" "$PKGS_LIST_PATH"

nb_of_pkgs="$(wc -l $PKGS_LIST_PATH | cut -d ' ' -f 1)"
if [ "$nb_of_pkgs" -eq 0 ]; then
	echo "No packages found."
	exit 1
fi

# Download packages
echo "Start to download $nb_of_pkgs packages."
wget -i "$PKGS_LIST_PATH" -P "$PKGS_DL_PATH" -c

# Rebuild RPM database
sudo rpm --rebuilddb

# Install packages
for pkg in "$PKGS_DL_PATH"/*.rpm; do
	sudo rpm -i -v --nodeps --justdb "$pkg" || continue
done
