#!/bin/bash

#  PatchUSB.sh
#  Patched Sur
#
#  Originally created by BarryKN as patch-kexts.sh.
#  Modified by Ben Sova for Patched Sur on 4/1/21.
#
#  Credit to some of the great people that
#  are working to make macOS run smoothly
#  on unsupported Macs
#


# MARK: Functions for Later

# Error out better for the patcher.
error() {
    echo
    echo "$1" 1>&2
    exit 1
}

# Check for errors, and handle any errors appropriately, after a command
# invocation. Takes the name of the command as its only parameter.
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

# MARK: Fun Stuff

# Rootify script
[ $UID = 0 ] || exec sudo "$0" "$@"

echo 'Welcome to PatchKexts.sh (for Patched Sur)!'
echo

# MARK: Check Environment and Patch Kexts Location

echo "Checking environment..."
LPATCHES="/Volumes/Image Volume"
if [[ -d "$LPATCHES" ]]; then
    echo "We're in a recovery environment."
    RECOVERY="YES"
else
    echo "We're booted into full macOS."
    RECOVERY="NO"
    if [[ -d "/Volumes/Install macOS Big Sur" ]]; then
        LPATCHES="/Volumes/Install macOS Big Sur"
    elif [[ -d "/Volumes/Install macOS Big Sur Beta" ]]; then
        LPATCHES="/Volumes/Install macOS Big Sur Beta"
    elif [[ -d "/Volumes/Install macOS Beta" ]]; then
        LPATCHES="/Volumes/Install macOS Beta"
    elif [[ -d "/usr/local/lib/Patched-Sur-Patches" ]]; then
        LPATCHES="/usr/local/lib/Patched-Sur-Patches"
    fi
fi

echo "Confirming patch location..."

# The Patch Location should be correct, but let's make sure.

if [ ! -d "$LPATCHES" ]
then
    echo "After checking every normal place, the patches were not found"
    echo "Please plug in a patched macOS installer USB, or install the"
    echo "Patched Sur post-install app to your Mac."
    error "Error 3x1: The patches for PatchKexts.sh were not detected."
fi

echo "Patch Location: $LPATCHES"

# MARK: Check CLI Options

while [[ $1 = -* ]]
do
    case $1 in
    --create-snapshot)
        SNAPSHOT=YES
        ;;
    --no-create-snapshot)
        SNAPSHOT=NO
        ;;
    --old-kmutil)
        echo "Using old kmutil binary from beta 7/8."
        echo "This will give verbose error messages, which might help with debugging."
        OLD_KMUTIL=YES
        ;;
    --un*|-u)
        echo "Uninstalling kexts."
        PATCHMODE="-u"
        ;;
    --no-wifi)
        echo "Override disabling WiFi patch."
        INSTALL_WIFI=NO
        ;;
    --wifi=hv12v-old)
        echo "Using highvoltage12v's old WiFi patch."
        INSTALL_WIFI="hv12v-old"
        ;;
    --wifi=hv12v-new)
        echo "Using highvoltage12v's new WiFi patch ."
        INSTALL_WIFI="hv12v-new"
        ;;
    --wifi=mojave-hybrid)
        echo "Using mojave-hybrid (by BarryKN) WiFi patch."
        INSTALL_WIFI="mojave-hybrid"
        ;;
    --useOC)
        echo "Assuming this is a iMac 2011 with OpenCore (K610, K1100M, K2100M, AMD Polaris GPU)."
        IMACUSE_OC=YES
        ;;
    --force)
        echo "Overriding some checks."
        FORCE=YES
        ;;
    --2009)
        echo "--2009 specified; using equivalent --2010 patches."
        PATCHMODE=--2010
        ;;
    --2010)
        echo "Using --2010 patches."
        PATCHMODE=--2010
        ;;
    --2011)
        echo "Using --2011 patches."
        PATCHMODE=--2011
        ;;
    --2012)
        echo "Using --2012 patches."
        PATCHMODE=--2012
        ;;
    --2013)
        echo "--2013 specified; using equivalent --2012 patches."
        PATCHMODE=--2012
        ;;
    *)
        echo "Unknown command line option: $1"
        exit 1
        ;;
    esac

    shift
done

# MARK: Check Configuration

# Check if we need the mojave-hybrid patch.

echo "Checking WiFi patch configuration..."
if [[ "x$PATCHMODE" = "x--2010" && -z "$INSTALL_WIFI" ]]
then
    echo "Using --2011 Patches with WiFi Patch."
    INSTALL_WIFI=mojave-hybrid
