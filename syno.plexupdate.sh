#!/bin/bash
#
# Script to automagically update Plex Media Server on Synology NAS
# Must be run as root to natively control running services.
#
# Author @michealespinola https://github.com/michealespinola
# https://github.com/michealespinola/syno.plexupdate
#
# Originally forked from @martinorob https://github.com/martinorob
# https://github.com/martinorob/plexupdate/
#
# Example Task 'user-defined script': 
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh
#
########## USER CONFIGURABLE VARIABLES ####################
###########################################################
# A NEW UPDATE MUST BE THIS MANY DAYS OLD
MinimumAge=7
# SAVED PACKAGES DELETED IF OLDER THAN THIS MANY DAYS
OldUpdates=60

########## NOTHING WORTH MESSING WITH BELOW HERE ##########
###########################################################
# SCRIPT VERSION
SPUScrpVer=2.9.9
MinDSMVers=6.0
# PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
printf "\n"
printf "%s\n" "SYNO.PLEX UPDATER SCRIPT v$SPUScrpVer"
printf "\n"

# CHECK IF ROOT
if [ "$EUID" -ne "0" ]; then
  printf " %s\n" "This script MUST be run as root - exiting..."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Script was not run as root."}'
  printf "\n"
  exit 1
fi

# GET EPOCH TIMESTAMP FOR AGE CHECKS
TodaysDate=$(date --date "now" +'%s')

