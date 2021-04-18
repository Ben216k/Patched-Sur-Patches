#!/bin/bash

error() {
    echo
    echo "$1" 1>&2
    exit 1
}

# echo -ne "\033[2K" ; printf "\r"

echo 'Welcome to Patched Sur recovery!'
echo "Don't worry, you'll be up and running in just a second!"
echo "Right now, Patched Sur just needs to set a couple things up."
echo "After that, you'll be back to what feels and (mostly acts just like recovery mode)."
echo

# MARK: Verify Environment

sleep 0.1
echo -n 'Verifying Environment'

[ $UID = 0 ] || error 'This is not macOS recovery.'
#[ -d "/Volumes/macOS Base System" ] || error 'This is not macOS recovery.'

VOLUMENAME="$(echo "$0" | cut -c10- | cut -f1 -d"/")"
PSPATCHES="/Volumes/$VOLUMENAME/usr/local/lib/Patched-Sur-Patches"
#echo "$VOLUMENAME"

if [ -d "/Volumes/Image Volume/" ]; then
    echo
    echo "This is not native recovery mode."
    echo "This might be an installer USB, and StartPSRecovery"
    echo "is not meant for USB installers. Patched Sur can"
    echo "take care of that without you helping. So quit Terminal"
    echo "and do what you want to do."
    exit 1
fi

echo -ne "\033[2K" ; printf "\r"
echo -n "Mounting FileSystem"

RECOVERYID="$(diskutil list | grep Recovery | cut -c 71-)"
diskutil mount "$RECOVERYID" >/dev/null || error "Failed to mount recovery volume."
mount -uw /Volumes/Recovery || error "Failed to remount recovery volume."

if [ -d "/Volumes/Recovery/PATCHED-SUR-OVERRIDE" ]; then
    rm -rf "/Volumes/Recovery/PATCHED-SUR-OVERRIDE"
fi

mkdir "/Volumes/Recovery/PATCHED-SUR-OVERRIDE"
cd "/Volumes/Recovery/PATCHED-SUR-OVERRIDE"

# MARK: Copy Kexts

echo -ne "\033[2K" ; printf "\r"
echo -n "Copying Kexts"

cp -a "$PSPATCHES/KextPatches" . || error "Failed to copy kexts."

# MARK: Copy Bin

echo -ne "\033[2K" ; printf "\r"
echo -n "Copying Bin"

cp -a "$PSPATCHES/ArchiveBin" . || error "Failed to copy bin scripts."

# MARK: Copy Installer Hax

echo -ne "\033[2K" ; printf "\r"
echo -n "Copying Compatibility Patch"

cp -a "$PSPATCHES/InstallerHax" . || error "Failed to copy compatibility patch."

# MARK: Copy Patcher App

echo -ne "\033[2K" ; printf "\r"
echo -n "Copying Patched Sur Over App"

cp -a "$PSPATCHES/InstallerPatches/PSRecovery.app" . || error "Failed to copy Patched Sur app."

# MARK: Launch Patcher

echo -ne "\033[2K" ; printf "\r"
echo "Completed! Launching Patched Sur..."

"/Volumes/Recovery/PATCHED-SUR-OVERRIDE/PSRecovery.app/Contents/MacOS/PSRecovery"

echo
