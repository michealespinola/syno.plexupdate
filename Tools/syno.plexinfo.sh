#!/bin/bash
# shellcheck disable=SC2034
# SC1091,SC2004,SC2154,SC2181
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexinfo.sh

# SCRIPT VERSION
SPIScrpVer=1.0.0
# PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
printf "\n"
printf "%s\n" "SYNO.PLEX INFO SCRIPT for DSM 7"
printf "\n"

# SCRAPE SCRIPT PATH INFO
SrceFllPth=$(readlink -f "${BASH_SOURCE[0]}")
SrceFolder=$(dirname "$SrceFllPth")
SrceFileNm=${SrceFllPth##*/}

# SCRAPE SYNOLOGY HARDWARE MODEL
SynoHModel=$(cat /proc/sys/kernel/syno_hw_version)
# SCRAPE SYNOLOGY CPU ARCHITECTURE FAMILY
SynoFmArch=$(uname --machine)
SynoFmProc=$(uname --all | awk '{ print $NF }' | awk -F "_" '{ print $2 }')
SynoNodenm=$(uname --nodename)
SynoFmKern=$(uname --kernel-name)
SynoFmKrnR=$(uname --kernel-release)
SynoFmKLcs=$(echo "$SynoFmKern" | awk '{ print tolower($0) }')
# SCRAPE DSM VERSION
SynoDSMVer=$(grep -i "productversion=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
SynoDSMVer=$(echo "$SynoDSMVer"-"$(grep -i "buildnumber="    "/etc.defaults/VERSION" | cut -d"\"" -f 2)")
SynoDSMUpV=$(                      grep -i "smallfixnumber=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
if [ -n "$SynoDSMUpV" ]; then
  SynoDSMVer="$SynoDSMVer Update $SynoDSMUpV"
fi

# CHECK IF ADMIN IS DISABLED
SynoAdminF=$(synouser --get admin | grep "Fullname"  | awk -F "[][{}]" '{ print $2 }')
SynoAdminE=$(synouser --get admin | grep "User Mail" | awk -F "[][{}]" '{ print $2 }')
SynoAdminX=$(synouser --get admin | grep "Expired"   | awk -F "[][{}]" '{ print $2 }')
if [ "$SynoAdminX" = "true" ]; then
  SynoAdminX="Disabled"
elif [ "$SynoAdminX" = "false" ]; then
  SynoAdminX="Enabled (SECURITY RISK)"
# synouser --modify "admin" "$SynoAdminF" 1 "$SynoAdminE"
else 
  SynoAdminX="Unknown (???)"
fi

# GET INTERNAL IP ADDRESS INFO
SynoIntrIP=$(ip -f inet -o addr show eth0 | cut -d\  -f 7 | cut -d/ -f 1)

# SCRAPE EXTERNAL IP4 ADDRESS METHODS
  SynoExtrIP=$(ping -c 1 myip.opendns.com | awk -F "[()]" '/PING/ { print $2 }')
# SynoExtrIP=$(curl -Ls checkip.amazonaws.com)
# SynoExtrIP=$(curl -Ls whatismyip.akamai.com)
# SynoExtrIP=$(curl -Ls api.ipify.org)

# GET TIME ZONE INFO
SynoTZones=$( \
  find /usr/share/zoneinfo -type f -print0 | \
  xargs -0 md5sum | \
  grep "$(md5sum /etc/localtime | \
  cut -f 1 -d " ")" | \
  awk '{ gsub("[A-Za-z0-9]{32}\\s{2}/usr/share/zoneinfo/", "") }1' \
)

# SCRAPE PMS FOLDER LOCATION AND VERSION INFO
PlexMSVers=$(/usr/syno/bin/synopkg version "PlexMediaServer")
PlexFolder=$(readlink /var/packages/PlexMediaServer/shares/PlexMediaServer)
PlexFolder="$PlexFolder/AppData/Plex Media Server"
PlexTransc=$("/volume1/@appstore/PlexMediaServer/Plex Transcoder" -version -hide_banner | head -n 1 | cut -d " " -f 1)
PlexTransV=$("/volume1/@appstore/PlexMediaServer/Plex Transcoder" -version -hide_banner | head -n 1 | cut -d " " -f 3)
PlexCodecs="$PlexFolder/Codecs"
PlexFVCdcs=$(find "$PlexFolder/Codecs" -type d -name "$PlexTransV-$SynoFmKLcs-$SynoFmArch")
PlexDevcID=$(head -n 1 "$PlexCodecs/.device-id")
PlexFrName=$(grep -oP  "FriendlyName=\"\K[^\"]+"                "$PlexFolder/Preferences.xml")
PlexOToken=$(grep -oP  "PlexOnlineToken=\"\K[^\"]+"             "$PlexFolder/Preferences.xml")
PlexMachID=$(grep -oP  "ProcessedMachineIdentifier=\"\K[^\"]+"  "$PlexFolder/Preferences.xml")
PlexChannl=$(grep -oP  "ButlerUpdateChannel=\"\K[^\"]+"         "$PlexFolder/Preferences.xml")
if [ -z "$PlexChannl" ]; then
  PlexChannl=Public
else
  if [ "$PlexChannl" -eq "0" ]; then
    PlexChannl=Public
  elif [ "$PlexChannl" -eq "8" ]; then
    PlexChannl=Beta
  else
    PlexChannl=Undefined
  fi
fi

echo SYNOLOGY NAS INFO:
echo "---------------"
echo "       Nodename: $SynoNodenm"
echo "        DSM ver: $SynoDSMVer"
echo "          Model: $SynoHModel"
echo "   Architecture: $SynoFmArch ($SynoFmProc)"
echo "         Kernel: $SynoFmKern ($SynoFmKrnR)"
echo "  Admin account: $SynoAdminX"
echo "    Internal IP: $SynoIntrIP"
echo "    External IP: $SynoExtrIP"
echo 
echo TIME ZONE INFO:
echo "---------------"
printf "%s\n" "$SynoTZones"
echo 
echo PLEX MEDIA SERVER INFO:
echo "---------------"
echo "  Friendly Name: $PlexFrName"
echo "        PMS ver: $PlexMSVers"
echo "     Transcoder: $PlexTransc ($PlexTransV)"
echo " Update Channel: $PlexChannl"
echo "      Device-ID: $PlexDevcID"
echo "     Machine-ID: $PlexMachID"
echo "   Online Token: $PlexOToken"
echo 
echo PLEX DIRECTORY REFERENCE:
echo "---------------"
[ -d "$PlexFolder"                 ] && echo \'"$PlexFolder"\'
[ -d "$PlexFolder/Codecs"          ] && echo \'"$PlexFolder/Codecs"\'
[ -d "$PlexFVCdcs"                 ] && echo \'"$PlexFVCdcs"\'
[ -d "$PlexFolder/Logs"            ] && echo \'"$PlexFolder/Logs"\'
[ -d "$PlexFolder/Plug-ins"        ] && echo \'"$PlexFolder/Plug-ins"\'
[ -d "$PlexFolder/Plug-in Support" ] && echo \'"$PlexFolder/Plug-in Support"\'
[ -d "$PlexFolder/Scanners"        ] && echo \'"$PlexFolder/Scanners"\'
[ -d "$PlexFolder/Scanners/Common" ] && echo \'"$PlexFolder/Scanners/Common"\'
[ -d "$PlexFolder/Scanners/Series" ] && echo \'"$PlexFolder/Scanners/Series"\'
echo "----------------"
echo 
