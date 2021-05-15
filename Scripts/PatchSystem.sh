#!bin/bash

#
#  PatchSystem.sh
#  Patched Sur
#
#  Created by Ben Sova on 5/15/21
#  Written based on patch-kexts.sh by BarryKN
#  But expanded for Patched Sur.
# 
#  Credit to some of the great people that
#  are working to make macOS run smoothly
#  on unsupported Macs
#

# MARK: Functions for Later

# Error out better for interfacing with the patcher.
error() {
    echo
    echo "$1" 1>&2
    exit 1
}

# Check for errors with the previous command. 
# Cleaner for non-inline uses.
errorCheck() {
    if [ $? -ne 0 ]
    then
        error "$1 failed. Check the logs for more info."
    fi
}

# In the current directory, check for kexts which have been renamed from
# *.kext to *.kext.original, then remove the new versions and rename the
# old versions back into place.
restoreOriginals() {
    if [ -n "`ls -1d *.original`" ]
    then
        for x in *.original
        do
            BASENAME=`echo $x|sed -e 's@.original@@'`
            echo 'Unpatching' $BASENAME
            rm -rf "$BASENAME"
            mv "$x" "$BASENAME"
        done
    fi
}

# Fix permissions on the specified kexts.
fixPerms() {
    chown -R 0:0 "$@"
    chmod -R 755 "$@"
}

# Rootify script
[ $UID = 0 ] || exec sudo "$0" "$@"

echo 'Welcome to PatchSystem.sh (for Patched Sur)!'
echo 'Note: This script is running in still in alpha stages.'
echo

# MARK: Check Environment and Patch Kexts Location

echo "Checking environment..."
LPATCHES="/Volumes/Image Volume"
if [[ -d "$LPATCHES" ]]; then
    echo "[INFO] We're in a recovery environment."
    RECOVERY="YES"
else
    echo "[INFO] We're booted into full macOS."
    RECOVERY="NO"
    if [[ -d "/Volumes/Install macOS Big Sur/KextPatches" ]]; then
        echo `[INFO] Using Install macOS Big Sur source.`
        LPATCHES="/Volumes/Install macOS Big Sur"
    elif [[ -d "/Volumes/Install macOS Big Sur Beta/KextPatches" ]]; then
        echo '[INFO] Using Install macOS Big Sur Beta source.'
        LPATCHES="/Volumes/Install macOS Big Sur Beta"
    elif [[ -d "/Volumes/Install macOS Beta/KextPatches" ]]; then
        echo '[INFO] Using Install macOS Beta source.'
        LPATCHES="/Volumes/Install macOS Beta"
    elif [[ -d "/usr/local/lib/Patched-Sur-Patches/KextPatches" ]]; then
        echo '[INFO] Using usr lib source.'
        LPATCHES="/usr/local/lib/Patched-Sur-Patches"
    fi
fi

echo "Confirming patch location..."

if [[ ! -d "$LPATCHES" ]]
then
    echo "After checking every normal place, the patches were not found"
    echo "Please plug in a patched macOS installer USB, or install the"
    echo "Patched Sur post-install app to your Mac."
    error "Error 3x1: The patches for PatchKexts.sh were not detected."
fi

echo "[INFO] Patch Location: $LPATCHES"

echo "Checking Arguments..."

while [[ $1 == *- ]]; do
    case $1 in
        -u)
            echo '[CONFIG] Unpatching system.'
            echo 'Note: This may not fully (or correctly) remove all patches.'
            PATCHMODE="UNINSTALL"
            ;;
        --wifi=mojaveHybrid)
            echo '[CONFIG] Will use Mojave-Hybrid WiFi patch.'
            WIFIPATCH="mojaveHybrid"
            ;;
        --wifi=none)
            echo '[CONFIG] Will not use any WiFi patches.'
            WIFIPATCH="none"
            ;;
        --wifi=hv12vOld)
            echo "[CONFIG] Will use highvoltage12v's (old) WiFi patch."
            WIFIPATCH="hv12vOld"
            ;;
        --wifi=hv12vNew)
            echo "[CONFIG] Will use highvoltage12v's (new) WiFi patch."
            WIFIPATCH="hv12vNew"
            ;;
        --legacyUSB)
            echo "[CONFIG] Will use Legacy USB patch."
            LEGACYUSB="YES"
            ;;
        --hd3000)
            echo "[CONFIG] Will use HD3000 (not acceleration) patch."
            HD3000="YES"
            ;;
        --hda)
            echo "[CONFIG] Will use HDA patch."
            HDA="YES"
            ;;
        --bcm5701)
            echo "[CONFIG] Will use BCM5701 patch."
            BCM5701="YES"
            ;;
        --gfTesla)
            echo "[CONFIG] Will use GFTesla patch."
            GFTESLA="YES"
            ;;
        --nvNet)
            echo "[CONFIG] Will use NVNet patch."
            NVNET="YES"
            ;;
        --telemetry)
            echo "[CONFIG] Will disable Telemetry."
            TELEMETRY="YES"
            ;;
        --openGL)
            echo "[CONFIG] Will install OpenGL acceleration."
            OPENGL="YES"
            ;;
        --bootPlist)
            echo "[CONFIG] Will patch com.apple.Boot.plist"
            BOOTPLIST="YES"
            ;;
    esac
    shift
done