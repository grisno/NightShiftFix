#!/bin/bash
#title           :NightShiftFix.sh
#description     :enable night shift on unsupported mac models
#date            :20170816
#version         :0.01
#source          :https://pikeralpha.wordpress.com/2017/01/30/4398/

errLevel=0

nm="/usr/bin/nm"
xxd="/usr/bin/xxd"
codesign="/usr/bin/codesign"
plistbuddy="/usr/libexec/PlistBuddy"

#############################################################
# Get Operating System Product Version
#############################################################

plist="${1}/System/Library/CoreServices/SystemVersion.plist"
if  [ -f "${plist}" ]; then
    version=$("${plistbuddy}" -c "print :ProductVersion" "${plist}")
else
    if  [ "${1}" == '/' ] || [ "${1}" == '' ]; then
        version=$(sw_vers -productVersion)
    else
        echo "[ERR] Get Operating System Product Version."
        exit 1
    fi
fi

if  [[ "$(printf ${version} | awk -F'.' '/10.12/{print $3}')" < "4" ]]; then
    printf "[ERR] Unsupported Operating System.\n"
    exit 2
fi

#############################################################
# Get SIP Status
#############################################################

if  [ $(echo "${version}" | grep -e "10.10\|10.11\|10.12") ]; then
    if  [[ "$(csrutil status | head -n 1)" == *"status: enabled (Custom Configuration)"* ]]; then
        printf "[WAR] SIP might or might not be disabled\n"
        printf "      the script might or might not be working\n"
        printf "      check \"\$ csrutil status\"\n"
    elif [[ "$(csrutil status | head -n 1)" == *"status: enabled"* ]]; then
        printf "[ERR] SIP is enabled, this script will only work if SIP is disabled\n"
        exit 3
    fi
fi  

#############################################################
# Get _ModelMinVersion Of Framework
#############################################################

framework="${1}/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/Current/CoreBrightness"

if  [ -f "${framework}" ] && [ -f "${nm}" ] && [ -f "${xxd}" ] && [ -f "${codesign}" ]; then
    input=`"${xxd}" -s $("${nm}" "${framework}" | \
         awk '/_ModelMinVersion/{print "0x"$1}') -l 24 -ps "${framework}"`
else
    printf "[ERR] Not found Xcode command line tools.\n"
    "${nm}" > /dev/null 2>&1
    exit 4
fi

#############################################################
# Get Model From IOACPIPlane
#############################################################

model=`ioreg -p IOACPIPlane -n acpi | awk -F\" '/"model"/{print $4}'`

if  [[ "${model}" != *Mac* ]]; then
    printf "[ERR] Model not supported.\n"
    exit 5
fi

#############################################################
# Set _ModelMinVersion Of Framework
#############################################################

if  [ "${#input}" == "48" ] ; then
    
    MacBookPro="${input:0:8}"
    iMac="${input:8:8}"
    Macmini="${input:16:8}"
    MacBookAir="${input:24:8}"
    MacPro="${input:32:8}"
    MacBook="${input:40:8}"

    case $model in
    MacBookPro[0-9]*)
        MacBookPro=`printf "%02x000000" $(echo ${model} | \
            awk 'BEGIN {FS=","} {gsub("MacBookPro", "", $1); print $1}')`
        ;;
    iMac[0-9]*)
        iMac=`printf "%02x000000" $(echo ${model} | \
            awk 'BEGIN {FS=","} {gsub("iMac", "", $1); print $1}')`
        ;;
    Macmini[0-9]*)
        Macmini=`printf "%02x000000" $(echo ${model} | \
            awk 'BEGIN {FS=","} {gsub("Macmini", "", $1); print $1}')`
        ;;
    MacBookAir[0-9]*)
        MacBookAir=`printf "%02x000000" $(echo ${model} | \
            awk 'BEGIN {FS=","} {gsub("MacBookAir", "", $1); print $1}')`
        ;;
    MacPro[0-9]*)
        MacPro=`printf "%02x000000" $(echo ${model} | \
            awk 'BEGIN {FS=","} {gsub("MacPro", "", $1); print $1}')`
        ;;
    MacBook[0-9]*) echo macbook
        MacBook=`printf "%02x000000" $(echo ${model} | \
            awk 'BEGIN {FS=","} {gsub("MacBook", "", $1); print $1}')`
        ;;
    *) 
        printf "[ERR] Model not supported.\n"
        exit 5
        ;;
    esac

    output="${MacBookPro}${iMac}${Macmini}${MacBookAir}${MacPro}${MacBook}"

    for ((i=0;i<48;i+=2)); do ihex="${ihex}\\x${input:$i:2}"; done
    for ((i=0;i<48;i+=2)); do ohex="${ohex}\\x${output:$i:2}"; done

    stdoutcmd=`perl -pi -e "s|${ihex}|${ohex}|" "${framework}"`
    if [ ! -z "${stdoutcmd}" ]; then errLevel=$((errLevel + 1)); fi

    codesign -f -s - "${framework}" > /dev/null 2>&1
    if  [ "$?" != "0" ]; then
        printf "[ERR] Replacing existing signature.\n"
        exit 7
    fi

    printf "[INF] Night Shift Enabled.\n"

else
    
    printf "[ERR] Unsupported version of framework.\n"
    exit 6
    
fi

exit "${errLevel}"

