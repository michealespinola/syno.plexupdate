#!/usr/bin/env bash
# shellcheck disable=SC2034
# SC1091,SC2004,SC2154,SC2181
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexinfo.sh

SCRIPT_VERSION=2.0.0

# Function to get Script information
get_src_info() {
  srcScrpVer=${SCRIPT_VERSION}                                                                    # Source Script Version
  srcFullPth=$(readlink -f "${BASH_SOURCE[0]}")                                                   # Source Script Absolute Path Of Script
  srcDirctry=$(dirname "$srcFullPth")                                                             # Source Script Directory Containing Script
  srcFileNam=${srcFullPth##*/}                                                                    # Source Script Script File Name
}

# Function to get NAS information
get_nas_info() {
  nasHwModel=$(cat /proc/sys/kernel/syno_hw_version)                                              # NAS Model
  nasMchArch=$(uname --machine)                                                                   # NAS Machine Architecture
  [ "$nasMchArch" = "i686" ] && nasMchArch=x86                                                    # "-" Override Match
  [ "$nasMchArch" = "armv7l" ] && nasMchArch=armv7neon                                            # "-" Override Match
  nasMchProc=$(uname --all | awk '{ print $NF }' | awk -F "_" '{ print $2 }')                     # NAS Processor Platform
  nasNodeNam=$(uname --nodename)                                                                  # NAS Network Hostname
  nasMchKern=$(uname --kernel-name)                                                               # NAS Kernel Name
  nasMchKver=$(uname --kernel-release)                                                            # NAS Kernel Version
  nasMchKlcs=$(echo "$nasMchKern" | awk '{ print tolower($0) }')                                  # NAS Kernel Name (lowercase)
  nasBashVer=$(bash --version | head -n 1 | awk '{print $4}')                                     # NAS Bash Version
  nasTimZone=$(readlink /etc/localtime | sed 's|/usr/share/zoneinfo/||')                          # NAS Time Zone Configuration
  nasAdminXp=$(synouser --get admin | grep "Expired" | awk -F "[][{}]" '{ print $2 }')            # NAS Admin Account Check
  if [ "$nasAdminXp" = "true" ]; then
    nasAdminXp="Disabled"
  elif [ "$nasAdminXp" = "false" ]; then
    nasAdminXp="Enabled (SECURITY RISK)"
  else
    nasAdminXp="Unknown (???)"
  fi
  nasIntrnIP=$(ip -f inet -o addr show eth0 | awk '{ print $4 }' | cut -d/ -f1)                   # NAS Internal IP Address (eth0)
  nasExtrnIP=$(ping -c 1 myip.opendns.com   | awk -F "[()]" '/PING/ { print $2 }')                # NAS External IP Address
}

# Function to get DSM information
get_dsm_info() {
  dsmPrdctNm=$(grep -i "productversion=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)               # DSM Product Version
  dsmBuildNm=$(grep -i "buildnumber="    "/etc.defaults/VERSION" | cut -d"\"" -f 2)               # DSM Build Number
  dsmMinorVr=$(grep -i "smallfixnumber=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)               # DSM Minor Version
  if [ -n "$dsmMinorVr" ]; then
    dsmFullVer="$dsmPrdctNm-$dsmBuildNm Update $dsmMinorVr"
  else
    dsmFullVer="$dsmPrdctNm-$dsmBuildNm"
  fi
}

# Function to get PMS Media Server information
get_pms_info() {
  pmsVersion=$(synopkg version "PlexMediaServer")                                                 # PMS Version
  pmsSTarget=$(readlink /var/packages/PlexMediaServer/target)                                     # PMS Target Symbolic Link
  pmsApplDir="$pmsSTarget"                                                                        # PMS Application Directory
  pmsSShares=$(readlink /var/packages/PlexMediaServer/shares/PlexMediaServer)                     # PMS Shares Symbolic Link
  pmsDataDir="$pmsSShares/AppData/Plex Media Server"                                              # PMS Data Directory
  pmsTrnscdr=$("$pmsApplDir/Plex Transcoder" -version -hide_banner | head -n 1 | cut -d " " -f 1) # PMS Transcoder App
  pmsTrnscdV=$("$pmsApplDir/Plex Transcoder" -version -hide_banner | head -n 1 | cut -d " " -f 3) # PMS Transcoder Version
  pmsCdcsDir="$pmsDataDir/Codecs"                                                                 # PMS Codecs Directory
  pmsCdcVDir=$(find "$pmsDataDir/Codecs" -type d -name "$pmsTrnscdV-$nasMchKlcs-$nasMchArch")     # PMS Transcoder Version Codecs Directory
  pmsFrnName=$(grep -oP "FriendlyName=\"\K[^\"]+" "$pmsDataDir/Preferences.xml")                  # PMS Friendly Name
  pmsDevicID=$(head -n 1 "$pmsCdcsDir/.device-id")                                                # PMS Device ID
  pmsMachnID=$(grep -oP "ProcessedMachineIdentifier=\"\K[^\"]+" "$pmsDataDir/Preferences.xml")    # PMS Machine ID
  pmsOnToken=$(grep -oP "PlexOnlineToken=\"\K[^\"]+" "$pmsDataDir/Preferences.xml")               # PMS Online Token
  pmsChannel=$(grep -oP "ButlerUpdateChannel=\"\K[^\"]+" "$pmsDataDir/Preferences.xml")           # PMS Update Channel
  if [ -z "$pmsChannel" ]; then
    pmsChannel=Public
  else
    if [ "$pmsChannel" -eq "0" ]; then
      pmsChannel=Public
    elif [ "$pmsChannel" -eq "8" ]; then
      pmsChannel=Beta
    else
      pmsChannel=Undefined
    fi
  fi
  pmsAutTrsh=$(grep -oP "autoEmptyTrash=\"\K[^\"]+" "$pmsDataDir/Preferences.xml")                # PMS Auto Empty Trash
  if [ -z "$pmsAutTrsh" ]; then
    pmsAutTrsh="Not Automatic"
  else
    if [ "$pmsAutTrsh" -eq "0" ]; then
      pmsAutTrsh="Not Automatic"
    elif [ "$pmsAutTrsh" -eq "1" ]; then
      pmsAutTrsh="Automatic (DISCONNECTION RISK)"
    else
      pmsAutTrsh="Undefined (???)"
    fi
  fi
}

# Function to summarize data
print_summary() {
  # PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
  printf "\n%s\n\n" "SYNO.PLEX INFO SCRIPT for DSM 7"

  # Call functions to gather information
  get_src_info
  get_nas_info
  get_dsm_info
  get_pms_info

  # Print the collected information
  printf "SYNOLOGY NAS INFO:\n"
  printf "%s\n" "---------------"
  printf '%16s %s\n'       "Nodename:" "$nasNodeNam"
  printf '%16s %s\n'        "DSM ver:" "$dsmFullVer"
  printf '%16s %s\n'          "Model:" "$nasHwModel"
  printf '%16s %s\n'   "Architecture:" "$nasMchArch ($nasMchProc)"
  printf '%16s %s\n'         "Kernel:" "$nasMchKern ($nasMchKver)"
  printf '%16s %s\n'           "Bash:" "$nasBashVer"
  printf '%16s %s\n'      "Time Zone:" "$nasTimZone"
  printf '%16s %s\n'  "Admin account:" "$nasAdminXp"
  printf '%16s %s\n'    "Internal IP:" "$nasIntrnIP"
  printf '%16s %s\n'    "External IP:" "$nasExtrnIP"
  printf "\n"

  printf "PLEX MEDIA SERVER INFO:\n"
  printf "%s\n" "---------------"
  printf '%16s %s\n'  "Friendly Name:" "$pmsFrnName"
  printf '%16s %s\n'        "PMS ver:" "$pmsVersion"
  printf '%16s %s\n' "Update Channel:" "$pmsChannel"
  printf '%16s %s\n'    "Empty Trash:" "$pmsAutTrsh"
  printf '%16s %s\n'     "Transcoder:" "$pmsTrnscdr ($pmsTrnscdV)"
  printf "\n"

  printf "PLEX DIRECTORY REFERENCE:\n"
  printf "%s\n" "---------------"
  [ -d "$pmsApplDir" ]                 && printf '%16s %s\n'  "Applications:" "$pmsApplDir"
  [ -d "$pmsDataDir" ]                 && printf '%16s %s\n'       "AppData:" "$pmsDataDir"
  [ -d "$pmsDataDir/Cache" ]           && printf '%16s %s\n'         "Cache:" " \" /Cache"
  [ -d "$pmsCdcVDir" ]                 && printf '%16s %s\n'        "Codecs:" " \" /Codecs/$pmsTrnscdV-$nasMchKlcs-$nasMchArch"
  [ -d "$pmsDataDir/Logs" ]            && printf '%16s %s\n' "Crash Reports:" " \" /Crash Reports"
  [ -d "$pmsDataDir/Logs" ]            && printf '%16s %s\n'          "Logs:" " \" /Logs"
  [ -d "$pmsDataDir/Plug-ins" ]        && printf '%16s %s\n'      "Plug-ins:" " \" /Plug-ins"
  [ -d "$pmsDataDir/Scanners" ]        && printf '%16s %s\n'      "Scanners:" " \" /Scanners"
  printf "\n"

  printf "PLEX MEDIA SERVER IDs (DO NOT SHARE):\n"
  printf "%s\n" "---------------"
  printf '%16s %s\n'      "Device-ID:" "$pmsDevicID"
  printf '%16s %s\n'     "Machine-ID:" "$pmsMachnID"
  printf '%16s %s\n'   "Online Token:" "$pmsOnToken"
  printf "%s\n" "---------------"
  printf "\n"
}

# Print the summary
print_summary