elif [[ "x$PATCHMODE" != "x-u" && -z "$INSTALL_WIFI" ]]
then
    echo "No WiFi option specified, so checking for 802.11ac..."
    if [ -z "`ioreg -l | fgrep 802.11 | fgrep ac`" ]
    then
        echo "No 802.11ac WiFi card detected, using WiFi patch."
        INSTALL_WIFI=mojave-hybrid
    else
        echo "Found 802.11ac WiFi card, not using WiFi patch."
        INSTALL_WIFI=NO
    fi
fi

# Check what patches to use.
if [ -z "$PATCHMODE" ]
then
    echo "Auto-detecting Mac model..."
    echo "(Override with --2010, --2011, or --2012)"
    MODEL=`sysctl -n hw.model`
    echo "Detected model: $MODEL"
    case $MODEL in
    # Macs with CPUs that can't run Big Sur.
    iMac,1|Power*|RackMac*|[0-9][0-9][0-9])
        error "This Mac cannot boot Big Sur."
        ;;
    MacBookPro1,?|MacBook1,1|Macmini1,1)
        error "This Mac cannot boot Big Sur."
        ;;
    MacBook[23],1|Macmini2,1|MacPro[12],1|MacBookAir1,1|MacBookPro[23],?|Xserve1,?)
        error "This Mac cannot boot Big Sur."
        ;;
    MacBookPro6,?)
        error "This Mac cannot boot Big Sur."
        ;;
    # Macs that support this patcher.
    MacBook[4-7],?|Macmini[34],1|MacBookAir[23],?|MacBookPro[457],?|MacPro3,1)
        echo "Detected a 2008-2010 Mac. Using --2010 patches."
        PATCHMODE=--2010
        ;;
    iMac[0-9],?|iMac10,?)
        echo "Detected a 2006-2009 iMac. Using --2010 patches."
        PATCHMODE=--2010
        ;;
    Macmini5,?|MacBookAir4,?|MacBookPro8,?)
        echo "Detected a 2011 Mac. Using --2011 patches."
        PATCHMODE=--2011
        ;;
    iMac11,?)
        echo "Detected a Late 2009 or Mid 2010 11,x iMac. Using special iMac 11,x patches."
        PATCHMODE=--IMAC11
        INSTALL_IMAC0910="YES"
        INSTALL_AGC="YES"
        IMACUSE_OC=YES
        ;;
    iMac12,?)
        echo "Detected a Mid 2011 12,x iMac. Using --2011 patches."
        PATCHMODE=--2011
        INSTALL_IMAC2011="YES"
        INSTALL_AGC="YES"
        INSTALL_MCCS="YES"
        ;;
    Macmini6,?|MacBookAir5,?|MacBookPro9,?|MacBookPro10,?|iMac13,?)
        echo "Detected a 2012-2013 Mac. Using --2012 patches."
        PATCHMODE=--2012
        ;;
    MacPro[45],1)
        echo "Detected a 2009-2012 Mac Pro. Using --2012 patches."
        PATCHMODE=--2012
        ;;
    iMac14,[123])
        error "Late 2013 iMacs don't need patch kexts!"
        ;;
    # Big Sur supported Macs.
    iMac14,4|iMac1[5-9],?|iMac[2-9][0-9],?|iMacPro*|MacPro[6-9],?|Macmini[7-9],?|MacBook[89],1|MacBook[1-9][0-9],?|MacBookAir[6-9],?|MacBookAir[1-9][0-9],?|MacBookPro1[1-9],?)
        error "This Mac supports Big Sur, and doesn't need a patcher!"
        ;;
    *)
        error "Unknown Mac. This is probably a Big Sur supported mac."
        exit 1
        ;;
    esac
fi

# Check for csr-active-config

echo "Checking SIP status"
if [ "x$RECOVERY" = "xNO" ]
then
    if [ "x$FORCE" != "xYES" ]; then
        CSRVAL="`nvram csr-active-config | cut -c 19-`"
        case $CSRVAL in
        w%0[89f]* | %[7f]f%0[89f]*)
            ;;
        *)
            echo csr-active-config appears to be set incorrectly:
            nvram csr-active-config
            echo
            echo "You can fix this by booting into the purple EFI Boot"
            echo "on your Patched Installer USB."
            error 'Invalid SIP status.'
            exit 1
            ;;
        esac
    fi
fi

# Figure out which kexts to install (or if we want to uninstall)

