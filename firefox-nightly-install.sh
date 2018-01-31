#!/usr/bin/env bash

install_path="/opt/firefox-nightly/"

arch=`uname -m`
case $arch in
    "x86_64")   ;;
    "i686")             ;;
    *)  echo "Sorry, no firefox build available for $arch"; exit;;
esac

echo "Searching for nightly packages for Linux $arch..."

result=`curl -s http://ftp.mozilla.org/pub/mozilla.org/firefox/nightly/latest-trunk/ | grep "$arch\.tar\.bz2</a>" | tail -n1`

package="`echo "$result" | perl -ne 'm/<a .*?>(.*?)<\/a>/; print "$1\n"'`"
date="`echo "$result"    | perl -ne 'm/<a .*?>.*?<\/a><\/td><.*?>(.*?)\s+<\/td>/; print "$1\n"' | sed -r 's/\s/-/g'`"
size="`echo "$result"    | perl -ne 'm/<a .*?>.*?<\/a><\/td><.*?>.*?\s+<\/td><.*?>\s+(.*?)</; print "$1\n"'`"

[[ ".$package." == ".." ]] && echo "No packages found" && exit 1

case "$1" in
    "--ask")
        echo "Found package: $package - $date ($size)"

        read -p "Proceed with installation? [y/n] "
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Quitting... " && exit 0
        fi

        read -p "Install location? [$install_path] " path
        install_path=${path:-$install_path}
        ;;
esac

mkdir -p "$install_path/firefox-nightly" || exit

cd "$install_path/firefox-nightly"

echo "Dowloading $package to $install_path"
curl "http://ftp.mozilla.org/pub/mozilla.org/firefox/nightly/latest-trunk/$package" -o "$package" || exit

echo
echo "Unpacking $package"
tar xjf "$package"
echo

if [[ $EUID -ne 0 ]]; then
    echo "Need to be root to symlink"
    exit 1
fi

sudo ln -sf "$PWD/firefox/firefox" "/usr/local/bin/firefox-nightly" || exit
sudo -k

echo "Symlinked to /usr/local/bin/firefox-nightly"
echo

echo "Installed. Firefox-nightly may now be run by running /usr/local/bin/firefox-nightly"