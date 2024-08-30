#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC1091,SC2004,SC2154,SC2181
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexinfo.sh

# SCRIPT VERSION
SPIScrpVer=1.1.0

# Function to get DSM version
get_dsm_version() {
  SynoDSMVer=$(grep -i "productversion=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
  SynoDSMVer=$(echo "$SynoDSMVer"-"$(grep -i "buildnumber=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)")
  SynoDSMUpV=$(grep -i "smallfixnumber=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
  if [ -n "$SynoDSMUpV" ]; then
    SynoDSMVer="$SynoDSMVer Update $SynoDSMUpV"
  fi
}

# Function to get NAS information
get_nas_info() {
  SynoHModel=$(cat /proc/sys/kernel/syno_hw_version)
  SynoFmArch=$(uname --machine)
  SynoFmProc=$(uname --all | awk '{ print $NF }' | awk -F "_" '{ print $2 }')
  SynoNodenm=$(uname --nodename)
  SynoFmKern=$(uname --kernel-name)
  SynoFmKrnR=$(uname --kernel-release)
  SynoFmKLcs=$(echo "$SynoFmKern" | awk '{ print tolower($0) }')
  SynoBashVr=$(bash --version | head -n 1 | awk '{print $4}')
  SynoTmZone=$(readlink /etc/localtime | sed 's|/usr/share/zoneinfo/||')

  SynoAdminX=$(synouser --get admin | grep "Expired" | awk -F "[][{}]" '{ print $2 }')
  if [ "$SynoAdminX" = "true" ]; then
    SynoAdminX="Disabled"
  elif [ "$SynoAdminX" = "false" ]; then
    SynoAdminX="Enabled (SECURITY RISK)"
  else
    SynoAdminX="Unknown (???)"
  fi

  SynoIntrIP=$(ip -f inet -o addr show eth0 | awk '{ print $4 }' | cut -d/ -f1)
  SynoExtrIP=$(ping -c 1 myip.opendns.com | awk -F "[()]" '/PING/ { print $2 }')
}

# Function to get Plex Media Server information
get_plex_info() {
  PlexMSVers=$(/usr/syno/bin/synopkg version "PlexMediaServer")
  PlexTarget=$(readlink /var/packages/PlexMediaServer/target)
  PlexAppBin="$PlexTarget"
  PlexShares=$(readlink /var/packages/PlexMediaServer/shares/PlexMediaServer)
  PlexFolder="$PlexShares"
  PlexFolder="$PlexFolder/AppData/Plex Media Server"
  PlexTransc=$("$PlexAppBin/Plex Transcoder" -version -hide_banner | head -n 1 | cut -d " " -f 1)
  PlexTransV=$("$PlexAppBin/Plex Transcoder" -version -hide_banner | head -n 1 | cut -d " " -f 3)
  PlexCodecs="$PlexFolder/Codecs"
  PlexFVCdcs=$(find "$PlexFolder/Codecs" -type d -name "$PlexTransV-$SynoFmKLcs-$SynoFmArch")
  PlexDevcID=$(head -n 1 "$PlexCodecs/.device-id")
  PlexFrName=$(grep -oP "FriendlyName=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
  PlexOToken=$(grep -oP "PlexOnlineToken=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
  PlexMachID=$(grep -oP "ProcessedMachineIdentifier=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
  PlexChannl=$(grep -oP "ButlerUpdateChannel=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
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
  PlexAutoET=$(grep -oP "autoEmptyTrash=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
  if [ -z "$PlexAutoET" ]; then
    PlexAutoET="Not Automatic"
  else
    if [ "$PlexAutoET" -eq "0" ]; then
      PlexAutoET="Not Automatic"
    elif [ "$PlexAutoET" -eq "1" ]; then
      PlexAutoET="Automatic (DISCONNECTION RISK)"
    else
      PlexAutoET="Undefined (???)"
    fi
  fi
}

# Function to summarize data
print_summary() {
  # PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
  printf "\n"
  printf "%s\n" "SYNO.PLEX INFO SCRIPT for DSM 7"
  printf "\n"

  # Call functions to gather information
  get_dsm_version
  get_nas_info
  get_plex_info

  # Print the collected information
  printf "SYNOLOGY NAS INFO:\n"
  printf "%s\n" "---------------"
  printf "       Nodename: %s\n" "$SynoNodenm"
  printf "        DSM ver: %s\n" "$SynoDSMVer"
  printf "          Model: %s\n" "$SynoHModel"
  printf "   Architecture: %s (%s)\n" "$SynoFmArch" "$SynoFmProc"
  printf "         Kernel: %s (%s)\n" "$SynoFmKern" "$SynoFmKrnR"
  printf "           Bash: %s\n" "$SynoBashVr"
  printf "      Time Zone: %s\n" "$SynoTmZone"
  printf "  Admin account: %s\n" "$SynoAdminX"
  printf "    Internal IP: %s\n" "$SynoIntrIP"
  printf "    External IP: %s\n" "$SynoExtrIP"
  printf "\n"

  printf "PLEX MEDIA SERVER INFO:\n"
  printf "%s\n" "---------------"
  printf "  Friendly Name: %s\n" "$PlexFrName"
  printf "        PMS ver: %s\n" "$PlexMSVers"
  printf " Update Channel: %s\n" "$PlexChannl"
  printf "    Empty Trash: %s\n" "$PlexAutoET"
  printf "     Transcoder: %s (%s)\n" "$PlexTransc" "$PlexTransV"

  printf "\n"
  printf "PLEX MEDIA SERVER ID (DO NOT SHARE):\n"
  printf "%s\n" "---------------"
  printf "      Device-ID: %s\n" "$PlexDevcID"
  printf "     Machine-ID: %s\n" "$PlexMachID"
  printf "   Online Token: %s\n" "$PlexOToken"
  printf "\n"

  printf "PLEX DIRECTORY REFERENCE:\n"
  printf "%s\n" "---------------"
  [ -d "$PlexAppBin"                 ] && printf "'%s'\n" "$PlexAppBin"
  [ -d "$PlexFolder"                 ] && printf "'%s'\n" "$PlexFolder"
  [ -d "$PlexFolder/Codecs"          ] && printf "  \"  \'/Codecs\'\n"
  [ -d "$PlexFVCdcs"                 ] && printf "  \"  \'/Codecs/%s-%s-%s\'\n" "$PlexTransV" "$SynoFmKLcs" "$SynoFmArch"
  [ -d "$PlexFolder/Logs"            ] && printf "  \"  \'/Logs\'\n"
  [ -d "$PlexFolder/Plug-ins"        ] && printf "  \"  \'/Plug-ins\'\n"
  [ -d "$PlexFolder/Plug-in Support" ] && printf "  \"  \'/Plug-in Support\'\n"
  [ -d "$PlexFolder/Scanners"        ] && printf "  \"  \'/Scanners\'\n"
  [ -d "$PlexFolder/Scanners/Common" ] && printf "  \"  \'/Scanners/Common\'\n"
  [ -d "$PlexFolder/Scanners/Series" ] && printf "  \"  \'/Scanners/Series\'\n"
  printf "%s\n" "---------------"
  printf "\n"
}

# Print the summary
print_summary
