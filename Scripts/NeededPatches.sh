#!/bin/bash

#
#  PatchSystem.sh
#  Patched Sur
#
#  Created by Ben Sova on 5/15/21
#

# Check what patches to use.
if [ -z "$PATCHMODE" ]
then
    MODEL=`sysctl -n hw.model`
    case $MODEL in
    # Macs with CPUs that can't run Big Sur.
    iMac,1|Power*|RackMac*|[0-9][0-9][0-9])
        echo "UNKNOWN"
        ;;
    MacBookPro1,?|MacBook1,1|Macmini1,1)
        echo "UNKNOWN"
        ;;
    MacBook[23],1|Macmini2,1|MacPro[12],1|MacBookAir1,1|MacBookPro[23],?|Xserve1,?)
        echo "UNKNOWN"
        ;;
    MacBookPro6,?)
        echo "UNKNOWN"
        ;;
    # Macs that support this patcher.
    MacBook[4-7],?|Macmini[34],1|MacBookAir[23],?|MacBookPro[457],?|MacPro3,1)
        echo "(2010):HDA:HD3000:USB:GFTESLA:NVNET:BCM5701:TELEMETRY"
        ;;
    iMac[0-9],?|iMac10,?)
        echo "(2010):HDA:HD3000:USB:GFTESLA:NVNET:BCM5701:TELEMETRY"
        ;;
    Macmini5,?|MacBookAir4,?|MacBookPro8,?)
        echo "(2011):HDA:HD3000:USB:BCM5701"
        ;;
    iMac11,?)
        echo "(IMAC):HDA:USB:BCM5701:AGC"
        USEBACKLIGHT=`ioreg -l | grep NVArch`
        if USEBACKLIGHT; then
            echo "(MORE):BACKLIGHT"
        fi
        ;;
    iMac12,?)
        echo "(2011):HDA:HD3000:USB:BCM5701:AGC:MCCS:SMBBUNDLE"
        USEBACKLIGHT=`ioreg -l | grep NVArch`
        if USEBACKLIGHT; then
            echo "(MORE):BACKLIGHT:BACKLIGHTFIXUP:VIT9696"
        fi
        USEBUNDLE=`chroot "$VOLUME" ioreg -l | grep Baffin`
        if USEBUNDLE; then
            echo "(MORE):SMBKEXT"
        fi 
        INSTALL_IMAC2011="YES"
        ;;
    Macmini6,?|MacBookAir5,?|MacBookPro9,?|MacBookPro10,?|iMac13,?)
        echo "(2012)"
        ;;
    MacPro[45],1)
        echo "(2012)"
        ;;
    iMac14,[123])
        echo "NONE"
        ;;
    # Big Sur supported Macs.
    iMac14,4|iMac1[5-9],?|iMac[2-9][0-9],?|iMacPro*|MacPro[6-9],?|Macmini[7-9],?|MacBook[89],1|MacBook[1-9][0-9],?|MacBookAir[6-9],?|MacBookAir[1-9][0-9],?|MacBookPro1[1-9],?)
        echo "UNKNOWN"
        ;;
    *)
        echo "UNKNOWN"
        exit 1
        ;;
    esac
fi

if [ -z "`ioreg -l | fgrep 802.11 | fgrep ac`" ]; then
    echo "(MORE):WIFI"
fi