case $PATCHMODE in
--IMAC11)
    INSTALL_HDA="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_BCM5701="YES"
    echo "Installing HSA, Legacy USB, and BCM701 patches."
    ;;
--2010)
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_GFTESLA="YES"
    INSTALL_NVENET="YES"
    INSTALL_BCM5701="YES"
    DEACTIVATE_TELEMETRY="YES"
    echo "Installing HDA, HD3000 (NOT gx accel), Legacy USB, GFTesla, NVENet, and BCM5701 patches."
    ;;
--2011)
    INSTALL_HDA="YES"
    INSTALL_HD3000="YES"
    INSTALL_LEGACY_USB="YES"
    INSTALL_BCM5701="YES"
    echo "Installing HDA, HD3000 (NOT gx accel), Legacy USB, and BCM5701 patches."
    ;;
--2012)
    if [ "x$INSTALL_WIFI" = "xNO" ]
    then
        error "--2012 patches only contains WiFI patches, however no WiFi patches were requested/are needed."
    fi
    ;;
-u)
    # Just so this doesn't fall into default.
    ;;
*)
    error "Unknown patch mode!"
    ;;
esac

# Check what volume to patch.

echo "Checking what volume to patch..."
VOLUME="$1"

if [ -z "$VOLUME" ]
then
    if [ "x$RECOVERY" = "xYES" ]
    then
        echo "Booted into recovery mode with no target volume."
        error "No target volume provided (ex `/path/to/PatchKexts.sh \"/Volumes/Macintosh HD`\")"
    else
        echo "Booted into full Big Sur, using main volume."
        VOLUME="/"
    fi
fi

if [ "x$PATCHMODE" != "x-u" ]
then
    echo "Installing kexts to volume $VOLUME"
else
    echo "Uninstalling patched kexts from volume $VOLUME"
fi
echo

# Sanity check for reasons.
# Just to make sure this exists.

if [ ! -d "$VOLUME" ]
then
    error "Unable to find the volume you wanted to patch kexts to."
fi

echo "Verifying volume..."

# Check if this is not a data partition.

if [ ! -d "$VOLUME/System/Library/Extensions" ]
then
    error "Specified volume was not the system volume."
fi

# Check if the volume is a Big Sur installation
SVPL="$VOLUME"/System/Library/CoreServices/SystemVersion.plist
SVPL_VER=`fgrep '<string>10' "$SVPL" | sed -e 's@^.*<string>10@10@' -e 's@</string>@@' | uniq -d`
SVPL_BUILD=`grep '<string>[0-9][0-9][A-Z]' "$SVPL" | sed -e 's@^.*<string>@@' -e 's@</string>@@'`

if echo $SVPL_BUILD | grep -q '^20'
then
    echo -n "Volume has Big Sur build" $SVPL_BUILD
else
    if [ -z "$SVPL_VER" ]
    then
        error "Unknown macOS version on volume."
    else
        error "macOS" "$SVPL_VER" "build" "$SVPL_BUILD" "detected. This patcher only works on Big Sur."
    fi
    exit 1
fi

echo "Correctly volume mount..."

# Check whether the mounted volume is actually the underlying volume or a snapshot.
DEVICE=`df "$VOLUME" | tail -1 | sed -e 's@ .*@@'`
echo 'Volume is mounted from device ' $DEVICE

POPSLICE=`echo $DEVICE | sed -E 's@s[0-9]+$@@'`
POPSLICE2=`echo $POPSLICE | sed -E 's@s[0-9]+$@@'`

if [ $POPSLICE = $POPSLICE2 ]
then
    WASSNAPSHOT="NO"
    echo "Mounted volume is not a snapshot."
else
    WASSNAPSHOT="YES"
    #VOLUME=`mktemp -d`
    # Use the same mountpoint as Apple's own updaters.
    
    VOLUME=/System/Volumes/Update/mnt1
    echo "Mounted device is a snapshot."
    echo "Attempting to mount underlying volume"
    echo "from device $POPSLICE at temporary mountpoint:"
    echo "$VOLUME"
    echo
    
    if ! mount -o nobrowse -t apfs "$POPSLICE" "$VOLUME"
    then
        error 'Failed to mount underlying volume.'
    fi
fi

