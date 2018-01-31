#!/bin/sh
set -e
if [ -z "$1" ]; then
  echo 'You must specify the path to a locally stored Vivaldi Linux package.' >&2
  echo "Example usage: `basename $0` vivaldi-snapshot-1.0.233.3-1.x86_64.rpm" >&2
  exit 1
fi
if ! echo "$1" | grep -q '[Vv]ivaldi.*\.\(deb\|rpm\)$'; then
  echo "$1 is not named like a Vivaldi Linux package" >&2
  exit 1
fi
if [ ! -r "$1" ]; then
  echo "$1 is either not present or cannot be read" >&2
  exit 1
fi
available () {
  command -v "$1" >/dev/null 2>&1
}
mk_output_dir () {
  if [ -d "$OUTPUT_DIR" ]; then
    echo "$OUTPUT_DIR is already present"
    exit 1
  else
    mkdir "$OUTPUT_DIR"
  fi
}
extract_rpm () {
  if available bsdtar; then
    OUTPUT_DIR="`head -c96 $1 | strings`"
    mk_output_dir
    bsdtar xf "$1" -C "$OUTPUT_DIR" 
  elif available cpio; then
    OUTPUT_DIR="`head -c96 $1 | strings`"
    mk_output_dir
    tail -c+`grep -abom1 7zXZ "$1" | cut -d: -f1` "$1" | xz -d | (cd "$OUTPUT_DIR"; cpio --quiet -id)
  else
    echo 'You must install BSD tar or GNU cpio to use this script' >&2
    exit 1
  fi
}
extract_deb () {
  if available bsdtar; then
    DEB_EXTRACT_COMMAND='bsdtar xOf'
  elif available ar; then
    DEB_EXTRACT_COMMAND='ar p'
  else
    echo 'You must install BSD tar or GNU binutils to use this script' >&2
    exit 1
  fi
  OUTPUT_DIR="`basename $1 .deb`"
  mk_output_dir
  $DEB_EXTRACT_COMMAND "$1" data.tar.xz | tar xJ -C "$OUTPUT_DIR"
}
case "$1" in
  *deb) extract_deb "$1" ;;
  *rpm) extract_rpm "$1" ;;
esac
cd "$OUTPUT_DIR"
SETUID_SBX=Y
if available bc; then
  KVER=`uname -r | cut -d. -f-2`
  if [ -n "$KVER" ]; then
    if [ 1 -eq "`echo "$KVER > 3.16" | bc`" ]; then
      if [ -r "/proc/config.gz" ] && gzip -dc /proc/config.gz | grep -qx 'CONFIG_USER_NS=[yY]' 2>/dev/null; then
        SETUID_SBX=N
      fi
    fi
  fi
fi
if [ "$SETUID_SBX" = "Y" ] && [ -r "/etc/os-release" ]; then
  . /etc/os-release
  if [ "$ID" = "ubuntu" ]; then
    if [ 1 -eq "`echo "$VERSION_ID > 14.04" | bc`" ]; then
      SETUID_SBX=N
    fi
  fi
fi
mv usr files
mv opt files
rm -fr etc
VIVALDI_STREAM=`basename files/opt/vivaldi*`
for png in files/opt/$VIVALDI_STREAM/product_logo_*.png; do
  pngsize="${png##*/product_logo_}"
  mkdir -p files/share/icons/hicolor/${pngsize%.png}x${pngsize%.png}/apps
  (
    cd files/share/icons/hicolor/${pngsize%.png}x${pngsize%.png}/apps/
    ln -s ../../../../../opt/$VIVALDI_STREAM/product_logo_${pngsize} $VIVALDI_STREAM.png
  )
