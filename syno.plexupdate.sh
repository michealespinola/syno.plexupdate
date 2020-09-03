#!/bin/bash
#
# Script to automagically update Plex Media Server on Synology NAS
# Must be run as root to natively control running services.
#
# Author @michealespinola https://github.com/michealespinola
# https://github.com/michealespinola/plexupdate
#
# Forked from @martinorob https://github.com/martinorob
# https://github.com/martinorob/plexupdate/
#
# Example Task 'user-defined script': bash /var/services/homes/admin/scripts/bash/plex/plexupdate/plexupdate.sh
#
########## USER CONFIGURABLE VARIABLES ####################
# A NEW UPDATE MUST BE THIS MANY DAYS OLD
MinimumAge=7
#SAVED PACKAGES DELETED IF OLDER THAN THIS MANY DAYS
OldUpdates=60

########## NOTHING WORTH MESSING WITH BELOW HERE ##########
# PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
printf "\n"
printf "%s\n" "SYNO.PLEX UPDATER SCRIPT v2.3.1"
printf "\n"

# CHECK IF ROOT
if [ "$EUID" -ne "0" ]; then
  printf " %s\n" "This script MUST be run as root - exiting..."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server update failed via Plex Update task. Script was not run as root."}'
  printf "\n"
  exit 1
fi

# SCRAPE DSM VERSION AND CHECK COMPATIBILITY
DSMVersion=$(                   more /etc.defaults/VERSION | grep -i 'productversion=' | cut -d"\"" -f 2)
dpkg --compare-versions "5" gt "$DSMVersion"
if [ "$?" -eq "0" ]; then
  printf " %s\n" "Plex Media Server requires DSM 5.0 minimum to install - exiting..."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server update failed via Plex Update task. DSM not at least version 5.0."}'
  printf "\n"
  exit 1
fi
DSMVersion=$(echo $DSMVersion-$(more /etc.defaults/VERSION | grep -i 'buildnumber='    | cut -d"\"" -f 2))
DSMUpdateV=$(                   more /etc.defaults/VERSION | grep -i 'smallfixnumber=' | cut -d"\"" -f 2)
if [ -n "$DSMUpdateV" ]; then
  DSMVersion=$(echo $DSMVersion Update $DSMUpdateV)
fi
# SCRAPE SYNOLOGY HARDWARE MODEL
SynoHModel=$(more /proc/sys/kernel/syno_hw_version)
# SCRAPE SYNOLOGY CPU ARCHITECTURE FAMILY
ArchFamily=$(uname -m)
# SCRAPE SCRIPT FOLDER LOCATION
SPUSFolder=$(dirname "$0")
# SCRAPE PMS FOLDER LOCATION AND CREATE UPDATES DIR W/OLD FILE CLEANUP
PlexFolder=$(echo $PlexFolder | /usr/syno/bin/synopkg log "Plex Media Server")
PlexFolder=$(echo ${PlexFolder%/Logs/Plex Media Server.log})
PlexFolder=/$(echo ${PlexFolder#*/})
if [ -d "$PlexFolder/Updates" ]; then
  find "$PlexFolder/Updates" -type f -name "*.spk" -mtime +$OldUpdates -delete
else
  mkdir "$PlexFolder/Updates"
fi
# SCRAPE PLEX ONLINE TOKEN
PlexOToken=$(cat "$PlexFolder/Preferences.xml" | grep -oP 'PlexOnlineToken="\K[^"]+')
# SCRAPE PLEX SERVER UPDATE CHANNEL
PlexChannl=$(cat "$PlexFolder/Preferences.xml" | grep -oP 'ButlerUpdateChannel="\K[^"]+')
if [ -z "${PlexChannl+x}" ]; then
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
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server update failed to indentify Server Update Channel (Public, Beta, etc)."}'
    printf "\n"
    exit 1
  fi
fi

# SCRAPE UPDATE CHANNEL FOR UPDATE INFO
DistroJson=$(curl -s $ChannelUrl)
NewVersion=$(echo $DistroJson | jq                                -r '.nas.Synology.version')
NewVerDate=$(echo $DistroJson | jq                                -r '.nas.Synology.release_date')
NewDwnlUrl=$(echo $DistroJson | jq --arg ArchFamily "$ArchFamily" -r '.nas.Synology.releases[] | select(.build == "linux-"+$ArchFamily) | .url'); NewPackage="${NewDwnlUrl##*/}"
# CALCULATE NEW PACKAGE AGE FROM RELEASE DATE
TodaysDate=$(date --date "now" +'%s')
PackageAge=$((($TodaysDate-$NewVerDate)/86400))
# SCRAPE CURRENTLY RUNNING PMS VERSION
RunVersion=$(synopkg version "Plex Media Server")

# PRINT STATUS/DEBUG INFO
printf "%14s %s\n"         "Synology:" "$SynoHModel ($ArchFamily), DSM $DSMVersion"
printf "%14s %s\n"       "Script Dir:" "$SPUSFolder"
printf "%14s %s\n"         "Plex Dir:" "$PlexFolder"
printf "%14s %s\n"       "Plex Token:" "$PlexOToken"
printf "%14s %s\n"      "Running Ver:" "$RunVersion"
printf "%14s %s %s\n"    "Update Ver:" "$NewVersion" "($ChannlName Channel)"
printf "%14s %s\n"     "Release Date:" "$(date --rfc-2822 --date @$NewVerDate)"
printf "\n"

# COMPARE VERSIONS
dpkg --compare-versions "$NewVersion" gt "$RunVersion"
if [ "$?" -eq "0" ]; then
  printf " %s\n" "Newer version found!"
  printf "\n"
  printf "%14s %s\n"      "New Package:" "$NewPackage"
  printf "%14s %s"        "Package Age:" "$PackageAge"
  if [ "$PackageAge" -eq "1" ]; then
    printf " %s" "day"
  else
    printf " %s" "days"
  fi
  printf " %s\n" "($MinimumAge required for install)"
  printf "\n"

  # INSTALL THE UPDATE
  if [ $PackageAge -ge $MinimumAge ]; then
    printf "%s\n" "INSTALLING NEW PACKAGE:"
    printf "%s\n" "----------------------------------------"
    /bin/wget $NewDwnlUrl -q -c -nc -P "$PlexFolder/Updates/"
    /usr/syno/bin/synopkg stop    "Plex Media Server"
    /usr/syno/bin/synopkg install "$PlexFolder/Updates/$NewPackage"
    /usr/syno/bin/synopkg start   "Plex Media Server"
    printf "%s\n" "----------------------------------------"
    printf "\n"
    NowVersion=$(synopkg version "Plex Media Server")
    printf "%14s %s\n"      "Update from:" "$RunVersion"
    printf "%14s %s"                 "to:" "$NewVersion"

    # REPORT UPDATE STATUS
    dpkg --compare-versions "$NowVersion" gt "$RunVersion"
    if [ "$?" -eq "0" ]; then
      printf " %s\n" "succeeded!"
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server update succeeded via Plex Update task"}'
      ExitStatus=1
    else
      printf " %s\n" "failed!"
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server update failed via Plex Update task"}'
      ExitStatus=1
    fi
  else
    printf " %s\n" "Update newer than $MinimumAge days - skipping..."
  fi
else
  printf " %s\n" "No new version found."
fi
  printf "\n"
exit $ExitStatus
