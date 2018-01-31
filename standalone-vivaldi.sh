#!/bin/sh
# A script to unpack a Vivaldi .rpm or .deb package for use without
# installation.

# Use the most recent Vivaldi package in the current working
# directory or whatever the user has defined as the first option
# to this script.
if [ -n "$1" ]; then
  PKG="$1"
else
  PKG=`ls -t vivaldi*.rpm vivaldi*.deb 2>/dev/null | head -n 1`
fi

# Exit as soon as an error is encountered.
set -e

# Check that a suitable package has been specified.
VIVALDI_PKG_INFO=`echo "$PKG" | sed -n 's/.*\(vivaldi-[a-z]\+\)[_-]\(\([0-9]\+\.\)\{3\}[0-9]\+\)-[0-9]\+[_\.]\([a-z0-9_]\+\)\.\(deb\|rpm\)$/\1:\2:\4/p'`

if [ -z "$VIVALDI_PKG_INFO" ]; then
  echo 'You must specify the path to a locally stored Vivaldi Linux package.' >&2
  echo "Example usage: $0 vivaldi-stable-1.4.589.29-1.x86_64.rpm" >&2
  exit 1
fi

if [ ! -r "$PKG" ]; then
  echo "$PKG is either not present or cannot be read." >&2
  exit 1
fi

# Define the various variables obtained from information in the
# original package name.
VIVALDI_STREAM=`echo "$VIVALDI_PKG_INFO" | cut -d: -f1`
case "$VIVALDI_STREAM" in
   vivaldi-stable) VIVALDI_STREAM=vivaldi ;;
     vivaldi-beta) VIVALDI_STREAM=vivaldi ;;
esac

VIVALDI_VERSION=`echo "$VIVALDI_PKG_INFO" | cut -d: -f2`

VIVALDI_ARCH=`echo "$VIVALDI_PKG_INFO" | cut -d: -f3`
case "$VIVALDI_ARCH" in
   x86_64) VIVALDI_ARCH=x64 ;;
    amd64) VIVALDI_ARCH=x64 ;;
     i386) VIVALDI_ARCH=x86 ;;
esac

VIVDIR="$VIVALDI_STREAM-$VIVALDI_VERSION-$VIVALDI_ARCH"

if [ -d "$VIVDIR" ]; then
  echo "$VIVDIR already exists, aborting." >&2
  exit 0
fi

# Extract the package contents.
available () {
  command -v "$1" >/dev/null 2>&1
}

extract_rpm () {
  if available bsdtar; then
    bsdtar xf "$1" -C "$VIVDIR"
  elif available cpio; then
    tail -c+`grep -abom1 7zXZ "$1" | cut -d: -f1` "$1" | xz -d | (cd "$VIVDIR"; cpio --quiet -id)
  else
    echo 'You must install BSD tar or GNU cpio to use this script.' >&2
    exit 1
  fi
}

extract_deb () {
  if available bsdtar; then
    DEB_EXTRACT_COMMAND='bsdtar xOf'
  elif available ar; then
    DEB_EXTRACT_COMMAND='ar p'
  else
    echo 'You must install BSD tar or GNU binutils to use this script.' >&2
    exit 1
  fi
  $DEB_EXTRACT_COMMAND "$1" data.tar.xz | tar xJ -C "$VIVDIR"
}

mkdir "$VIVDIR"

case "$PKG" in
  *deb) extract_deb "$PKG" ;;
  *rpm) extract_rpm "$PKG" ;;
esac

cd "$VIVDIR"

# Make a symlink to launch Vivaldi
ln -s "opt/$VIVALDI_STREAM/$VIVALDI_STREAM" vivaldi

# Make a (standalone) testrun wrapper
cat << EOF > testrun
#!/bin/sh
exec "\${0%/*}/opt/$VIVALDI_STREAM/$VIVALDI_STREAM" --user-data-dir="\${0%/*}/temp-settings"  "\$@"
EOF

# Provide a script to integrate with the desktop environment 
cat << EOF > integrate
#!/bin/sh
set -e
XDG_DATA_HOME="\${XDG_DATA_HOME:-\$HOME/.local/share}"
available () {
  command -v "\$1" >/dev/null 2>&1
}
update_caches () {
  touch -c "\$XDG_DATA_HOME/icons/hicolor"
  if available gtk-update-icon-cache; then
    gtk-update-icon-cache -tq "\$XDG_DATA_HOME/icons/hicolor"
  fi
  if available update-desktop-database; then
    update-desktop-database -q "\$XDG_DATA_HOME/applications"
  fi
}
cd "\${0%/*}"
if [ -n "\$1" ]; then
  if [ "\$1" = "-r" -o "--remove" ]; then
    rm "\$XDG_DATA_HOME/icons/hicolor"/*x*/"apps/$VIVALDI_STREAM.png" "\$XDG_DATA_HOME/applications/$VIVALDI_STREAM.desktop"
    update_caches
    echo "Removed desktop environment integration."
    exit 0
  fi
fi
for png in opt/$VIVALDI_STREAM/product_logo_*.png; do
  sizepng="\${png##*/product_logo_}"
  install -Dm644 \$png "\$XDG_DATA_HOME/icons/hicolor/\${sizepng%.png}x\${sizepng%.png}/apps/$VIVALDI_STREAM.png"
done
mkdir -p "\$XDG_DATA_HOME/applications"
sed "/^Exec=/s,.*,Exec=\"\$PWD/vivaldi\" %U," usr/share/applications/vivaldi*.desktop > "\$XDG_DATA_HOME/applications/$VIVALDI_STREAM.desktop"
update_caches
echo "Integration with the desktop environment complete."
echo "You may need to re-login before Vivaldi shows up."
echo 'Note: To remove integration, rerun this script with "--remove".'
EOF

# Make scripts executable
chmod 755 testrun integrate

# Some instructions for the user
cat << EOF

To test run Vivaldi with temporary settings:

    $VIVDIR/testrun&

To run Vivaldi with your normal settings:

    $VIVDIR/vivaldi&

To integrate this copy of Vivaldi with your desktop environment:

    $VIVDIR/integrate

EOF