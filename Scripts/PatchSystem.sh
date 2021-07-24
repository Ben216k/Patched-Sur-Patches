#!/bin/bash

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
    elif [[ -d "$(dirname $0)/KextPatches" ]]; then
        echo '[INFO] Using dirname source.'
        LPATCHES="$(dirname $0)"
    fi
fi

echo
echo "Confirming patch location..."

if [[ ! -d "$LPATCHES" ]]; then
    echo "After checking every normal place, the patches were not found"
    echo "Please plug in a patched macOS installer USB, or install the"
    echo "Patched Sur post-install app to your Mac."
    error "Error 3x1: The patches for PatchKexts.sh were not detected."
fi

if [[ "$1" == "--detect" ]] || [[ -z "$1" ]]; then
    echo "Set to detect patches, restarting PatchSystem with NeededPatches..."
    "$LPATCHES/NeededPatches.sh" --rerun "$LPATCHES" $2
    exit $?
elif echo "$1" | grep "/Volumes"; then
    echo "Set to detect patches, restarting PatchSystem with NeededPatches..."
    "$LPATCHES/NeededPatches.sh" --rerun "$LPATCHES" $1
    exit $?
fi

exit 0
exit 0
exit

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
        error "$1"
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

backupIfNeeded() {
    if [[ -d "$1".original ]]; then
        rm -rf "$1"
    else
        mv "$1" "$1".original
    fi
}

backupZIPIfNeeded() {
    if [[ ! -d "$1"-original.zip ]]; then
        zip -r "$1"-original.zip "$1"
    fi
    rm -rf "$1"
}

deleteIfNeeded() {
    if [[ -d "$1" ]]; then
        rm -rf "$1" || error "Failed to remove $1"
    else
        echo "$1 does not exist, so not deleting."
    fi
}

# Rootify script
[ $UID = 0 ] || exec sudo "$0" "$@"

echo 'Welcome to PatchSystem.sh (for Patched Sur)!'
echo 'Note: This script is still in alpha stages.'
echo

# MARK: Check Environment and Patch Kexts Location

echo "[INFO] Patch Location: $LPATCHES"

echo "Checking csr-active-config..."
CSRCONFIG=`nvram csr-active-config`
if [[ ! "$CSRCONFIG" == "csr-active-config	%7f%08%00%00" ]]; then
    if [[ $RECOVERY == "YES" ]]; then
        echo "csr-active-config not setup correctly, correcting..."
        csrutil disable || error "[ERROR] SIP is on, which prevents the patcher from patching the kexts. Boot into the purple EFI Boot on the installer USB to fix this. Patched Sur attempted to fix this, but failed."
        csrutil authenticated-root disable || error "[ERROR] SIP is on, which prevents the patcher from patching the kexts. Boot into the purple EFI Boot on the installer USB to fix this. Patched Sur attempted to fix this, but failed."
    else
        error "[ERROR] SIP is on, which prevents the patcher from patching the kexts. Boot into the purple EFI Boot on the installer USB to fix this."
    fi
fi

echo
echo "Checking Arguments..."

while [[ $1 == -* ]]; do
    case $1 in
        -u)
            echo '[CONFIG] Unpatching system.'
            echo 'Note: This may not fully (or correctly) remove all patches.'
            error 'Uninstalling patches is not supported yet.'
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
        --agc)
            echo "[CONFIG] Will use AGC patch."
            AGC="YES"
            ;;
        --mccs)
            echo "[CONFIG] Will use MCCS patch."
            MCCS="YES"
            ;;
        --smb=bundle)
            echo "[CONFIG] Will use SMB Bundle."
            SMB="BUNDLE"
            ;;
        --smb=kext)
            echo "[CONFIG] Will use SMB Kext."
            SMB="KEXT"
            ;;
        --backlight)
            echo "[CONFIG] Will use Backlight patch."
            BACKLIGHT="YES"
            ;;
        --backlightFixup)
            echo "[CONFIG] Will use Backlight Fix-Up patch."
            BACKLIGHTFIXUP="YES"
            ;;
        --vit9696)
            echo "[CONFIG] Will use WhateverGreen and Lilu patches."
            VIT9696="YES"
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
        --noRebuild)
            echo "Will patch without rebuilding the kernel collection."
            NOREBUILD="YES"
            ;;
        *)
            echo "Unknown option, ignoring. $1"
            ;;
    esac
    shift
done

echo
echo 'Checking patch to volume...'

if [[ $RECOVERY == "YES" ]] && [[ ! -d "/Volumes/$1" ]]; then
    echo "[CONFIG] Looking for /Volumes/$1"
    echo 'Make sure to run the script with path/to/PatchSystem.sh "NAME-OF-BIG-SUR-VOLUME"'
    error "No volume was specificed on the command line or the volume selected is invalid."
elif [[ $RECOVERY == "NO" ]]; then
    echo "[CONFIG] Patching to /System/Volumes/Update/mnt1 (booted system snapshot)"
    VOLUME="/"