if [ "x$RECOVERY" = "xYES" ]
then
    echo "Confirming SIP status..."
    # It's likely that at least one of these was reenabled during installation.
    # But as we're in the recovery environment, there's no need to check --
    # we'll just redisable these. If they're already disabled, then there's
    # no harm done.
    #
    # Actually, in October 2020 it's now apparent that we need to avoid doing
    # `csrutil disable` on betas that are too old (due to a SIP change
    # that happened in either beta 7 or beta 9). So avoid it on beta 1-6.
    case $SVPL_BUILD in
    20A4[0-9][0-9][0-9][a-z] | 20A53[0-6][0-9][a-z])
        ;;
    *)
        csrutil disable
        ;;
    esac
    csrutil authenticated-root disable
fi

if [ "x$WASSNAPSHOT" = "xNO" ]
then
    echo "Remounting volume as read-write..."
    if ! mount -uw "$VOLUME"
    then
        error "Volume r/w remount failed."
    fi
fi

if [ "x$PATCHMODE" != "x-u" ]
then
    echo "Checking for KernelCollection backup..."
    pushd "$VOLUME/System/Library/KernelCollections" > /dev/null
    BACKUP_FILE_BASE="KernelCollections-$SVPL_BUILD.tar"
    BACKUP_FILE="$BACKUP_FILE_BASE".lz4
    
    if [ -e "$BACKUP_FILE" ]
    then
        echo "Backup already there, so not overwriting."
    else
        echo "Backup not found. Performing backup now. This may take a few minutes."
        echo "Backing up original KernelCollections to:"
        echo `pwd`/"$BACKUP_FILE"
        tar cv *.kc | "$VOLUME/usr/bin/compression_tool" -encode -a lz4 > "$BACKUP_FILE"
        #tar cv *.kc | "$VOLUME/usr/bin/compression_tool" -encode > "$BACKUP_FILE"
        #tar c *.kc | "$IMGVOL/zstd" --long --adapt=min=0,max=19 -T0 -v > "$BACKUP_FILE"

        # Check for errors. Print an error message *and clean up* if necessary.
        if [ $? -ne 0 ]
        then
            echo "tar or compression_tool failed. See above output for more information."

            echo "Attempting to remove incomplete backup..."
            rm -f "$BACKUP_FILE"
            
            error "Failed to backup kernel collection. Check the logs for more info."
        fi
    fi
    
    popd > /dev/null
    
    # For each kext:
    # Move the old kext out of the way, or delete if needed. Then unzip the
    # replacement.
    pushd "$VOLUME/System/Library/Extensions" > /dev/null
    
    echo "Begin replacing kexts..."
    if [ "x$INSTALL_WIFI" != "xNO" ]
    then
        echo 'Beginning patched IO80211Family.kext installation'
        if [ -d IO80211Family.kext.original ]
        then
            rm -rf IO80211Family.kext
        else
            mv IO80211Family.kext IO80211Family.kext.original
        fi

        case $INSTALL_WIFI in
        hv12v-old)
            echo 'Installing old highvoltage12v WiFi patch'
            unzip -q "$LPATCHES/KextPatches/IO80211Family-highvoltage12v-old.kext.zip"
            ;;
        hv12v-new)
            echo 'Installing new highvoltage12v WiFi patch'
            unzip -q "$LPATCHES/KextPatches/IO80211Family-highvoltage12v-new.kext.zip"
            ;;
        mojave-hybrid)
            echo 'Installing mojave-hybrid WiFi patch'
            unzip -q "$LPATCHES/KextPatches/IO80211Family-18G6032.kext.zip"
            pushd IO80211Family.kext/Contents/Plugins > /dev/null
            unzip -q "$LPATCHES/KextPatches/AirPortAtheros40-17G14033+pciid.kext.zip"
            popd > /dev/null
            ;;
        *)
            echo 'patch-kexts.sh encountered an internal error while installing the WiFi patch.'
            echo "Invalid value for INSTALL_WIFI variable:"
            echo "INSTALL_WIFI=$INSTALL_WIFI"
            echo 'This is a patcher bug. patch-kexts.sh cannot continue.'
            exit 1
            ;;
        esac

        # The next line is really only here for the highvoltage12v zip
        # files, but it does no harm in other cases.
        rm -rf __MACOSX

        fixPerms IO80211Family.kext
    fi

    if [ "x$INSTALL_HDA" = "xYES" ]
    then
        echo 'Installing High Sierra AppleHDA.kext'
        if [ -d AppleHDA.kext.original ]
        then
            rm -rf AppleHDA.kext
        else
            mv AppleHDA.kext AppleHDA.kext.original
        fi

        unzip -q "$LPATCHES/KextPatches/AppleHDA-17G14033.kext.zip"
        fixPerms AppleHDA.kext
    fi

    if [ "x$INSTALL_HD3000" = "xYES" ]
    then
        echo 'Installing High Sierra Intel HD 3000 kexts'
        rm -rf AppleIntelHD3000* AppleIntelSNB*

        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000Graphics.kext-17G14033.zip"
        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000GraphicsGA.plugin-17G14033.zip"
        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000GraphicsGLDriver.bundle-17G14033.zip"
        unzip -q "$LPATCHES/KextPatches/AppleIntelSNBGraphicsFB.kext-17G14033.zip"
        fixPerms AppleIntelHD3000* AppleIntelSNB*
    fi

    if [ "x$INSTALL_LEGACY_USB" = "xYES" ]
    then
        echo 'Installing LegacyUSBInjector.kext'
        rm -rf LegacyUSBInjector.kext

        unzip -q "$LPATCHES/KextPatches/LegacyUSBInjector.kext.zip"
        fixPerms LegacyUSBInjector.kext

        # parameter for kmutil later on
        BUNDLE_PATH="--bundle-path /System/Library/Extensions/LegacyUSBInjector.kext"
    fi

    if [ "x$INSTALL_GFTESLA" = "xYES" ]
    then
        echo 'Installing GeForce Tesla (9400M/320M) kexts'
        rm -rf *Tesla*

        unzip -q "$LPATCHES/KextPatches/GeForceTesla-17G14033.zip"
        unzip -q "$LPATCHES/KextPatches/NVDANV50HalTesla-17G14033.kext.zip"

        unzip -q "$LPATCHES/KextPatches/NVDAResmanTesla-ASentientBot.kext.zip"
        rm -rf __MACOSX

        fixPerms *Tesla*
    fi

    if [ "x$INSTALL_NVENET" = "xYES" ]
    then
        echo 'Installing High Sierra nvenet.kext'
        pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
        rm -rf nvenet.kext
        unzip -q "$LPATCHES/KextPatches/nvenet-17G14033.kext.zip"
        fixPerms nvenet.kext
        popd > /dev/null
    fi

    if [ "x$INSTALL_BCM5701" = "xYES" ]
    then
        case $SVPL_BUILD in
        20A4[0-9][0-9][0-9][a-z])
            # skip this on Big Sur dev beta 1 and 2
            ;;
        *)
            echo 'Installing Catalina AppleBCM5701Ethernet.kext'
            pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null

            if [ -d AppleBCM5701Ethernet.kext.original ]
            then
                rm -rf AppleBCM5701Ethernet.kext
            else
                mv AppleBCM5701Ethernet.kext AppleBCM5701Ethernet.kext.original
            fi

            unzip -q "$LPATCHES/KextPatches/AppleBCM5701Ethernet-19H2.kext.zip"
            fixPerms AppleBCM5701Ethernet.kext

            popd > /dev/null
            ;;
        esac
    fi

    if [ "x$INSTALL_MCCS" = "xYES" ]
    then
        echo 'Installing Catalina (for iMac 2011) AppleMCCSControl.kext'
        if [ -d AppleMCCSControl.kext.original ]
        then
            rm -rf AppleMCCSControl.kext
        else
            mv AppleMCCSControl.kext AppleMCCSControl.kext.original
        fi

        unzip -q "$LPATCHES/KextPatches/AppleMCCSControl.kext.zip"
        chown -R 0:0 AppleMCCSControl.kext
        chmod -R 755 AppleMCCSControl.kext
    fi

    #
    # install patches needed by the iMac 2011 family (metal GPU, only)
    #
    if [ "x$INSTALL_IMAC2011" = "xYES" ]
    then
        # this will any iMac 2011 need
        # install the iMacFamily extensions
        echo "Installing highvoltage12v patches for iMac 2011 family"
        echo "Using SNB and HD3000 VA bundle files"

        unzip -q "$LPATCHES/KextPatches/AppleIntelHD3000GraphicsVADriver.bundle-17G14033.zip"
        unzip -q "$LPATCHES/KextPatches/AppleIntelSNBVA.bundle-17G14033.zip"
        
        chown -R 0:0 AppleIntelHD3000* AppleIntelSNB*
        chmod -R 755 AppleIntelHD3000* AppleIntelSNB*

        # AMD=`/usr/sbin/ioreg -l | grep Baffin`
        # NVIDIA=`/usr/sbin/ioreg -l | grep NVArch`

        AMD=`chroot "$VOLUME" ioreg -l | grep Baffin`
        NVIDIA=`chroot "$VOLUME" ioreg -l | grep NVArch`
    
        if [ "$AMD" ]
        then
            echo $CARD "Polaris Card found"
            echo "Using iMacPro1,1 enabled version of AppleIntelSNBGraphicsFB.kext"
            echo "WhateverGreen and Lilu need to be injected by OpenCore"
            rm -rf AppleIntelSNBGraphicsFB.kext
            unzip -q "$LPATCHES/KextPatches/AppleIntelSNBGraphicsFB-AMD.kext.zip"
            # rename AppleIntelSNBGraphicsFB-AMD.kext
            mv AppleIntelSNBGraphicsFB-AMD.kext AppleIntelSNBGraphicsFB.kext
            chown -R 0:0 AppleIntelSNBGraphicsFB.kext
            chmod -R 755 AppleIntelSNBGraphicsFB.kext

        elif [ "$NVIDIA" ]
        then
            INSTALL_BACKLIGHT = "YES"
            # INSTALL_AGC="YES"

            if [ "x$IMACUSE_OC"=="xYES" ]
            then
                echo "AppleBacklightFixup, WhateverGreen and Lilu need to be injected by OpenCore"
            else
                INSTALL_BACKLIGHTFIXUP="YES"
                INSTALL_VIT9696="YES"
            fi
        else
            echo "No metal supported video card found in this system!"
            echo "Big Sur may boot, but will be barely usable due to lack of any graphics acceleration"
        fi
    fi

    #
    # install patches needed by the iMac 2009-2010 family (metal GPU, only)
    # OC has to be used in any case, assuming injection of
    # AppleBacklightFixup, FakeSMC, Lilu, WhateverGreen
    #
    if [ "x$INSTALL_IMAC0910" = "xYES" ]
    then
        AMD=`chroot "$VOLUME" ioreg -l | grep Baffin`
        NVIDIA=`chroot "$VOLUME" ioreg -l | grep NVArch`

        # AMD=`/usr/sbin/ioreg -l | grep Baffin`
        # NVIDIA=`/usr/sbin/ioreg -l | grep NVArch`
    
        if [ "$AMD" ]
        then
            echo $CARD "AMD Polaris Card found"
        elif [ "$NVIDIA" ]
        then
            INSTALL_BACKLIGHT="YES"
            # INSTALL_AGC="YES"
            echo $CARD "NVIDIA Kepler Card found"
        else
            echo "No metal supported video card found in this system!"
            echo "Big Sur may boot, but will be barely usable due to lack of any graphics acceleration"
        fi
    fi


    if [ "x$INSTALL_AGC" = "xYES" ]
    then
        # we need the original file because we do an in place Info.plist patching....
        if [ -f AppleGraphicsControl.kext.zip ]
        then
           rm -rf AppleGraphicsControl.kext
           unzip -q AppleGraphicsControl.kext.zip
           rm -rf AppleGraphicsControl.kext.zip
        else
           # create a backup using a zip archive on disk
           # could not figure out how to make a 1:1 copy of an kext folder using cp, ditto and others
           zip -q -r -X AppleGraphicsControl.kext.zip AppleGraphicsControl.kext
        fi

        echo 'Patching AppleGraphicsControl.kext with iMac 2009-2011 board-id'
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-942B59F58194171B string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-942B5BF58194151B string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2268DAE string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2238AC8 string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        /usr/libexec/PlistBuddy -c 'Add :IOKitPersonalities:AppleGraphicsDevicePolicy:ConfigMap:Mac-F2238BAE string none' AppleGraphicsControl.kext/Contents/PlugIns/AppleGraphicsDevicePolicy.kext/Contents/Info.plist
        
        chown -R 0:0 AppleGraphicsControl.kext
        chmod -R 755 AppleGraphicsControl.kext
        
    fi

    if [ "x$INSTALL_AGCOLD" = "xYES" ]
    then
        if [ -d AppleGraphicsControl.kext.original ]
        then
            rm -rf AppleGraphicsControl.kext
            mv AppleGraphicsControl.kext.original AppleGraphicsControl.kext
        else
            cp -R AppleGraphicsControl.kext AppleGraphicsControl.kext.original
        fi
        
        unzip -q "$LPATCHES/KextPatches/AppleGraphicsControl.kext.zip"
        chown -R 0:0 AppleGraphicsControl.kext
        chmod -R 755 AppleGraphicsControl.kext
    fi

    if [ "x$INSTALL_BACKLIGHT" = "xYES" ]
    then
        echo 'Installing (for iMac NVIDIA 2009-2011) Catalina AppleBacklight.kext'
        if [ -d AppleBacklight.kext.original ]
        then
            rm -rf AppleBacklight.kext
        else
            mv AppleBacklight.kext AppleBacklight.kext.original
        fi

        unzip -q "$LPATCHES/KextPatches/AppleBacklight.kext.zip"
        chown -R 0:0 AppleBacklight.kext
        chmod -R 755 AppleBacklight.kext
    fi

    if [ "x$INSTALL_BACKLIGHTFIXUP" = "xYES" ]
    then
        echo 'Installing (for iMac NVIDIA 2009-2011) AppleBacklightFixup.kext'

        unzip -q "$LPATCHES/KextPatches/AppleBacklightFixup.kext.zip"
        chown -R 0:0 AppleBacklightFixup.kext
        chmod -R 755 AppleBacklightFixup.kext
    fi

    if [ "x$INSTALL_VIT9696" = "xYES" ]
    then
        echo 'Installing (for iMac 2009-2011) WhateverGreen.kext and Lilu.kext'

        rm -rf WhateverGreen.kext
        unzip -q "$LPATCHES/KextPatches/WhateverGreen.kext.zip"

        rm -rf Lilu.kext
        unzip -q "$LPATCHES/KextPatches/Lilu.kext.zip"
 
        chown -R 0:0 WhateverGreen* Lilu*
        chmod -R 755 WhateverGreen* Lilu*
    fi

    popd > /dev/null

    if [ "x$DEACTIVATE_TELEMETRY" = "xYES" ]
    then
        echo 'Deactivating com.apple.telemetry.plugin'
        pushd "$VOLUME/System/Library/UserEventPlugins" > /dev/null
        mv -f com.apple.telemetry.plugin com.apple.telemetry.plugin.disabled
        popd > /dev/null
    fi
    
    # MARK: Rebuild Kernel Collection
    
    echo "Prepare for kmutil"
    
    # Get ready to use kmutil
    if [ "x$OLD_KMUTIL" = "xYES" ]
    then
        cp -f "$LPATCHES/ArchiveBin/kmutil.beta8re" "$VOLUME/usr/bin/kmutil.old"
        KMUTIL=kmutil.old
    else
        KMUTIL=kmutil
    fi
    
    # Update the kernel/kext collections.
    # kmutil *must* be invoked separately for boot and system KCs when
    # LegacyUSBInjector is being used, or the injector gets left out, at least
    # as of Big Sur beta 2. So, we'll always do it that way (even without
    # LegacyUSBInjector, it shouldn't do any harm).
    #
    # I suspect it's not supposed to require the chroot, but I was getting weird
    # "invalid argument" errors, and chrooting it eliminated those errors.
    # BTW, kmutil defaults to "--volume-root /" according to the manpage, so
    # it's probably redundant, but whatever.
    echo 'Rebuilding boot collection...'
    chroot "$VOLUME" $KMUTIL create -n boot \
        --kernel /System/Library/Kernels/kernel \
        --variant-suffix release --volume-root / $BUNDLE_PATH \
        --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
    errorCheck kmutil

    # When creating SystemKernelExtensions.kc, kmutil requires *both*
    # --both-path and --system-path!
    echo 'Rebuilding system collection...'
    chroot "$VOLUME" $KMUTIL create -n sys \
        --kernel /System/Library/Kernels/kernel \
        --variant-suffix release --volume-root / \
        --system-path /System/Library/KernelCollections/SystemKernelExtensions.kc \
        --boot-path /System/Library/KernelCollections/BootKernelExtensions.kc
    errorCheck kmutil
    
    echo "Finished rebuilding"