done
DESKTOP_FILE_LOCATION=`echo files/share/applications/*.desktop`
sed 's,/usr/bin/,,' "$DESKTOP_FILE_LOCATION" > "${DESKTOP_FILE_LOCATION}.updated"
cat "${DESKTOP_FILE_LOCATION}.updated" > "$DESKTOP_FILE_LOCATION"
rm "${DESKTOP_FILE_LOCATION}.updated"
rm -fr files/share/xfce4
( cd files/bin; ln -fs ../opt/$VIVALDI_STREAM/$VIVALDI_STREAM vivaldi* )
if [ "$SETUID_SBX" = "Y" ]; then
  SBX=`echo files/opt/vivaldi*/vivaldi-sandbox`
  if [ -n "$CHROME_DEVEL_SANDBOX" ]; then
    mv "$SBX" "${SBX}.backup"
  elif [ "${ID:-unknown}" = "ubuntu" ]; then
    echo "Calling sudo ... If prompted, please enter your password to give vivaldi-sandbox sufficient permissions to function properly with your Linux kernel."
    sudo chown root:root $SBX && sudo chmod 4755 $SBX
  else
    echo "Please enter your root password to give vivaldi-sandbox sufficient permissions to function properly with your Linux kernel."
    su -c "(chown root:root $SBX && chmod 4755 $SBX)"
  fi
