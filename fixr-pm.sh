#!/usr/bin/bash

set -e

#############
# Variables #
#############
readonly DEFAULT_WORKDIR=.

readonly PRIMARY_NAME="primary"
readonly PRIMARY_FILENAME="$PRIMARY_NAME.xml"
readonly PRIMARY_COMPRESSED_FILENAME="$PRIMARY_FILENAME.compressed"
readonly REPOMD_FILENAME="repomd.xml"

ARCH="$(uname -m)"

WORKDIR="$DEFAULT_WORKDIR"
PRIMARY_PATH="$WORKDIR/$PRIMARY_FILENAME"
PRIMARY_COMPRESSED_PATH="$WORKDIR/$PRIMARY_COMPRESSED_FILENAME"
REPOMD_PATH="$WORKDIR/$REPOMD_FILENAME"
PKGS_LIST_PATH="$WORKDIR/pkgs_list"
PKGS_DL_PATH="$WORKDIR/pkgs"

#############
# Functions #
#############
ENABLED_REPO_DATA="$(dnf -q repo info --enabled)"

echo "The following repotories are enabled on your system:"
grep Name <<<"$ENABLED_REPO_DATA" | while read -r repo_name; do
	sed 's/Name *:/-/' <<<"$repo_name"
done

BASE_ONLY_URLS="$(echo "$ENABLED_REPO_DATA" | grep -E '(Base URL|Metalink)' | sed -Ez 's/ *Base URL[^\n]+\n *Metalink[^\n]+\n//g' | grep -Eo 'http[^ ]+' | sed -E 's|/?$|/repodata/repomd.xml|' | sed -Ez 's/\nh/ h/g')"
REPOMD_URLS="$BASE_ONLY_URLS"

echo "Getting all repositories packages list..."
METALINK_URLS="$(echo "$ENABLED_REPO_DATA" | grep "Metalink" | grep -Eo 'http[^ ]+' | sed 's|/$||')"
for metalink_url in $METALINK_URLS; do
	[ -f "$REPOMD_FILENAME" ] && rm "$REPOMD_FILENAME"

    echo -n "Downloading $metalink_url... "
	REPOMD_URLS="${REPOMD_URLS} $(wget "$metalink_url" -O /dev/null | grep "HTTP response 206" | grep -Eo "http[^]]+")"
    echo "ok"
done

# Clean up packages list
echo -n >"$PKGS_LIST_PATH"

for repomd_url in $REPOMD_URLS; do

	# Follow a mirror and download repomd.xml.
	[ -f "$REPOMD_PATH" ] && rm "$REPOMD_PATH"
	repo_url="$(sed 's|/repodata/repomd.xml||' <<<"$repomd_url")"
	wget -q "${repomd_url}" -O "$REPOMD_PATH"

	# Download list of packages and files
	primary_url="$(grep "$PRIMARY_FILENAME" "$REPOMD_PATH" | cut -d '"' -f 2 | head -1)"
	[ -z "$primary_url" ] && continue
	wget "${repo_url}/$primary_url" -O "$PRIMARY_COMPRESSED_PATH"

	# Uncompressed data
	case "$(file $PRIMARY_COMPRESSED_PATH)" in
	*bzip2*) bzip2 -d "$PRIMARY_COMPRESSED_PATH" -c >"$PRIMARY_PATH" ;;
	*gzip*) gzip -d -f "$PRIMARY_COMPRESSED_PATH" -c >"$PRIMARY_PATH" ;;
	*)
		echo -n "Unsupported filetype: " >&2
		file "$PRIMARY_COMPRESSED_PATH" >&2
		continue
		;;
	esac

	echo "Getting repository packages data..."
	pkgs_data="$(grep -E '<(name|arch|file|location)' "$PRIMARY_PATH" |
		grep -Eoz "<name>[^<]+</name>[^<]+<arch>($ARCH|noarch)</arch>[^<]+<location[^<]+(<file[^<]+</file>[^<]+)+" |
		tr -d '\n' | sed -z 's/<name>/\n<name>/g' | sed '/^[\t ]*$/d' | sed 's/\x00//g')"

	# Loop over each package in repo
	echo "Searching for packages files on filesystem..."
	echo -n "$pkgs_data" | while read -r pkg_data; do
		name="$(sed -E 's|.*name>(.*)</name.*|\1|' <<<"$pkg_data")"
		href="$(sed -E 's|.*location href="(.*)"/>.*|\1|' <<<"$pkg_data")"
		files="$(sed -E 's|.*file( type="dir")?>(.*)</file.*|\2\n|' <<<"$pkg_data")"

		echo "Looking for package $name..."

		# Loop over each file provided by package
		for file in $files; do
			if [ -e "$file" ]; then
				echo "Package $name found."
				echo "${repo_url}/$href" >>"$PKGS_LIST_PATH"
				break
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