else
    # MARK: Restore Kernel Collection Backup

    # Instead of updating the kernel/kext collections (later), restore the backup
    # that was previously saved (now).

    pushd "$VOLUME/System/Library/KernelCollections" > /dev/null

    BACKUP_FILE_BASE="KernelCollections-$SVPL_BUILD.tar"
    BACKUP_FILE="$BACKUP_FILE_BASE".lz4
    #BACKUP_FILE_BASE="$BACKUP_FILE_BASE".lzfse
    #BACKUP_FILE_BASE="$BACKUP_FILE_BASE".zst

    if [ ! -e "$BACKUP_FILE" ]
    then
        echo "Looked for KernelCollections backup at:"
        echo "`pwd`"/"$BACKUP_FILE"
        echo "but could not find it. unpatch-kexts.sh cannot continue."
        error "Failed to find kernel collection backup at $(pwd)/$BACKUP_FILE"
    fi
    
    echo "Restoring KernelCollections backup from:"
    echo "$(pwd)/$BACKUP_FILE"
    rm -f *.kc
    
    "$VOLUME/usr/bin/compression_tool" -decode < "$BACKUP_FILE" | tar xpv
    errorCheck tar
    
    # Must remove the KernelCollections backup now, or the mere existence
    # of it causes filesystem verification to fail.
    rm -f "$BACKUP_FILE"
    
    popd > /dev/null
    
    echo "Restoring original kexts"
    # Now remove the new kexts and move the old ones back into place.
    # First in /System/Library/Extensions, then in
    # /S/L/E/IONetworkingFamily.kext/Contents/Plugins
    # (then go back up to /System/Library/Extensions)
    pushd "$VOLUME/System/Library/Extensions" > /dev/null
    restoreOriginals

    pushd IONetworkingFamily.kext/Contents/Plugins > /dev/null
    restoreOriginals
    popd > /dev/null
    
    # And remove kexts which did not overwrite newer versions.
    if [ -f AppleGraphicsControl.kext.zip ]
    then
        echo 'Restoring patched AppleGraphicsControl extension'
        rm -rf AppleGraphicsControl.kext
        unzip -q AppleGraphicsControl.kext.zip
        rm AppleGraphicsControl.kext.zip
    fi
    rm -rf AppleGraphicsControl.kext
    echo 'Removing kexts for Intel HD 3000 graphics support'
    rm -rf AppleIntelHD3000* AppleIntelSNB*
    echo 'Removing LegacyUSBInjector'
    rm -rf LegacyUSBInjector.kext
    echo 'Removing nvenet'
    rm -rf IONetworkingFamily.kext/Contents/Plugins/nvenet.kext
    echo 'Removing GeForceTesla.kext and related kexts'
    rm -rf *Tesla*
    echo 'Removing @vit9696 Whatevergreen.kext and Lilu.kext'
    rm -rf Whatevergreen.kext Lilu.kext
    echo 'Removing iMac AppleBacklightFixup'
    rm -rf AppleBacklightFixup.kext
    echo 'Reactivating telemetry plugin'
    mv -f "$VOLUME/System/Library/UserEventPlugins/com.apple.telemetry.plugin.disabled" "$VOLUME/System/Library/UserEventPlugins/com.apple.telemetry.plugin"
    
    popd > /dev/null

    # Also, remove kmutil.old (if it exists, it was installed by patch-kexts.sh)
    rm -f "$VOLUME/usr/bin/kmutil.old"
