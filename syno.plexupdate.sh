#!/bin/bash

# A script to automagically update Plex Media Server on Synology NAS
# This must be run as root to natively control running services
#
# Author @michealespinola https://github.com/michealespinola/syno.plexupdate
#
# Update concept via https://github.com/martinorob/plexupdate/
#
# Example Task 'user-defined script': 
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh

# SCRIPT VERSION
SPUScrpVer=3.0.2
MinDSMVers=6.0
# PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
printf "\n"
printf "%s\n" "SYNO.PLEX UPDATE SCRIPT v$SPUScrpVer"
printf "\n"

# CHECK IF ROOT
if [ "$EUID" -ne "0" ]; then
  printf " %s\n" "* This script MUST be run as root - exiting..."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Script was not run as root."}'
  printf "\n"
  exit 1
fi

# SCRAPE SCRIPT PATH INFO
SPUSFllPth=$(readlink -f "$0")
SPUSFolder=$(dirname "$SPUSFllPth")
SPUSFileNm=${SPUSFllPth##*/}

#CHECK IF CONFIG FILE EXISTS, IF NOT CREATE IT
if [ ! -f "$SPUSFolder/config.ini" ]; then
  printf " %s\n\n" "* CONFIGURATION FILE (config.ini) IS MISSING, CREATING DEFAULT SETUP..."
  printf "%s\n"    "# A NEW UPDATE MUST BE THIS MANY DAYS OLD"                              >  "$SPUSFolder/config.ini"
  printf "%s\n"    "MinimumAge=7"                                                           >> "$SPUSFolder/config.ini"
  printf "%s\n"    "# PREVIOUSLY DOWNLOADED PACKAGES DELETED IF OLDER THAN THIS MANY DAYS"  >> "$SPUSFolder/config.ini"
  printf "%s\n"    "OldUpdates=60"                                                          >> "$SPUSFolder/config.ini"
  printf "%s\n"    "# NETWORK TIMEOUT IN SECONDS (900s = 15m)"                              >> "$SPUSFolder/config.ini"
  printf "%s\n"    "NetTimeout=900"                                                         >> "$SPUSFolder/config.ini"
  printf "%s\n"    "# SCRIPT WILL SELF-UPDATE IF SET TO 1"                                  >> "$SPUSFolder/config.ini"
  printf "%s\n"    "SelfUpdate=0"                                                           >> "$SPUSFolder/config.ini"
  ExitStatus=1
fi
if [ -f "$SPUSFolder/config.ini" ]; then
  . "$SPUSFolder/config.ini"
fi

#CHECK IF SCRIPT IS ARCHIVED
if [ ! -d "$SPUSFolder/Archive/Scripts" ]; then
  mkdir -p "$SPUSFolder/Archive/Scripts"
fi
if [ ! -f "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh" ]; then
  cp "$SPUSFllPth" "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
else
  cmp -s "$SPUSFllPth" "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
  if [ "$?" -ne "0" ]; then
    cp "$SPUSFllPth" "$SPUSFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
  fi
fi

# GET EPOCH TIMESTAMP FOR AGE CHECKS
TodaysDate=$(date --date "now" +'%s')

# SCRAPE GITHUB FOR UPDATE INFO
SPUSRelHtm=$(curl -m $NetTimeout -L -s https://github.com/michealespinola/syno.plexupdate/releases/latest)
if [ "$?" -eq "0" ]; then
  SPUSZipLnk=https://github.com/$(echo $SPUSRelHtm | grep -oP '\<title\>Release v\d{1,}\.\d{1,}(\.\d{1,})?(\.\d{1,})?')
  SPUSZipFil=${SPUSZipLnk##*/}
  SPUSZipVer=$(echo $SPUSZipFil | grep -oP '\d{1,}\.\d{1,}\.\d{1,}')
  SPUSGtDate=$(echo $SPUSRelHtm | grep -oP 'relative-time datetime="\K[^"]+')
  SPUSRlDate=$(date --date "$SPUSGtDate" +'%s')
  SPUSRelAge=$((($TodaysDate-$SPUSRlDate)/86400))
  SPUSDwnUrl=https://raw.githubusercontent.com/michealespinola/syno.plexupdate/v$SPUSZipVer/syno.plexupdate.sh
else
  printf " %s\n\n" "* UNABLE TO CHECK FOR LATEST VERSION OF SCRIPT..."
  ExitStatus=1
fi

# PRINT SCRIPT STATUS/DEBUG INFO
printf "%16s %s\n"           "Script:" "$SPUSFileNm v$SPUScrpVer"
printf "%16s %s\n"       "Script Dir:" "$SPUSFolder"
printf "%16s %s\n"      "Running Ver:" "$SPUScrpVer"
if [ "$SPUSZipVer" != "" ]; then
  printf "%16s %s\n"     "Online Ver:" "$SPUSZipVer"
  printf "%16s %s\n"       "Released:" "$(date --rfc-3339 seconds --date @$SPUSRlDate) ($SPUSRelAge+ days old)"
fi

# COMPARE SCRIPT VERSIONS
/usr/bin/dpkg --compare-versions "$SPUSZipVer" gt "$SPUScrpVer"
if [ "$?" -eq "0" ]; then
  printf "                 %s\n" "* Newer version found!"

  # DOWNLOAD AND INSTALL THE SCRIPT UPDATE
  if [ "$SelfUpdate" -eq "1" ]; then
    if [ $SPUSRelAge -ge $MinimumAge ]; then
      printf "\n"
      printf "%s\n" "INSTALLING NEW SCRIPT:"
      printf "%s\n" "----------------------------------------"
      /bin/wget $SPUSDwnUrl -nv -O "$SPUSFolder/Archive/Scripts/$SPUSFileNm"
      if [ "$?" -eq "0" ]; then
        # MAKE A COPY FOR UPGRADE COMPARISON BECAUSE WE ARE GOING TO MOVE NOT COPY THE NEW FILE
        cp -f "$SPUSFolder/Archive/Scripts/$SPUSFileNm" "$SPUSFolder/Archive/Scripts/$SPUSFileNm.cmp"
        # MOVE-OVERWRITE INSTEAD OF COPY-OVERWRITE TO NOT CORRUPT RUNNING IN-MEMORY VERSION OF SCRIPT
        mv -f "$SPUSFolder/Archive/Scripts/$SPUSFileNm" "$SPUSFolder/$SPUSFileNm"
        printf "%s\n" "----------------------------------------"
        cmp -s "$SPUSFolder/Archive/Scripts/$SPUSFileNm.cmp" "$SPUSFolder/$SPUSFileNm"
        if [ "$?" -eq "0" ]; then
          printf "                 %s\n" "* Script update succeeded!"
          /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update completed successfully"}'
          ExitStatus=1
        else
          printf "                 %s\n" "* Script update failed to overwrite."
          /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update failed."}'
          ExitStatus=1
        fi
      else
        printf "                 %s\n" "* Script update failed to download."
        /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update failed to download."}'
        ExitStatus=1
      fi
    else
      printf " \n%s\n" "Update newer than $MinimumAge days - skipping..."
    fi
    # DELETE TEMP COMPARISON FILE
    find "$SPUSFolder/Archive/Scripts" -type f -name "$SPUSFileNm.cmp" -delete
  fi

else
  printf "                 %s\n" "* No new version found."
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
/usr/bin/dpkg --compare-versions "$MinDSMVers" gt "$DSMVersion"
if [ "$?" -eq "0" ]; then
  printf " %s\n" "* Plex Media Server for $SynoHModel requires DSM $MinDSMVers minimum to install - exiting..."
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
RunVersion=$(echo $RunVersion | grep -oP '^.+?(?=\-)')

# SCRAPE PMS FOLDER LOCATION AND CREATE ARCHIVED PACKAGES DIR W/OLD FILE CLEANUP
PlexFolder=$(echo $PlexFolder | /usr/syno/bin/synopkg log "Plex Media Server")
PlexFolder=$(echo ${PlexFolder%/Logs/Plex Media Server.log})
PlexFolder=/$(echo ${PlexFolder#*/})
if [ -d "$PlexFolder/Updates" ]; then
  mv -f "$PlexFolder/Updates/"* "$SPUSFolder/Archive/Packages/" 2>/dev/null
  if [ -n "$(find "$PlexFolder/Updates/" -prune -empty) 2>/dev/null" ]; then
    rmdir "$PlexFolder/Updates/"
  fi
fi
if [ -d "$SPUSFolder/Archive/Packages" ]; then
  find "$SPUSFolder/Archive/Packages" -type f -name "PlexMediaServer*.spk" -mtime +$OldUpdates -delete
else
  mkdir -p "$SPUSFolder/Archive/Packages"
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

# SCRAPE PLEX FOR UPDATE INFO
DistroJson=$(curl -m $NetTimeout -L -s $ChannelUrl)
if [ "$?" -eq "0" ]; then
  NewVersion=$(echo $DistroJson | jq                                -r '.nas.Synology.version')
  NewVersion=$(echo $NewVersion | grep -oP '^.+?(?=\-)')
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

# UPDATE LOCAL VERSION CHANGELOG
grep -q         "Version $NewVersion ($(date --rfc-3339 seconds --date @$NewVerDate))"    "$SPUSFolder/Archive/Packages/changelog.txt" 2>/dev/null
if [ "$?" -ne "0" ]; then
  printf "%s\n" "Version $NewVersion ($(date --rfc-3339 seconds --date @$NewVerDate))" >  "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" "$ChannlName Channel"                                                  >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" ""                                                                     >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" "New Features:"                                                        >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" "$NewVerAddd" | awk '{ print "* " $0 }'                                >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" ""                                                                     >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" "Fixed Features:"                                                      >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" "$NewVerFixd" | awk '{ print "* " $0 }'                                >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" ""                                                                     >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" "----------------------------------------"                             >> "$SPUSFolder/Archive/Packages/changelog.new"
  printf "%s\n" ""                                                                     >> "$SPUSFolder/Archive/Packages/changelog.new"
  if [ -f "$SPUSFolder/Archive/Packages/changelog.new" ]; then
    if [ -f "$SPUSFolder/Archive/Packages/changelog.txt" ]; then
      mv    "$SPUSFolder/Archive/Packages/changelog.txt" "$SPUSFolder/Archive/Packages/changelog.tmp"
      cat   "$SPUSFolder/Archive/Packages/changelog.new" "$SPUSFolder/Archive/Packages/changelog.tmp" > "$SPUSFolder/Archive/Packages/changelog.txt"
    else
      mv    "$SPUSFolder/Archive/Packages/changelog.new" "$SPUSFolder/Archive/Packages/changelog.txt"    
    fi
  fi
fi
rm "$SPUSFolder/Archive/Packages/changelog.new" "$SPUSFolder/Archive/Packages/changelog.tmp" 2>/dev/null

# PRINT PLEX STATUS/DEBUG INFO
printf "%16s %s\n"         "Synology:" "$SynoHModel ($ArchFamily), DSM $DSMVersion"
printf "%16s %s\n"         "Plex Dir:" "$PlexFolder"
printf "%16s %s\n"       "Plex Token:" "$PlexOToken"
printf "%16s %s\n"      "Running Ver:" "$RunVersion"
if [ "$NewVersion" != "" ]; then
  printf "%16s %s\n"     "Online Ver:" "$NewVersion ($ChannlName Channel)"
  printf "%16s %s\n"       "Released:" "$(date --rfc-3339 seconds --date @$NewVerDate) ($PackageAge+ days old)"
fi

# COMPARE PLEX VERSIONS
/usr/bin/dpkg --compare-versions "$NewVersion" gt "$RunVersion"
if [ "$?" -eq "0" ]; then
  printf "                 %s\n" "* Newer version found!"
  printf "\n"
  printf "%16s %s\n"      "New Package:" "$NewPackage"
  printf "%16s %s\n"      "Package Age:" "$PackageAge+ days old ($MinimumAge+ required for install)"
  printf "\n"

  # DOWNLOAD AND INSTALL THE PLEX UPDATE
  if [ $PackageAge -ge $MinimumAge ]; then
    printf "%s\n" "INSTALLING NEW PACKAGE:"
    printf "%s\n" "----------------------------------------"
    /bin/wget $NewDwnlUrl -nv -c -nc -P "$SPUSFolder/Archive/Packages/"
    if [ "$?" -eq "0" ]; then
      /usr/syno/bin/synopkg stop    "Plex Media Server"
      printf "\n"
      /usr/syno/bin/synopkg install "$SPUSFolder/Archive/Packages/$NewPackage"
      printf "\n"
      /usr/syno/bin/synopkg start   "Plex Media Server"
    else
      printf "\n %s\n" "* Package download failed, skipping install..."
    fi
    printf "%s\n" "----------------------------------------"
    printf "\n"
    NowVersion=$(/usr/syno/bin/synopkg version "Plex Media Server")
    printf "%16s %s\n"      "Update from:" "$RunVersion"
    printf "%16s %s"                 "to:" "$NewVersion"

    # REPORT PLEX UPDATE STATUS
    /usr/bin/dpkg --compare-versions "$NowVersion" gt "$RunVersion"
    if [ "$?" -eq "0" ]; then
      printf " %s\n" "succeeded!"
      printf "\n"
      if [ ! -z "$NewVerAddd" ]; then
        # SHOW NEW PLEX FEATURES
        printf "%s\n" "NEW FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerAddd" | awk '{ print "* " $0 }'
        printf "%s\n" "----------------------------------------"
      fi
      printf "\n"
      if [ ! -z "$NewVerFixd" ]; then
        # SHOW FIXED PLEX FEATURES
        printf "%s\n" "FIXED FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerFixd" | awk '{ print "* " $0 }'
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
  printf "                 %s\n" "* No new version found."
fi
  printf "\n"
# EXIT NORMALLY BUT POSSIBLY WITH FORCED EXIT STATUS FOR SCRIPT NOTIFICATIONS
exit $ExitStatus