else
    echo "[CONFIG] Patching to /Volumes/$1"
fi

if [[ ! -d "$VOLUME" ]]
then
    echo 'Make sure to run the script with path/to/PatchSystem.sh "NAME-OF-BIG-SUR-VOLUME"'
    error "No volume was specificed on the command line or the volume selected is invalid."
fi

echo
echo "Verifying volume..."

if [[ ! -d "$VOLUME/System/Library/Extensions" ]]; then
    error "The selected volume is not a macOS system volume. This volume might be a data volume or maybe another OS."
fi

SVPL="$VOLUME"/System/Library/CoreServices/SystemVersion.plist
SVPL_VER=`fgrep '<string>10' "$SVPL" | sed -e 's@^.*<string>10@10@' -e 's@</string>@@' | uniq -d`
SVPL_BUILD=`grep '<string>[0-9][0-9][A-Z]' "$SVPL" | sed -e 's@^.*<string>@@' -e 's@</string>@@'`

if echo $SVPL_BUILD | grep -q '^20'
then
    echo -n "[INFO] Volume has Big Sur build" $SVPL_BUILD
else
    if [ -z "$SVPL_VER" ]
    then
        error "Unknown macOS version on volume."
    else
        error "macOS" "$SVPL_VER" "build" "$SVPL_BUILD" "detected. This patcher only works on Big Sur."
    fi
    exit 1
fi

# MARK: Preparing for Patching

echo

echo 'Unmounting underlying volume just incase.'
umount "/System/Volumes/Update/mnt1" || diskutil unmount force "/System/Volumes/Update/mnt1"

echo "Remounting Volume..."

if [[ "$VOLUME" = "/" ]]; then
    DEVICE=`df "$VOLUME" | tail -1 | sed -e 's@ .*@@'`
    POPSLICE=`echo $DEVICE | sed -E 's@s[0-9]+$@@'`
    VOLUME="/System/Volumes/Update/mnt1"

    echo "[INFO] Remounting snapshot with IDs $DEVICE and $POPSLICE"

    mount -o nobrowse -t apfs "$POPSLICE" "$VOLUME"
    errorCheck "Failed to remount snapshot as read/write. This is probably because your Mac is optimizing. Wait 5 minutes, reboot, wait 5 minutes again then try again."
else
    mount -uw "$VOLUME"
    errorCheck "Failed to remount volume as read/write."
fi

if [[ ! "$PATCHMODE" == "UNINSTALL" ]]; then
    # MARK: Backing Up System

    echo "Checking for backup..."
    pushd "$VOLUME/System/Library/KernelCollections" > /dev/null
    BACKUP_FILE_BASE="KernelCollections-$SVPL_BUILD.tar"
    BACKUP_FILE="$BACKUP_FILE_BASE".lz4
    
    if [[ -e "$BACKUP_FILE" ]]; then
        echo "Backup already there, so not overwriting."
    else
        echo "Backup not found. Performing backup now. This may take a few minutes."
        echo "Backing up original KernelCollections to:"
        echo `pwd`/"$BACKUP_FILE"
        tar cv *.kc | "$VOLUME/usr/bin/compression_tool" -encode -a lz4 > "$BACKUP_FILE"

        if [ $? -ne 0 ]
        then
            echo "tar or compression_tool failed. See above output for more information."

            echo "Attempting to remove incomplete backup..."
            rm -f "$BACKUP_FILE" || error "Failed to backup kernel collection and failed to delete the incomplete backup."
            
            error "Failed to backup kernel collection. Check the logs for more info."
        fi
    fi

    echo "[INFO] Saved Backup! PatchKexts.sh can restore backups until PatchSystem.sh adds support."
    
    popd > /dev/null

    # MARK: Patching System

    pushd "$VOLUME/System/Library/Extensions" > /dev/null

    echo "Beginning Kext Patching..."

    if [[ "$WIFIPATCH" == "mojaveHybrid" ]]; then
        echo "Patching IO80211Family.kext with MojaveHybrid..."
        backupIfNeeded "IO80211Family.kext"
        unzip -q "$LPATCHES/KextPatches/IO80211Family-18G6032.kext.zip"
        errorCheck "Failed to patch IO80211Family.kext with mojaveHybrid (part 1)."
        pushd IO80211Family.kext/Contents/Plugins > /dev/null
        unzip -q "$LPATCHES/KextPatches/AirPortAtheros40-17G14033+pciid.kext.zip"
        errorCheck "Failed to patch IO80211Family.kext with mojaveHybrid (part 2)."
        popd > /dev/null
    elif [[ "$WIFIPATCH" == "hv12vOld" ]]; then
        echo "Patching IO80211Family.kext with hv12vOld..."
        unzip -q "$LPATCHES/KextPatches/IO80211Family-highvoltage12v-old.kext.zip"
        errorCheck "Failed to patch IO80211Family.kext with hv12vOld."
    elif [[ "$WIFIPATCH" == "hv12vNew" ]]; then
        echo "Patching IO80211Family.kext with hv12vNew..."
        unzip -q "$LPATCHES/KextPatches/IO80211Family-highvoltage12v-new.kext.zip"
        errorCheck "Failed to patch IO80211Family.kext with hv12vNew."
    fi
    if [[ ! -z "$WIFIPATCH" ]] && [[ ! "$WIFIPATCH" == "none" ]]; then
        # Clean up after WiFi patches
        rm -rf __MACOSX
        echo "Correcting permissions for IO80211Family.kext..."
        fixPerms IO80211Family.kext
        errorCheck "Failed to correct permissioms for IO80211Family.kext."
    fi

    if [[ "$LEGACYUSB" == "YES" ]]; then
        echo 'Patching LegacyUSBInjector.kext...'
        rm -rf LegacyUSBInjector.kext
        unzip -q "$LPATCHES/KextPatches/LegacyUSBInjector.kext.zip"
        errorCheck "Failed to patch LegacyUSBInjector.kext."
        echo 'Correcting permissions for LegacyUSBInjector.kext...'
        fixPerms LegacyUSBInjector.kext
        errorCheck "Failed to correct permissioms for LegacyUSBInjector.kext."
        # parameter for kmutil later on
        BUNDLEPATH="--bundle-path /System/Library/Extensions/LegacyUSBInjector.kext"
    fi

