#!/bin/bash

#
#  PatchSystem.sh
#  Patched Sur
#
#  Created by Ben Sova on 5/15/21
#

exitIfUnknown() {
    if [[ "$1" == "--rerun" ]]; then
        echo "Failed to find Needed Patches, this Mac probably doesn't support the patcher (or just doesn't need it)." 1>&2
        exit 1
    fi
}

# Check what patches to use.
if [ -z "$PATCHMODE" ]
then
    MODEL=`sysctl -n hw.model`
    case $MODEL in
    # Macs that support this patcher.
    MacBook[4-7],?|Macmini[34],1|MacBookAir[23],?|MacBookPro[457],?|MacPro3,1|iMac[0-9],?|iMac10,?)
        echo "(2010):HDA:HD3000:USB:GFTESLA:NVNET:BCM5701:TELEMETRY:BOOTPLIST"
        HDA="--hda" HD3000="--hd3000" USB="--legacyUSB" GFTESLA="gfTesla" NVNET="--nvNet" BCM5701="--bcm5701" TELEMETRY="--telemetry" BOOTPLIST="--bootPlist"
        ;;
    Macmini5,?|MacBookAir4,?|MacBookPro8,?)
        echo "(2011):HDA:HD3000:USB:BCM5701:BOOTPLIST"
        HD3000="--hd3000" USB="--legacyUSB" BCM5701="--bcm5701" BOOTPLIST="--bootPlist"
        # HDA="--hda"
        ;;
    iMac11,?)
        echo "(IMAC):HDA:USB:BCM5701:AGC:BOOTPLIST"
        HDA="--hda" USB="--legacyUSB" BCM5701="--bcm5701" AGC="--agc" BOOTPLIST="--bootPlist"
        USEBACKLIGHT=`ioreg -l | grep NVArch`
        if USEBACKLIGHT; then
            echo "(MORE):BACKLIGHT"
            BACKLIGHT="--backlight"
        fi
        ;;
    iMac12,?)
        echo "(2011):HDA:HD3000:USB:BCM5701:AGC:MCCS:SMBBUNDLE:BOOTPLIST"
        HDA="--hda" HD3000="--hd3000" USB="--legacyUSB" BCM5701="--bcm5701" AGC="--agc" MCCS="--mccs" BOOTPLIST="--bootPlist" SMB="--smb=bundle"
        USEBACKLIGHT=`ioreg -l | grep NVArch`
        if [ "$USEBACKLIGHT" ]; then
            echo "(MORE):BACKLIGHT:FIXUP:VIT9696"
            BACKLIGHT="--backlight" FIXUP="--backlightFixup" VIT9696="--vit9696"
        fi
        USEBUNDLE=`chroot "$VOLUME" ioreg -l | grep Baffin`
        if [ "$USEBUNDLE" ]; then
            echo "(MORE):SMBKEXT"
            SMB="--smb=kext"
        fi
        ;;
    Macmini6,?|MacBookAir5,?|MacBookPro9,?|MacBookPro10,?|iMac13,?|MacPro[45],1|iMac14,[123])
        echo "(2012):BOOTPLIST"
        BOOTPLIST="--bootPlist"
        ;;
    # Everything else
    *)
        echo "UNKNOWN"
        exitIfUnknown
        ;;
    esac
fi

if [ -z "`ioreg -l | fgrep 802.11 | fgrep ac`" ]; then
    echo "(MORE):WIFI"
    WIFI="--wifi=mojave-hybird"
fi

if [[ "$1" == "--rerun" ]]; then
    echo "Running PatchSystem.sh..."
    "$2/PatchSystem.sh" $WIFI $HDA $HD3000 $USB $GFTESLA $NVNET $BCM5701 $TELEMETRY $AGC $MCCS $SMB $BACKLIGHT $BACKLIGHTFIXUP $VIT9696 $BOOTPLIST $3
    exit $?
fi