# SCRAPE SCRIPT PATH INFO
SPUSFllPth=$(readlink -f "$0")
SPUSFolder=$(dirname "$SPUSFllPth")
SPUSFileNm=${SPUSFllPth##*/}

#CHECK IF SCRIPT IS ARCHIVED
if [ ! -d "$SPUSFolder/Archive/Scripts" ]; then
  mkdir "$SPUSFolder/Archive/Scripts"
fi
if [ ! -f "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh" ]; then
  cp "$SPUSFllPth" "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
else
  cmp -s "$SPUSFllPth" "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
  if [ "$?" -ne "0" ]; then
    cp "$SPUSFllPth" "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
  fi
fi

# SCRAPE GITHUB FOR UPDATE INFO (15 MINUTE TIMEOUT)
SPUSRelHtm=$(curl -m 900 -L -s https://github.com/michealespinola/syno.plexupdate/releases/latest)
if [ "$?" -eq "0" ]; then
  SPUSZipLnk=https://github.com/$(echo $SPUSRelHtm | grep -oP 'michealespinola\/syno.plexupdate\/archive\/v\d{1,}\.\d{1,}\.\d{1,}\.zip')
  SPUSZipFil=${SPUSZipLnk##*/}
  SPUSZipVer=$(echo $SPUSZipFil | grep -oP '\d{1,}\.\d{1,}\.\d{1,}')
  SPUSGtDate=$(echo $SPUSRelHtm | grep -oP 'relative-time datetime="\K[^"]+')
  SPUSRlDate=$(date --date "$SPUSGtDate" +'%s')
  SPUSRelAge=$((($TodaysDate-$SPUSRlDate)/86400))
else
  printf " %s\n" "* UNABLE TO CHECK FOR LATEST VERSION OF SCRIPT..."
  printf "\n"
  ExitStatus=1
fi

# PRINT SCRIPT STATUS/DEBUG INFO
printf "%14s %s\n"           "Script:" "$SPUSFileNm v$SPUScrpVer"
printf "%14s %s\n"       "Script Dir:" "$SPUSFolder"
printf "%14s %s\n"      "Running Ver:" "$SPUScrpVer"
if [ "$SPUSZipVer" != "" ]; then
  printf "%14s %s\n"     "Online Ver:" "$SPUSZipVer"
  printf "%14s %s\n"       "Released:" "$(date --rfc-3339 seconds --date @$SPUSRlDate) ($SPUSRelAge+ days old)"
fi

# COMPARE SCRIPT VERSIONS
dpkg --compare-versions "$SPUSZipVer" gt "$SPUScrpVer"
if [ "$?" -eq "0" ]; then
  printf "             %s\n" "* Newer version found!"
else
  printf "             %s\n" "* No new version found."
fi
printf "\n"

# SCRAPE SYNOLOGY HARDWARE MODEL
SynoHModel=$(cat /proc/sys/kernel/syno_hw_version)
# SCRAPE SYNOLOGY CPU ARCHITECTURE FAMILY
ArchFamily=$(uname -m)
# SCRAPE DSM VERSION AND CHECK COMPATIBILITY
DSMVersion=$(                   cat /etc.defaults/VERSION | grep -i 'productversion=' | cut -d"\"" -f 2)
# CHECK IF X86 MODEL
if [ "$SynoHModel" == "DS214Play" ] || [ "$SynoHModel" == "DS415Play" ]; then
  MinDSMVers=5.2
fi
dpkg --compare-versions "$MinDSMVers" gt "$DSMVersion"
if [ "$?" -eq "0" ]; then
  printf " %s\n" "Plex Media Server $SynoHModel for requires DSM $MinDSMVers minimum to install - exiting..."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. DSM not sufficient version."}'
  printf "\n"
  exit 1
fi
DSMVersion=$(echo $DSMVersion-$(cat /etc.defaults/VERSION | grep -i 'buildnumber='    | cut -d"\"" -f 2))
DSMUpdateV=$(                   cat /etc.defaults/VERSION | grep -i 'smallfixnumber=' | cut -d"\"" -f 2)
if [ -n "$DSMUpdateV" ]; then
  DSMVersion=$(echo $DSMVersion Update $DSMUpdateV)
fi

# SCRAPE CURRENTLY RUNNING PMS VERSION
RunVersion=$(/usr/syno/bin/synopkg version "Plex Media Server")
# SCRAPE PMS FOLDER LOCATION AND CREATE ARCHIVED PACKAGES DIR W/OLD FILE CLEANUP
PlexFolder=$(echo $PlexFolder | /usr/syno/bin/synopkg log "Plex Media Server")
PlexFolder=$(echo ${PlexFolder%/Logs/Plex Media Server.log})
PlexFolder=/$(echo ${PlexFolder#*/})
if [ -d "$PlexFolder/Updates" ]; then
  mv "$PlexFolder/Updates/"* "$SPUSFolder/Archive/Packages/" 2>/dev/null
  if [ -n "$(find "$PlexFolder/Updates/" -prune -empty) 2>/dev/null" ]; then
    rmdir "$PlexFolder/Updates/"
  fi
fi
if [ -d "$SPUSFolder/Archive/Packages" ]; then
  find "$SPUSFolder/Archive/Packages" -type f -name "PlexMediaServer*.spk" -mtime +$OldUpdates -delete
else
  mkdir "$SPUSFolder/Archive/Packages"
fi

# SCRAPE PLEX ONLINE TOKEN
PlexOToken=$(cat "$PlexFolder/Preferences.xml" | grep -oP 'PlexOnlineToken="\K[^"]+')
# SCRAPE PLEX SERVER UPDATE CHANNEL
PlexChannl=$(cat "$PlexFolder/Preferences.xml" | grep -oP 'ButlerUpdateChannel="\K[^"]+')
if [ -z "$PlexChannl" ]; then
  # DEFAULT TO PUBLIC SERVER UPDATE CHANNEL IF NULL (NEVER SET) VALUE
  ChannlName=Public
  ChannelUrl=$(echo "https://plex.tv/api/downloads/5.json")
else
  if [ "$PlexChannl" -eq "0" ]; then
    # PUBLIC SERVER UPDATE CHANNEL
    ChannlName=Public
    ChannelUrl=$(echo "https://plex.tv/api/downloads/5.json")
  elif [ "$PlexChannl" -eq "8" ]; then
    # BETA SERVER UPDATE CHANNEL (REQUIRES PLEX PASS)
    ChannlName=Beta
    ChannelUrl=$(echo "https://plex.tv/api/downloads/5.json?channel=plexpass&X-Plex-Token=$PlexOToken")
  else
    # REPORT ERROR IF UNRECOGNIZED CHANNEL SELECTION
    printf " %s\n" "Unable to indentify Server Update Channel (Public, Beta, etc) - exiting..."
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Could not identify update channel (Public, Beta, etc)."}'
    printf "\n"
    exit 1
  fi
fi

# SCRAPE PLEX FOR UPDATE INFO (15 MINUTE TIMEOUT)
DistroJson=$(curl -m 900 -L -s $ChannelUrl)
if [ "$?" -eq "0" ]; then
  NewVersion=$(echo $DistroJson | jq                                -r '.nas.Synology.version')
  NewVerDate=$(echo $DistroJson | jq                                -r '.nas.Synology.release_date')
  NewVerAddd=$(echo $DistroJson | jq                                -r '.nas.Synology.items_added')
  NewVerFixd=$(echo $DistroJson | jq                                -r '.nas.Synology.items_fixed')
  NewDwnlUrl=$(echo $DistroJson | jq --arg ArchFamily "$ArchFamily" -r '.nas.Synology.releases[] | select(.build == "linux-"+$ArchFamily) | .url'); NewPackage="${NewDwnlUrl##*/}"
  # CALCULATE NEW PACKAGE AGE FROM RELEASE DATE
  PackageAge=$((($TodaysDate-$NewVerDate)/86400))
else
  printf " %s\n" "* UNABLE TO CHECK FOR LATEST VERSION OF PLEX MEDIA SERVER..."
  printf "\n"
  ExitStatus=1
fi

# PRINT PLEX STATUS/DEBUG INFO
printf "%14s %s\n"         "Synology:" "$SynoHModel ($ArchFamily), DSM $DSMVersion"
printf "%14s %s\n"         "Plex Dir:" "$PlexFolder"
printf "%14s %s\n"       "Plex Token:" "$PlexOToken"
printf "%14s %s\n"      "Running Ver:" "$RunVersion"
if [ "$NewVersion" != "" ]; then
  printf "%14s %s\n"     "Online Ver:" "$NewVersion ($ChannlName Channel)"
  printf "%14s %s\n"       "Released:" "$(date --rfc-3339 seconds --date @$NewVerDate) ($PackageAge+ days old)"
fi

# COMPARE PLEX VERSIONS
dpkg --compare-versions "$NewVersion" gt "$RunVersion"
if [ "$?" -eq "0" ]; then
  printf "             %s\n" "* Newer version found!"
  printf "\n"
  printf "%14s %s\n"      "New Package:" "$NewPackage"
  printf "%14s %s\n"      "Package Age:" "$PackageAge+ days old ($MinimumAge+ required for install)"
  printf "\n"

  # DOWNLOAD AND INSTALL THE PLEX UPDATE
  if [ $PackageAge -ge $MinimumAge ]; then
    printf "%s\n" "INSTALLING NEW PACKAGE:"
    printf "%s\n" "----------------------------------------"
    /bin/wget $NewDwnlUrl -q -c -nc -P "$SPUSFolder/Archive/Packages/"
    if [ "$?" -eq "0" ]; then
      /usr/syno/bin/synopkg stop    "Plex Media Server"
      /usr/syno/bin/synopkg install "$SPUSFolder/Archive/Packages/$NewPackage"
      /usr/syno/bin/synopkg start   "Plex Media Server"
    else
      printf "\n %s\n" "* Package download failed, skipping install..."
    fi
    printf "%s\n" "----------------------------------------"
    printf "\n"
    NowVersion=$(/usr/syno/bin/synopkg version "Plex Media Server")
    printf "%14s %s\n"      "Update from:" "$RunVersion"
    printf "%14s %s"                 "to:" "$NewVersion"

    # REPORT PLEX UPDATE STATUS
    dpkg --compare-versions "$NowVersion" gt "$RunVersion"
    if [ "$?" -eq "0" ]; then
      printf " %s\n" "succeeded!"
      printf "\n"
      if [ ! -z "$NewVerAddd" ]; then
        # SHOW NEW PLEX FEATURES
        printf "%s\n" "NEW FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerAddd"
        printf "%s\n" "----------------------------------------"
      fi
      printf "\n"
      if [ ! -z "$NewVerFixd" ]; then
        # SHOW FIXED PLEX FEATURES
        printf "%s\n" "FIXED FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerFixd"
        printf "%s\n" "----------------------------------------"
      fi
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task completed successfully"}'
      ExitStatus=1
    else
      printf " %s\n" "failed!"
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Installation not newer version."}'
      ExitStatus=1
    fi
  else
    printf " %s\n" "Update newer than $MinimumAge days - skipping..."
  fi
else
  printf "             %s\n" "* No new version found."
fi
  printf "\n"
# EXIT NORMALLY BUT POSSIBLY WITH FORCED EXIT STATUS FOR SCRIPT NOTIFICATIONS
exit $ExitStatus