#    if [[ "$HD3000" == "YES" ]]; then
#        echo 'Patching AppleIntelHD3000Graphics* kexts/plugins/bundles.'
#        rm -rf AppleIntelHD3000* AppleIntelSNB*
#        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000Graphics.kext-17G14033.zip"
#        errorCheck "Failed to patch AppleIntelHD3000Graphics.kext."
#        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000GraphicsGA.plugin-17G14033.zip"
#        errorCheck "Failed to patch AppleIntelHD3000GraphicsGA.plugin."
#        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000GraphicsGLDriver.bundle-17G14033.zip"
#        errorCheck "Failed to patch AppleIntelHD3000GraphicsGLDriver.bundle."
#
#        echo 'Patching AppleIntelSNBGraphicsFB kext.'
#        unzip -q "$LPATCHES/KextPatches/AppleIntelSNBGraphicsFB.kext-17G14033.zip"
#        errorCheck "Failed to patch AppleIntelSNBGraphicsFB.kext."
#
#        echo 'Correcting permissions for AppleIntelHD3000Graphics* and AppleIntelSNBGraphicsFB.kext...'
#        fixPerms AppleIntelHD3000* AppleIntelSNB*
#        errorCheck "Failed to correct permissioms for AppleIntelHD3000Graphics* and/or AppleIntelSNBGraphicsFB.kext."
#    fi

    if [[ "$HDA" == "YES" ]]; then
        echo "Patching AppleHDA.kext..."
        backupIfNeeded "AppleHDA.kext"
        unzip -q "$LPATCHES/KextPatches/AppleHDA-17G14033.kext.zip"
        errorCheck "Failed to patch AppleHDA.kext."
        echo 'Correcting permissions for AppleHDA.kext...'
        fixPerms AppleHDA.kext
        errorCheck "Failed to correct permissioms for AppleHDA.kext."
    fi

    if [[ "$BCM5701" == "YES" ]]; then
        echo 'Patching AppleBCM5701Ethernet.kext...'
        pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
        backupIfNeeded "AppleBCM5701Ethernet.kext"
        unzip -q "$LPATCHES/KextPatches/AppleBCM5701Ethernet-19H2.kext.zip"
        errorCheck "Failed to patch AppleBCM5701Ethernet.kext."
        echo 'Correcting permissions for AppleBCM5701Ethernet.kexts...'
        fixPerms AppleBCM5701Ethernet.kext
        errorCheck "Failed to correct permissioms for AppleBCM5701Ethernet.kext."
        popd > /dev/null
    fi

    if [[ "$GFTESLA" == "YES" ]]; then
        echo 'Patching GeForceTesla.kexts...'
        rm -rf *Tesla*
        unzip -q "$LPATCHES/KextPatches/GeForceTesla-17G14033.zip"
        errorCheck "Failed to patch GeForceTesla.kext."
        unzip -q "$LPATCHES/KextPatches/NVDANV50HalTesla-17G14033.kext.zip"
        errorCheck "Failed to patch NVDANV50HalTesla.kext."
        unzip -q "$LPATCHES/KextPatches/NVDAResmanTesla-ASentientBot.kext.zip"
        errorCheck "Failed to patch NVDAResmanTesla.kext."
        rm -rf __MACOSX
        echo 'Correcting permissions for GeForceTesla.kexts...'
        fixPerms *Tesla*
        errorCheck "Failed to correct permissions for GeForceTesla.kexts."
    fi

    if [[ "$NVNET" == "YES" ]]; then
        echo 'Patching nvenet.kext...'
        pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
        rm -rf nvenet.kext
        unzip -q "$LPATCHES/KextPatches/nvenet-17G14033.kext.zip"
        errorCheck "Failed to patch nvenet.kext."
        echo 'Fixing permissions for nvenet.kext...'
        fixPerms nvenet.kext
        errorCheck "Failed to correct permissions for nvenet.kexts."
        popd > /dev/null
    fi

    if [[ "$AGC" == "YES" ]]; then
        echo 'Patching AppleGraphicsControl.kext...'
        if [ -f AppleGraphicsControl.kext.zip ]
        then
           rm -rf AppleGraphicsControl.kext
           unzip -q AppleGraphicsControl.kext.zip
           rm -rf AppleGraphicsControl.kext.zip
        else
           zip -q -r -X AppleGraphicsControl.kext.zip AppleGraphicsControl.kext
        fi
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-942B59F58194171B string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-942B5BF58194151B string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2268DAE string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2238AC8 string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2238BAE string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        echo 'Correcting permissions for AppleGraphicsControl.kext'
        fixPerms AppleGraphicsControl.kext
        errorCheck 'Failed to correct permissions for AppleGraphicsControl.kext'
    fi

    if [[ "$MCCS" == "YES" ]]; then
        echo 'Patching AppleMCCSControl.kext...'
        backupIfNeeded "AppleMCCSControl.kext"
        unzip -q "$LPATCHES/KextPatches/AppleMCCSControl.kext.zip"
        errorCheck 'Failed to patch AppleMCCSControl.kext'
        echo 'Correcting permissions for AppleMCCSControl.kext'
        fixPerms AppleMCCSControl.kext
        errorCheck 'Failed to correct permissions for AppleMCCSControl.kext'
    fi

    if [[ ! -z "$SMB" ]]; then
        echo 'Patching AppleIntelHD3000GraphicsVADriver.bundle and AppleIntelSNBVA.bundle.'
        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000GraphicsVADriver.bundle-17G14033.zip"
        errorCheck 'Failed to patch AppleIntelHD3000GraphicsVADriver.bundle'
        unzip -q "$LPATCHES/KextPatches/AppleIntelSNBVA.bundle-17G14033.zip"
        errorCheck 'Failed to patch AppleIntelSNBVA.bundle'
        echo 'Correcting permissions for AppleIntelHD3000* and AppleIntelSNB*...'
        fixPerms AppleIntelHD3000* AppleIntelSNB*
        errorCheck 'Failed to fix permissions for AppleIntelHD3000* and AppleIntelSNB*.'
    fi
    if [[ "$SMB" == "KEXT" ]]; then
        echo 'Patching AppleIntelSNBGraphicsFB.kext...'
        unzip -q "$LPATCHES/KextPatches/AppleIntelSNBGraphicsFB-AMD.kext.zip"
        errorCheck 'Failed to patch AppleIntelSNBGraphicsFB.kext'
        mv AppleIntelSNBGraphicsFB-AMD.kext AppleIntelSNBGraphicsFB.kext
        errorCheck 'Failed to rename AppleIntelSNBGraphicsFB.kext'
        echo 'Correcting permissions for AppleIntelSNBGraphicsFB.kext...'
        fixPerms 'AppleIntelSNBGraphicsFB.kext'
        errorCheck 'Failed to correct permissions for AppleIntelSNBGraphicsFB.kext.'
    fi

    if [[ $BACKLIGHT == "YES" ]]; then
        echo 'Patching AppleBacklight.kext...'
        backupIfNeeded 'AppleBacklight.kext'
        unzip -q "$LPATCHES/KextPatches/AppleBacklight.kext.zip"
        errorCheck 'Failed to patch AppleBacklight.kext'
        echo 'Correcting permissions for AppleBacklight.kext...'
        fixPerms 'AppleBacklight.kext'
        errorCheck 'Failed to correct permissions AppleBacklight.kext'
    fi

    if [[ "$BACKLIGHTFIXUP" == "YES" ]]; then
        echo 'Patching AppleBacklightFixup.kext'
        unzip -q "$LPATCHES/KextPatches/AppleBacklightFixup.kext.zip"
        errorCheck 'Failed to patch AppleBacklightFixup.kext'
        echo 'Correcting permissions for AppleBacklightFixup.kext...'
        fixPerms AppleBacklightFixup.kext
        errorCheck 'Failed to correct permissions for AppleBacklightFixup.kext'
    fi

    if [[ "$VIT9696" == "YES" ]]; then
        echo 'Patching WhateverGreen.kext and Lilu.kext...'
        rm -rf WhateverGreen.kext
        unzip -q "$LPATCHES/KextPatches/WhateverGreen.kext.zip"
        errorCheck 'Failed to patch WhateverGreen.kext'
        rm -rf Lilu.kext
        unzip -q "$LPATCHES/KextPatches/Lilu.kext.zip"
        echo 'Correcting permissions for WhateverGreen.kext and Lilu.kext...'
        fixPerms WhateverGreen* Lilu*
        errorCheck 'Failed to correct permissions for WhateverGreen.kext and Lilu.kext'
    fi

    popd > /dev/null

    if [[ "$TELEMETRY" == "YES" ]]; then
        echo 'Deactivating com.apple.telemetry.plugin...'
        pushd "$VOLUME/System/Library/UserEventPlugins" > /dev/null
        mv -f com.apple.telemetry.plugin com.apple.telemetry.plugin.disabled
        errorCheck 'Failed to deactivate com.apple.telemetry.plugin'
        popd > /dev/null
    fi

    if [[ "$BOOTPLIST" == "YES" ]]; then
        if [[ "$RECOVERY" == "YES" ]]; then
            echo "Cannot patch boot plist from recovery due to limitations."
        else
            echo 'Patching com.apple.Boot.plist (System Volume)...'
            pushd "$VOLUME/Library/Preferences/SystemConfiguration" > /dev/null
            cp "$LPATCHES/SystemPatches/com.apple.Boot.plist" com.apple.Boot.plist || echo 'Failed to patch com.apple.Boot.plist, however this is not fatal, so the patcher will not exit.'
            fixPerms com.apple.Boot.plist || echo 'Failed to correct permissions for com.apple.Boot.plist, however this is not fatal, so the patcher will not exit.'
            popd > /dev/null
            pushd "$VOLUME/System/Library/CoreServices" > /dev/null
            echo 'Patching PlatformSupport.plist (System Volume)...'
            cp "$LPATCHES/SystemPatches/PlatformSupport.plist" PlatformSupport.plist || echo 'Failed to patch PlatformSupport.plist, however this is not fatal, so the patcher will not exit.'
            fixPerms "PlatformSupport.plist" || echo 'Failed to correct permissions PlatformSupport.plist, however this is not fatal, so the patcher will not exit.'
            popd > /dev/null

            echo 'Making sure the Premount volume is mounted for Boot.plist patches...'
            PREMOUNTID=`diskutil list | grep Preboot | head -n 1 | cut -c 71-`
            diskutil mount "$PREMOUNTID"
            if [[ "$VOLUME" == "/System/Volumes/Update/mnt1" ]]; then
                APFSID=`diskutil info / | grep "APFS Volume Group" | cut -c 31-`
            else
                APFSID=`diskutil info $VOLUME | grep "APFS Volume Group" | cut -c 31-`
            fi

            pushd "/System/Volumes/Preboot/$APFSID/Library/Preferences/SystemConfiguration" > /dev/null
            echo 'Patching com.apple.Boot.plist (Preboot Volume)...'
            cp -X "$LPATCHES/SystemPatches/com.apple.Boot.plist" com.apple.Boot.plist || echo 'Failed to patch com.apple.Boot.plist, however this is not fatal, so the patcher will not exit.'
            fixPerms com.apple.Boot.plist || echo 'Failed to correct permissions for com.apple.Boot.plist, however this is not fatal, so the patcher will not exit.'
            popd > /dev/null
            pushd "/System/Volumes/Preboot/$APFSID/Library/Preferences/SystemConfiguration" > /dev/null
            echo 'Patching PlatformSupport.plist (Preboot Volume)...'
            cp -X "$LPATCHES/SystemPatches/PlatformSupport.plist" PlatformSupport.plist || echo 'Failed to patch PlatformSupport.plist, however this is not fatal, so the patcher will not exit.'
            fixPerms "PlatformSupport.plist" || echo 'Failed to correct permissions PlatformSupport.plist, however this is not fatal, so the patcher will not exit.'
            popd > /dev/null

            echo 'Enabling the patcher daemon since this will be needed for bugging the user after an NVRAM reset.'
            pushd "/Library/LaunchAgents" > /dev/null
            launchctl unload /Library/LaunchAgents/u-bensova.Patched-Sur.Daemon.plist
            rm -rf u-bensova.Patched-Sur.Daemon.plist
            cp "$LPATCHES/SystemPatches/u-bensova.Patched-Sur.Daemon.plist" u-bensova.Patched-Sur.Daemon.plist || echo 'Failed to add patcher daemon, not important, not exiting.'
            launchctl load -w /Library/LaunchAgents/u-bensova.Patched-Sur.Daemon.plist || echo 'Failed to enable patcher daemon, not important, not exiting.'
            launchctl enable system/u-bensova.Patched-Sur.Daemon
            popd > /dev/null
        fi
    fi

    if [[ "$OPENGL" == "YES" ]]; then
        echo 'Starting OpenGL Patching... (Thanks ASentientBot, OCLP Team, dosdude1 and others)'
        pushd "$VOLUME/System/Library/Frameworks" > /dev/null

        ISAMD=`chroot "$VOLUME" ioreg -l | grep Baffin`
        if [[ "$ISAMD" ]]; then
            echo 'Removing AMD bad kexts...'
            deleteIfNeeded "AMDRadeonX4000.kext"
            deleteIfNeeded "AMDRadeonX4000HWServices.kext"
            deleteIfNeeded "AMDRadeonX5000.kext"
            deleteIfNeeded "AMDRadeonX5000HWServices.kext"
            deleteIfNeeded "AMDRadeonX6000.kext"
            deleteIfNeeded "AMDRadeonX6000Framebuffer.kext"
            deleteIfNeeded "AMDRadeonX6000HWServices.kext"
            deleteIfNeeded "AMD7000Controller.kext"
            deleteIfNeeded "AMD8000Controller.kext"
            deleteIfNeeded "AMD9000Controller.kext"
            deleteIfNeeded "AMD9500Controller.kext"
            deleteIfNeeded "AMD10000Controller.kext"
            deleteIfNeeded "AppleIntelBDWGraphics.kext"
            deleteIfNeeded "AppleIntelBDWGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelCFLGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelHD4000Graphics.kext"
            deleteIfNeeded "AppleIntelHD5000Graphics.kext"
            deleteIfNeeded "AppleIntelICLGraphics.kext"
            deleteIfNeeded "AppleIntelICLLPGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelKBLGraphics.kext"
            deleteIfNeeded "AppleIntelKBLGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelSKLGraphics.kext"
            deleteIfNeeded "AppleIntelSKLGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelFramebufferAzul.kext"
            deleteIfNeeded "AppleIntelFramebufferCapri.kext"
            deleteIfNeeded "AppleParavirtGPU.kext"
            deleteIfNeeded "GeForce.kext"
            deleteIfNeeded "IOGPUFamily.kext"
        else
            echo 'Removing Nvidia/Intel bad kexts...'
            deleteIfNeeded "AMDRadeonX4000.kext"
            deleteIfNeeded "AMDRadeonX4000HWServices.kext"
            deleteIfNeeded "AMDRadeonX5000.kext"
            deleteIfNeeded "AMDRadeonX5000HWServices.kext"
            deleteIfNeeded "AMDRadeonX6000.kext"
            deleteIfNeeded "AMDRadeonX6000Framebuffer.kext"
            deleteIfNeeded "AMDRadeonX6000HWServices.kext"
            deleteIfNeeded "AppleIntelBDWGraphics.kext"
            deleteIfNeeded "AppleIntelBDWGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelCFLGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelHD4000Graphics.kext"
            deleteIfNeeded "AppleIntelHD5000Graphics.kext"
            deleteIfNeeded "AppleIntelICLGraphics.kext"
            deleteIfNeeded "AppleIntelICLLPGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelKBLGraphics.kext"
            deleteIfNeeded "AppleIntelKBLGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelSKLGraphics.kext"
            deleteIfNeeded "AppleIntelSKLGraphicsFramebuffer.kext"
            deleteIfNeeded "AppleIntelFramebufferAzul.kext"
            deleteIfNeeded "AppleIntelFramebufferCapri.kext"
            deleteIfNeeded "AppleParavirtGPU.kext"
            deleteIfNeeded "GeForce.kext"
            deleteIfNeeded "IOAcceleratorFamily2.kext"
            deleteIfNeeded "IOGPUFamily.kext"
        fi

        echo 'Checking deleted kexts...'
        [[ ! -d "AppleIntelHD4000Graphics.kext" ]] || error "Removing bad kexts failed but claimed to work."


        echo 'Patching OpenGL.framework...'
        backupZIPIfNeeded "OpenGL.framework"
        unzip -q "$LPATCHES/SystemPatches/OpenGL.framework.zip"
        errorCheck "Failed to patch OpenGL.framework."
        fixPerms "OpenGL.framework"
        errorCheck "Failed to fix permissions for OpenGL.framework"

        echo 'Patching IOSurface.framework...'
        backupZIPIfNeeded "IOSurface.framework"
        unzip -q "$LPATCHES/SystemPatches/IOSurface.framework.zip"
        errorCheck "Failed to patch IOSurface.framework."
        fixPerms "IOSurface.framework"
        errorCheck "Failed to fix permissions for IOSurface.framework"

        echo 'Patching CoreDisplay.framework...'
        backupZIPIfNeeded "CoreDisplay.framework"
        unzip -q "$LPATCHES/SystemPatches/CoreDisplay.framework.zip"
        errorCheck "Failed to patch CoreDisplay.framework."
        fixPerms "CoreDisplay.framework"
        errorCheck "Failed to fix permissions for CoreDisplay.framework"

        popd > /dev/null

        pushd "$VOLUME/System/Library/PrivateFrameworks" > /dev/null

        echo 'Patching SkyLight.framework...'
        backupZIPIfNeeded "SkyLight.framework"
        unzip -q "$LPATCHES/SystemPatches/SkyLight.framework.zip"
        errorCheck "Failed to patch SkyLight.framework."
        fixPerms "SkyLight.framework"
        errorCheck "Failed to fix permissions for SkyLight.framework"

        echo 'Patching GPUSupport.framework...'
        backupZIPIfNeeded "GPUSupport.framework"
        unzip -q "$LPATCHES/SystemPatches/GPUSupport.framework.zip"
        errorCheck "Failed to patch GPUSupport.framework."
        fixPerms "GPUSupport.framework"
        errorCheck "Failed to fix permissions for GPUSupport.framework"

        popd > /dev/null
        
        pushd "$VOLUME/System/Library/Extensions" > /dev/null

        echo 'Patching IOSurface.kext...'
        backupIfNeeded "IOSurface.kext"
        rm -rf "__MACOSX"
        unzip -q "$LPATCHES/KextPatches/IOSurface.kext.zip"
        errorCheck "Failed to patch IOSurface.kext."
        fixPerms "IOSurface.kext"
        errorCheck "Failed to fix permissions for IOSurface.kext"

        echo 'Patching IOAcceleratorFamily2.kext...'
        backupIfNeeded "IOAcceleratorFamily2.kext"
        rm -rf "__MACOSX"
        unzip -q "$LPATCHES/KextPatches/IOAcceleratorFamily2.kext.zip"
        errorCheck "Failed to patch IOAcceleratorFamily2.kext."
        fixPerms "IOAcceleratorFamily2.kext"
        errorCheck "Failed to fix permissions for IOAcceleratorFamily2.kext"

        echo 'Patching IOGraphicsFamily.kext...'
        backupIfNeeded "IOGraphicsFamily.kext"
        rm -rf "__MACOSX"
        unzip -q "$LPATCHES/KextPatches/IOGraphicsFamily.kext.zip"
        errorCheck "Failed to patch IOGraphicsFamily.kext."
        fixPerms "IOGraphicsFamily.kext"
        errorCheck "Failed to fix permissions for IOGraphicsFamily.kext"

        echo 'Patching IONDRVSupport.kext...'
        backupIfNeeded "IONDRVSupport.kext"
        rm -rf "__MACOSX"
        unzip -q "$LPATCHES/KextPatches/IONDRVSupport.kext.zip"
        errorCheck "Failed to patch IONDRVSupport.kext."
        fixPerms "IONDRVSupport.kext"
        errorCheck "Failed to fix permissions for IONDRVSupport.kext"

        if [[ "$HD3000" == "YES" ]]; then
            echo 'Patching AppleIntelHD3000Graphics.kext...'
            deleteIfNeeded "AppleIntelHD3000Graphics.kext"
            unzip -q "$LPATCHES/SystemPatches/HD3000/AppleIntelHD3000Graphics.kext.zip"
            errorCheck "Failed to patch AppleIntelHD3000Graphics.kext."
            fixPerms "AppleIntelHD3000Graphics.kext"
            errorCheck "Failed to fix permissions for AppleIntelHD3000Graphics.kext"

            echo 'Patching AppleIntelHD3000GraphicsGA.plugin...'
            deleteIfNeeded "AppleIntelHD3000GraphicsGA.plugin"
            unzip -q "$LPATCHES/SystemPatches/HD3000/AppleIntelHD3000GraphicsGA.plugin.zip"
            errorCheck "Failed to patch AppleIntelHD3000GraphicsGA.plugin."
            fixPerms "AppleIntelHD3000GraphicsGA.plugin"
            errorCheck "Failed to fix permissions for AppleIntelHD3000GraphicsGA.plugin"

            echo 'Patching AppleIntelHD3000GraphicsGLDriver.bundle...'
            deleteIfNeeded "AppleIntelHD3000GraphicsGLDriver.bundle"
            unzip -q "$LPATCHES/SystemPatches/HD3000/AppleIntelHD3000GraphicsGLDriver.bundle.zip"
            errorCheck "Failed to patch AppleIntelHD3000GraphicsGLDriver.bundle."
            fixPerms "AppleIntelHD3000GraphicsGLDriver.bundle"
            errorCheck "Failed to fix permissions for AppleIntelHD3000GraphicsGLDriver.bundle"

            echo 'Patching AppleIntelHD3000GraphicsVADriver.bundle...'
            deleteIfNeeded "AppleIntelHD3000GraphicsVADriver.bundle"
            unzip -q "$LPATCHES/SystemPatches/HD3000/AppleIntelHD3000GraphicsVADriver.bundle.zip"
            errorCheck "Failed to patch AppleIntelHD3000GraphicsVADriver.bundle."
            fixPerms "AppleIntelHD3000GraphicsVADriver.bundle"
            errorCheck "Failed to fix permissions for AppleIntelHD3000GraphicsVADriver.bundle"

            echo 'Patching AppleIntelSNBGraphicsFB.kext...'
            deleteIfNeeded "AppleIntelSNBGraphicsFB.kext"
            unzip -q "$LPATCHES/SystemPatches/HD3000/AppleIntelSNBGraphicsFB.kext.zip"
            errorCheck "Failed to patch AppleIntelSNBGraphicsFB.kext."
            fixPerms "AppleIntelSNBGraphicsFB.kext"
            errorCheck "Failed to fix permissions for AppleIntelSNBGraphicsFB.kext"

            echo 'Patching AppleIntelSNBVA.bundle...'
            deleteIfNeeded "AppleIntelSNBVA.bundle.kext"
            unzip -q "$LPATCHES/SystemPatches/HD3000/AppleIntelSNBVA.bundle.zip"
            errorCheck "Failed to patch AppleIntelSNBVA.bundle."
            fixPerms "AppleIntelSNBVA.bundle"
            errorCheck "Failed to fix permissions for AppleIntelSNBVA.bundle"
        fi

        popd > /dev/null
    fi

    # MARK: Rebuild Kernel Collection 

    if [[ ! $NOREBUILD == "YES" ]]; then
        echo 'Rebuilding boot collection...'
        chroot "$VOLUME" kmutil create -n boot \
            --kernel /System/Library/Kernels/kernel \
            --variant-suffix release --volume-root / $BUNDLEPATH \
            --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
        errorCheck 'Failed to rebuild kernel boot collection.'

        echo 'Rebuilding system collection...'
        chroot "$VOLUME" kmutil create -n sys \
            --kernel /System/Library/Kernels/kernel \
            --variant-suffix release --volume-root / \
            --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
            --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
        errorCheck 'Failed to rebuild kernel system collection.'

        echo "Finished rebuilding!"
    fi