fi

echo "Running kcditto"
"$VOLUME/usr/sbin/kcditto"
errorCheck kcditto

# MARK: Snapshots Stuff

# First, check if there was a snapshot-related command line option.
# If not, pick a default as follows:
#
# If $VOLUME = "/" at this point in the script, then we are running in a
# live installation and the system volume is not booted from a snapshot.
# Otherwise, assume snapshot booting is configured and use bless to create
# a new snapshot.
if [ -z "$SNAPSHOT" ]
then
    if [ "$VOLUME" != "/" ]
    then
        SNAPSHOT=YES
        CREATE_SNAPSHOT="--create-snapshot"
        echo 'Creating new root snapshot.'
    else
        SNAPSHOT=NO
        echo 'Booted directly from volume, so skipping snapshot creation.'
    fi
elif [ SNAPSHOT = YES ]
then
    CREATE_SNAPSHOT="--create-snapshot"
    echo 'Creating new root snapshot due to command line option.'
else
    echo 'Skipping creation of root snapshot due to command line option.'
fi

echo "Reblessing volume"
bless --folder "$VOLUME"/System/Library/CoreServices --bootefi $CREATE_SNAPSHOT --setBoot
errorCheck bless

# Try to unmount the underlying volume if it was mounted by this script.
# (Otherwise, trying to run this script again without rebooting causes
# errors when this script tries to mount the underlying volume a second
# time.)
if [ "x$WASSNAPSHOT" = "xYES" ]
then
    echo "Attempting to unmount underlying volume (don't worry if this fails)."
    echo "This may take a minute or two."
    umount "$VOLUME" || diskutil unmount "$VOLUME"
fi

if [ "x$PATCHMODE" != "x-u" ]
then
    echo 'Installed patch kexts successfully.'
else
    echo 'Uninstalled patch kexts successfully.'
fi