fi
VIV_BIN=`echo files/opt/vivaldi*/vivaldi-bin`
cat <<EOF>run
#!/bin/sh
if [ -n "\$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH="\${0%/*}/${VIV_BIN%/*}:\$LD_LIBRARY_PATH"
else
  LD_LIBRARY_PATH="\${0%/*}/${VIV_BIN%/*}"
fi
export LD_LIBRARY_PATH
if [ -r '/usr/lib/adobe-flashplugin/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/usr/lib/adobe-flashplugin/libpepflashplayer.so' # Adobe (Canonical Partner repository)
elif [ -r '/opt/google/chrome/PepperFlash/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/opt/google/chrome/PepperFlash/libpepflashplayer.so' # Google
elif [ -r '/usr/lib/pepperflashplugin-nonfree/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/usr/lib/pepperflashplugin-nonfree/libpepflashplayer.so' # Debian/Ubuntu
elif [ -r '/usr/lib/pepflashplugin-installer/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/usr/lib/pepflashplugin-installer/libpepflashplayer.so' # ppa:skunk/pepper-flash
elif [ -r '/usr/lib64/PepperFlash/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/usr/lib/PepperFlash/libpepflashplayer.so' # Arch
elif [ -r '/usr/lib64/chromium/PepperFlash/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/usr/lib64/chromium/PepperFlash/libpepflashplayer.so' # OpenSUSE/Slackware 64bit
elif [ -r '/usr/lib/chromium/PepperFlash/libpepflashplayer.so' ]; then
  PPAPI_FLASH_LOCATION='/usr/lib/chromium/PepperFlash/libpepflashplayer.so' # OpenSUSE/Slackware 32bit
elif [ -f "/usr/lib/chromium-browser/PepperFlash/libpepflashplayer.so" ]; then
  PPAPI_FLASH_LOCATION='/usr/lib/chromium-browser/PepperFlash/libpepflashplayer.so' # Rosa/Mandriva 32-bit
elif [ -f "/usr/lib64/chromium-browser/PepperFlash/libpepflashplayer.so" ]; then
  PPAPI_FLASH_LOCATION='/usr/lib64/chromium-browser/PepperFlash/libpepflashplayer.so' # Rosa/Mandriva 64-bit
fi
if [ -n "\$PPAPI_FLASH_LOCATION" ]; then
  exec "\${0%/*}/$VIV_BIN" --ppapi-flash-path="\$PPAPI_FLASH_LOCATION" --ppapi-flash-version=6.6.6.999 --user-data-dir="\${0%/*}/profile"  "\$@"
fi
exec "\${0%/*}/$VIV_BIN" --user-data-dir="\${0%/*}/profile"  "\$@"
EOF
cat <<EOF>install
#!/bin/sh
set -e
if [ "\$UID" = "0" ]; then
  VIVALDI_INSTALL_DIR="\${VIVALDI_INSTALL_DIR:-/usr/local}"
else
  VIVALDI_INSTALL_DIR="\${VIVALDI_INSTALL_DIR:-\$HOME/.local}"
fi
available () {
  command -v "\$1" >/dev/null 2>&1
}
if [ -n "\$1" ]; then
  if [ "\$1" = "-p" ]; then
    WARNING=Y
  fi
fi
if [ ! "\$UID" = "0" ] && [ "\${WARNING:-N}" = "N" ]; then
cat <<WARN 2>&1

Install, just for your user (\$USER)? You will need a suitable kernel for single-user installs. Kernel's greater than 3.17 will _probably_ be OK. 

Cancelling the script and re-running as root (or prefaced with sudo) to do a system-wide install is more reliable. In either case an uninstall script is generated, so the risk of trying is low. ;)

WARN
  read -p "Do you wish to proceed (or quit) with install into \"\$VIVALDI_INSTALL_DIR\" [p/Q]: " PQ
  case "\$PQ" in
    [PpYy]*) break ;;
    [QqNn]*) printf "\nAborting install.\n" ; exit ;;
         *) printf '\nAnswer not recognised, assuming "Quit". Aborting install.\n'; exit ;;
  esac
fi
cd "\${0%/*}/files"
RM_SCRIPT="\$VIVALDI_INSTALL_DIR/\`echo bin/remove-vivaldi*\`"
if [ -x "\$RM_SCRIPT" ]; then
  printf "Vivaldi is already installed. It will be removed before upgrading.\n\n"
  "\$RM_SCRIPT"
fi
mkdir -p "\$VIVALDI_INSTALL_DIR"
printf "\nInstalling Vivaldi into: \"\$VIVALDI_INSTALL_DIR\"\n\n"
find . ! -type d | tar -cf- -T- | tar -xvf- -C "\$VIVALDI_INSTALL_DIR" | sed 's/.*/./' | tr -d '\n'
DESKTOP_FILE_LOCATION="\$VIVALDI_INSTALL_DIR/\`echo share/applications/*.desktop\`"
sed "s,Exec=.*vivaldi,Exec=\$VIVALDI_INSTALL_DIR/bin/vivaldi," "\$DESKTOP_FILE_LOCATION" > "\$DESKTOP_FILE_LOCATION.updated"
cat "\$DESKTOP_FILE_LOCATION.updated" > "\$DESKTOP_FILE_LOCATION"
rm "\$DESKTOP_FILE_LOCATION.updated"
sed "s,^cd .*#$,cd \"\$VIVALDI_INSTALL_DIR\" #," "\$RM_SCRIPT" > "\$RM_SCRIPT.updated"
cat "\$RM_SCRIPT.updated" > "\$RM_SCRIPT"
rm "\$RM_SCRIPT.updated"
if [ "\$UID" = "0" ]; then
  VIVALDI_SANDBOX="\$VIVALDI_INSTALL_DIR/\`echo opt/vivaldi*/vivaldi-sandbox*\`"
  chown root:root "\$VIVALDI_SANDBOX"
  chmod 4755 "\$VIVALDI_SANDBOX"
fi
touch -c "\$VIVALDI_INSTALL_DIR/share/icons/hicolor"
if available gtk-update-icon-cache; then
  gtk-update-icon-cache -tq "\$VIVALDI_INSTALL_DIR/share/icons/hicolor"
fi
if available update-desktop-database; then
  update-desktop-database -q "\$VIVALDI_INSTALL_DIR/share/applications"
fi
printf " Installed.\n\n"
echo "To uninstall issue:"
echo "  \$RM_SCRIPT"
EOF
cat <<EOF> files/bin/remove-$VIVALDI_STREAM
#!/bin/sh
set -e
cd "\${0%/bin/*}" #
while read f; do
  if [ -e "\$f" -o -h "\$f" ]; then
    if [ -d "\$f" ]; then
      if ! ls -A "\$f" | grep -q ^; then
        if [ ! -h "\$f" ]; then
          rmdir "\$f"
        fi
      fi
    else
      rm "\$f"
      printf '.'
    fi
  fi
done << FILE_LIST
EOF
find files ! -type d | grep -v 'bin/remove' | sed 's,^files/,,' >> files/bin/remove-$VIVALDI_STREAM
find files -depth -type d | sed 's,^files/,,' | grep -xv files >> files/bin/remove-$VIVALDI_STREAM
printf "FILE_LIST\nrm bin/remove-$VIVALDI_STREAM\necho '. Removed.'" >> files/bin/remove-$VIVALDI_STREAM
chmod 755 run install files/bin/remove-$VIVALDI_STREAM
printf "\nThe directory $OUTPUT_DIR has been created, to start Vivaldi:\n"
printf "\n\t$OUTPUT_DIR/run&\n"
printf "\nTo install:\n"
printf "\n\t$OUTPUT_DIR/install\n\n"