else
    # MARK: Unpatch Kexts

    pushd "$VOLUME/System/Library/KernelCollections" > /dev/null

    BACKUP_FILE_BASE="KernelCollections-$SVPL_BUILD.tar"
    BACKUP_FILE="$BACKUP_FILE_BASE".lz4

    if [ ! -e "$BACKUP_FILE" ]
    then
        error "Failed to find kernel collection backup at $(pwd)/$BACKUP_FILE"
    fi
    
    echo "Restoring KernelCollections backup from: $(pwd)/$BACKUP_FILE"
    rm -rf *.kc
    "$VOLUME/usr/bin/compression_tool" -decode < "$BACKUP_FILE" | tar xpv
    errorCheck 'Failed to unpatch the KernelCollection'
    rm -rf "$BACKUP_FILE"
    
    popd > /dev/null
    
    echo "Unpatching kexts"
    pushd "$VOLUME/System/Library/Extensions" > /dev/null
    restoreOriginals

    pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
    restoreOriginals
    popd > /dev/null
    
    if [[ -f AppleGraphicsControl.kext.zip ]]; then
        echo 'Restoring patched AppleGraphicsControl extension'
        rm -rf AppleGraphicsControl.kext
        unzip -q AppleGraphicsControl.kext.zip
        rm AppleGraphicsControl.kext.zip
    fi
    echo 'Unpatching IntelHD3000.kexts'
    rm -rf AppleIntelHD3000* AppleIntelSNB*
    echo 'Unpatching LegacyUSBInjector.kext'
    rm -rf LegacyUSBInjector.kext
    echo 'Unpatching nvenet.kext'
    rm -rf IONetworkingFamily.kext/Contents/Plugins/nvenet.kext
    echo 'Unpatching Tesla kext...'
    rm -rf *Tesla*
    echo 'Removing @vit9696 Whatevergreen.kext and Lilu.kext'
    rm -rf Whatevergreen.kext Lilu.kext
    echo 'Removing iMac AppleBacklightFixup'
    rm -rf AppleBacklightFixup.kext
    echo 'Reactivating telemetry plugin'
    echo 'WARNING: OpenGL will not be unpatched.'
    mv -f "$VOLUME/System/Library/UserEventPlugins/com.apple.telemetry.plugin.disabled" "$VOLUME/System/Library/UserEventPlugins/com.apple.telemetry.plugin"
    
    popd > /dev/null
fi

# MARK: Finish Up
if [[ ! $NOREBUILD == "YES" ]]; then
    echo 'Running kcditto...'
    "$VOLUME/usr/sbin/kcditto"
    errorCheck 'kcditto failed.'
fi

echo 'Reblessing volume...'
bless --folder "$VOLUME"/System/Library/CoreServices --bootefi --create-snapshot --setBoot
errorCheck bless


if [[ "$VOLUME" = "/System/Volumes/Update/mnt1" ]]; then
    echo "Unmounting underlying volume..."
    umount "$VOLUME" || diskutil unmount "$VOLUME"
fi

echo 'Patched System Successfully!'
echo 'Reboot to finish up and enjoy Big Sur!'
