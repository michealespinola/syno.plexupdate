#!/bin/bash
# shellcheck disable=SC2154,SC2181
# shellcheck source=/dev/null
#
# A script to automagically update Plex Media Server on Synology NAS
# This must be run as root to natively control running services
#
# Author @michealespinola https://github.com/michealespinola/syno.plexupdate
#
# Original update concept based on: https://github.com/martinorob/plexupdate
#
# Example Synology DSM Scheduled Task type 'user-defined script': 
# bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh

# SCRAPE SCRIPT PATH INFO
SrceFllPth=$(readlink -f "${BASH_SOURCE[0]}")
SrceFolder=$(dirname "$SrceFllPth")
SrceFileNm=${SrceFllPth##*/}

# REDIRECT STDOUT TO TEE IN ORDER TO DUPLICATE THE OUTPUT TO THE TERMINAL AS WELL AS A .LOG FILE
exec > >(tee "$SrceFllPth.log") 2>"$SrceFllPth.debug"
# ENABLE XTRACE OUTPUT FOR DEBUG FILE
set -x

# SCRIPT VERSION
SPUScrpVer=4.4.1
MinDSMVers=7.0
# PRINT OUR GLORIOUS HEADER BECAUSE WE ARE FULL OF OURSELVES
printf "\n"
printf "%s\n" "SYNO.PLEX UPDATE SCRIPT v$SPUScrpVer for DSM 7"
printf "\n"

# CHECK IF ROOT
if [ "$EUID" -ne "0" ]; then
  printf ' %s\n' "* This script MUST be run as root - exiting.."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Script was not run as root."}'
  printf "\n"
  exit 1
fi

# CHECK IF DEFAULT CONFIG FILE EXISTS, IF NOT CREATE IT
if [ ! -f "$SrceFolder/config.ini" ]; then
  printf ' %s\n\n' "* CONFIGURATION FILE (config.ini) IS MISSING, CREATING DEFAULT SETUP.."
  {
    printf "%s\n"  "# A NEW UPDATE MUST BE THIS MANY DAYS OLD"
    printf "%s\n"  "MinimumAge=7"
    printf "%s\n"  "# PREVIOUSLY DOWNLOADED PACKAGES DELETED IF OLDER THAN THIS MANY DAYS"
    printf "%s\n"  "OldUpdates=60"
    printf "%s\n"  "# NETWORK TIMEOUT IN SECONDS (900s = 15m)"
    printf "%s\n"  "NetTimeout=900"
    printf "%s\n"  "# SCRIPT WILL SELF-UPDATE IF SET TO 1"
    printf "%s\n"  "SelfUpdate=0"
  } >> "$SrceFolder/config.ini"
  ExitStatus=1
fi

# LOAD CONFIG FILE IF IT EXISTS
if [ -f "$SrceFolder/config.ini" ]; then
  source "$SrceFolder/config.ini"
fi

# CHECK IF SCRIPT IS ARCHIVED
if [ ! -d "$SrceFolder/Archive/Scripts" ]; then
  mkdir -p "$SrceFolder/Archive/Scripts"
fi
if [ ! -f "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh" ]; then
  cp "$SrceFllPth" "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
else
  cmp -s "$SrceFllPth" "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
  if [ "$?" -ne "0" ]; then
    cp "$SrceFllPth" "$SrceFolder/Archive/Scripts/syno.plexupdate.v$SPUScrpVer.sh"
  fi
fi

# GET EPOCH TIMESTAMP FOR AGE CHECKS
TodaysDate=$(date --date "now" +'%s')

# SCRAPE GITHUB WEBSITE FOR LATEST INFO
GitHubRepo=michealespinola/syno.plexupdate
GitHubHtml=$(curl -i -m "$NetTimeout" -Ls https://api.github.com/repos/$GitHubRepo/releases?per_page=1)
if [ "$?" -eq "0" ]; then
  # AVOID SCRAPING SQUARED BRACKETS BECAUSE GITHUB IS INCONSISTENT
  GitHubJson=$(echo "$GitHubHtml" | grep -oPz '\{\s{0,6}\"\X*\s{0,4}\}')
  # ADD SQUARED BRACKETS BECAUSE ITS PROPER AND JQ NEEDS IT
  GitHubJson=$'[\n'"$GitHubJson"$'\n]'
  GitHubHtml=$(echo "$GitHubHtml" | grep -oPz '\X*\{\W{0,6}\"' | sed -z 's/\W\[.*//')
  # SCRAPE CURRENT RATE LIMIT
  SPUSAPIRlm=$(echo "$GitHubHtml" | grep -oP  '^x-ratelimit-limit: \K[\d]+')
  SPUSAPIRlr=$(echo "$GitHubHtml" | grep -oP  '^x-ratelimit-remaining: \K[\d]+')
  # SCRAPE API MESSAGES
  SPUSAPIMsg=$(echo "$GitHubJson" | jq -r '.[].message')
  SPUSAPIDoc=$(echo "$GitHubJson" | jq -r '.[].documentation_url')
  #SCRAPE EXPECTED RELEASE-RELATED INFO
  SPUSNewVer=$(echo "$GitHubJson" | jq -r '.[].tag_name')
  SPUSNewVer=${SPUSNewVer#v}
  SPUSRlDate=$(echo "$GitHubJson" | jq -r '.[].published_at')
  SPUSRlDate=$(date --date "$SPUSRlDate" +'%s')
  SPUSRelAge=$(((TodaysDate-SPUSRlDate)/86400))
  SPUSDwnUrl=https://raw.githubusercontent.com/$GitHubRepo/v$SPUSNewVer/syno.plexupdate.sh
  SPUSHlpUrl=https://github.com/$GitHubRepo/issues
  SPUSRelDes=$(echo "$GitHubJson" | jq -r '.[].body')
else
  printf ' %s\n\n' "* UNABLE TO CHECK FOR LATEST VERSION OF SCRIPT.."
  ExitStatus=1
fi

# PRINT SCRIPT STATUS/DEBUG INFO
printf '%16s %s\n'           "Script:" "$SrceFileNm"
printf '%16s %s\n'       "Script Dir:" "$SrceFolder"
printf '%16s %s\n'      "Running Ver:" "$SPUScrpVer"
if [ "$SPUSNewVer" = "null" ]; then
  printf "%16s %s\n" "GitHub API Msg:" "$(echo "$SPUSAPIMsg" | fold -w 60 -s | sed '2,$s/^/                 /')"
  printf "%16s %s\n" "GitHub API Lmt:" "$SPUSAPIRlm connections per hour per IP"
  printf "%16s %s\n" "GitHub API Doc:" "$(echo "$SPUSAPIDoc" | fold -w 60 -s | sed '2,$s/^/                 /')"
  ExitStatus=1
elif [ "$SPUSNewVer" != "" ]; then
  printf '%16s %s\n'     "Online Ver:" "$SPUSNewVer ($SPUSAPIRlr/$SPUSAPIRlm)"
  printf '%16s %s\n'       "Released:" "$(date --rfc-3339 seconds --date @"$SPUSRlDate") ($SPUSRelAge+ days old)"
fi

# COMPARE SCRIPT VERSIONS
if [ "$SPUSNewVer" != "null" ]; then
  /usr/bin/dpkg --compare-versions "$SPUSNewVer" gt "$SPUScrpVer"
  if [ "$?" -eq "0" ]; then
    printf '                 %s\n' "* Newer version found!"
    # DOWNLOAD AND INSTALL THE SCRIPT UPDATE
    if [ "$SelfUpdate" -eq "1" ]; then
      if [ "$SPUSRelAge" -ge "$MinimumAge" ]; then
        printf "\n"
        printf "%s\n" "INSTALLING NEW SCRIPT:"
        printf "%s\n" "----------------------------------------"
        /bin/wget -nv "$SPUSDwnUrl" -O "$SrceFolder/Archive/Scripts/$SrceFileNm"                               2>&1
        if [ "$?" -eq "0" ]; then
          # MAKE A COPY FOR UPGRADE COMPARISON BECAUSE WE ARE GOING TO MOVE NOT COPY THE NEW FILE
          cp -f -v "$SrceFolder/Archive/Scripts/$SrceFileNm"     "$SrceFolder/Archive/Scripts/$SrceFileNm.cmp" 2>&1
          # MOVE-OVERWRITE INSTEAD OF COPY-OVERWRITE TO NOT CORRUPT RUNNING IN-MEMORY VERSION OF SCRIPT
          mv -f -v "$SrceFolder/Archive/Scripts/$SrceFileNm"     "$SrceFolder/$SrceFileNm"                     2>&1
          printf "%s\n" "----------------------------------------"
          cmp -s   "$SrceFolder/Archive/Scripts/$SrceFileNm.cmp" "$SrceFolder/$SrceFileNm"
          if [ "$?" -eq "0" ]; then
            printf '                 %s\n' "* Script update succeeded!"
            /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update completed successfully"}'
            ExitStatus=1
            if [ -n "$SPUSRelDes" ]; then
              # SHOW RELEASE NOTES
              printf "\n"
              printf "%s\n" "RELEASE NOTES:"
              printf "%s\n" "----------------------------------------"
              printf "%s\n" "$SPUSRelDes"
              printf "%s\n" "----------------------------------------"
              printf "%s\n" "Report issues to: $SPUSHlpUrl"
            fi
          else
            printf '                 %s\n' "* Script update failed to overwrite."
            /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update failed."}'
            ExitStatus=1
          fi
        else
          printf '                 %s\n' "* Script update failed to download."
          /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Syno.Plex Update\n\nSelf-Update failed to download."}'
          ExitStatus=1
        fi
      else
        printf ' \n%s\n' "Update newer than $MinimumAge days - skipping.."
      fi
      # DELETE TEMP COMPARISON FILE
      find "$SrceFolder/Archive/Scripts" -type f -name "$SrceFileNm.cmp" -delete
    fi
  
  else
    printf '                 %s\n' "* No new version found."
  fi
fi
printf "\n"

# SCRAPE SYNOLOGY HARDWARE MODEL
SynoHModel=$(< /proc/sys/kernel/syno_hw_version)
# SCRAPE SYNOLOGY CPU ARCHITECTURE FAMILY
ArchFamily=$(uname --machine)

# FIXES FOR INCONSISTENT ARCHITECTURE MATCHES
[ "$ArchFamily" = "i686" ]   && ArchFamily=x86
[ "$ArchFamily" = "armv7l" ] && ArchFamily=armv7neon

# SCRAPE DSM VERSION AND CHECK COMPATIBILITY
DSMVersion=$(                      grep -i "productversion=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
# CHECK IF DSM 7
/usr/bin/dpkg --compare-versions "$MinDSMVers" gt "$DSMVersion"
if [ "$?" -eq "0" ]; then
  printf ' %s\n' "* Syno.Plex Update requires DSM $MinDSMVers minimum to install - exiting.."
  /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. DSM not sufficient version."}'
  printf "\n"
  exit 1
fi
DSMVersion=$(echo "$DSMVersion"-"$(grep -i "buildnumber="    "/etc.defaults/VERSION" | cut -d"\"" -f 2)")
DSMUpdateV=$(                      grep -i "smallfixnumber=" "/etc.defaults/VERSION" | cut -d"\"" -f 2)
if [ -n "$DSMUpdateV" ]; then
  DSMVersion="$DSMVersion Update $DSMUpdateV"
fi

# SCRAPE CURRENTLY RUNNING PMS VERSION
RunVersion=$(/usr/syno/bin/synopkg version "PlexMediaServer")
RunVersion=$(echo "$RunVersion"  | grep -oP '^.+?(?=\-)')

# SCRAPE PMS FOLDER LOCATION AND CREATE ARCHIVED PACKAGES DIR W/OLD FILE CLEANUP
PlexFolder=$(readlink /var/packages/PlexMediaServer/shares/PlexMediaServer)
PlexFolder="$PlexFolder/AppData/Plex Media Server"

if [ -d "$PlexFolder/Updates" ]; then
  mv -f "$PlexFolder/Updates/"* "$SrceFolder/Archive/Packages/" 2>/dev/null
  if [ -n "$(find "$PlexFolder/Updates/" -prune -empty 2>/dev/null)" ]; then
    rmdir "$PlexFolder/Updates/"
  fi
fi
if [ -d "$SrceFolder/Archive/Packages" ]; then
  find "$SrceFolder/Archive/Packages" -type f -name "PlexMediaServer*.spk" -mtime +"$OldUpdates" -delete
else
  mkdir -p "$SrceFolder/Archive/Packages"
fi

# SCRAPE PLEX ONLINE TOKEN
PlexOToken=$(grep -oP "PlexOnlineToken=\"\K[^\"]+"     "$PlexFolder/Preferences.xml")
# SCRAPE PLEX SERVER UPDATE CHANNEL
PlexChannl=$(grep -oP "ButlerUpdateChannel=\"\K[^\"]+" "$PlexFolder/Preferences.xml")
if [ -z "$PlexChannl" ]; then
  # DEFAULT TO PUBLIC SERVER UPDATE CHANNEL IF NULL (NEVER SET) VALUE
  ChannlName=Public
  ChannelUrl="https://plex.tv/api/downloads/5.json"
else
  if [ "$PlexChannl" -eq "0" ]; then
    # PUBLIC SERVER UPDATE CHANNEL
    ChannlName=Public
    ChannelUrl="https://plex.tv/api/downloads/5.json"
  elif [ "$PlexChannl" -eq "8" ]; then
    # BETA SERVER UPDATE CHANNEL (REQUIRES PLEX PASS)
    ChannlName=Beta
    ChannelUrl="https://plex.tv/api/downloads/5.json?channel=plexpass&X-Plex-Token=$PlexOToken"
  else
    # REPORT ERROR IF UNRECOGNIZED CHANNEL SELECTION
    printf ' %s\n' "Unable to identify Server Update Channel (Public, Beta, etc) - exiting.."
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Could not identify update channel (Public, Beta, etc)."}'
    printf "\n"
    exit 1
  fi
fi

# SCRAPE PLEX WEBSITE FOR UPDATE INFO
DistroJson=$(curl -m "$NetTimeout" -Ls "$ChannelUrl")
if [ "$?" -eq "0" ]; then
  NewVersion=$(echo "$DistroJson" | jq -r '.nas.Synology.version')
  NewVersion=$(echo "$NewVersion" | grep -oP '^.+?(?=\-)')
  NewVerDate=$(echo "$DistroJson" | jq -r '.nas.Synology.release_date')
  NewVerAddd=$(echo "$DistroJson" | jq -r '.nas.Synology.items_added')
  NewVerFixd=$(echo "$DistroJson" | jq -r '.nas.Synology.items_fixed')
  NewDwnlUrl=$(echo "$DistroJson" | jq --arg ArchFamily "$ArchFamily"  -r '.nas."Synology (DSM 7)".releases[] | select(.build == "linux-"+$ArchFamily) | .url'); NewPackage="${NewDwnlUrl##*/}"
  # CALCULATE NEW PACKAGE AGE FROM RELEASE DATE
  PackageAge=$(((TodaysDate-NewVerDate)/86400))
else
  printf ' %s\n' "* UNABLE TO CHECK FOR LATEST VERSION OF PLEX MEDIA SERVER.."
  printf "\n"
  ExitStatus=1
fi

# UPDATE LOCAL VERSION CHANGELOG
grep -q           "Version $NewVersion ($(date --rfc-3339 seconds --date @"$NewVerDate"))"    "$SrceFolder/Archive/Packages/changelog.txt" 2>/dev/null
if [ "$?" -ne "0" ]; then
  {
    printf "%s\n" "Version $NewVersion ($(date --rfc-3339 seconds --date @"$NewVerDate"))"
    printf "%s\n" "$ChannlName Channel"
    printf "%s\n" ""
    printf "%s\n" "New Features:"
    printf "%s\n" "$NewVerAddd" | awk '{ print "* " $BASH_SOURCE }'
    printf "%s\n" ""
    printf "%s\n" "Fixed Features:"
    printf "%s\n" "$NewVerFixd" | awk '{ print "* " $BASH_SOURCE }'
    printf "%s\n" ""
    printf "%s\n" "----------------------------------------"
    printf "%s\n" ""
  } >> "$SrceFolder/Archive/Packages/changelog.new"
  if [ -f "$SrceFolder/Archive/Packages/changelog.new" ]; then
    if [ -f "$SrceFolder/Archive/Packages/changelog.txt" ]; then
      mv    "$SrceFolder/Archive/Packages/changelog.txt" "$SrceFolder/Archive/Packages/changelog.tmp"
      cat   "$SrceFolder/Archive/Packages/changelog.new" "$SrceFolder/Archive/Packages/changelog.tmp" > "$SrceFolder/Archive/Packages/changelog.txt"
    else
      mv    "$SrceFolder/Archive/Packages/changelog.new" "$SrceFolder/Archive/Packages/changelog.txt"    
    fi
  fi
fi
rm "$SrceFolder/Archive/Packages/changelog.new" "$SrceFolder/Archive/Packages/changelog.tmp" 2>/dev/null

# PRINT PLEX STATUS/DEBUG INFO
printf '%16s %s\n'         "Synology:" "$SynoHModel ($ArchFamily), DSM $DSMVersion"
printf '%16s %s\n'         "Plex Dir:" "$PlexFolder"
printf '%16s %s\n'      "Running Ver:" "$RunVersion"
if [ "$NewVersion" != "" ]; then
  printf '%16s %s\n'     "Online Ver:" "$NewVersion ($ChannlName Channel)"
  printf '%16s %s\n'       "Released:" "$(date --rfc-3339 seconds --date @"$NewVerDate") ($PackageAge+ days old)"
fi

# COMPARE PLEX VERSIONS
/usr/bin/dpkg --compare-versions "$NewVersion" gt "$RunVersion"
if [ "$?" -eq "0" ]; then
  printf '                 %s\n' "* Newer version found!"
  printf "\n"
  printf '%16s %s\n'      "New Package:" "$NewPackage"
  printf '%16s %s\n'      "Package Age:" "$PackageAge+ days old ($MinimumAge+ required for install)"
  printf "\n"

  # DOWNLOAD AND INSTALL THE PLEX UPDATE
  if [ "$PackageAge" -ge "$MinimumAge" ]; then
    printf "%s\n" "INSTALLING NEW PACKAGE:"
    printf "%s\n" "----------------------------------------"
    printf "%s\n" "Downloading PlexMediaServer package:"
    /bin/wget "$NewDwnlUrl" -nv -c -nc -P "$SrceFolder/Archive/Packages/"
    if [ "$?" -eq "0" ]; then
      printf "\n%s\n"   "Stopping PlexMediaServer service:"
      /usr/syno/bin/synopkg stop    "PlexMediaServer"
      printf "\n%s\n" "Installing PlexMediaServer update:"
      # INSTALL WHILE STRIPPING OUTPUT ANNOYANCES 
      /usr/syno/bin/synopkg install "$SrceFolder/Archive/Packages/$NewPackage" | awk '{gsub("<[^>]*>", "")}1' | awk '{gsub(/\\nNote:.*?\\n",/, RS)}1'
      printf "\n%s\n" "Starting PlexMediaServer service:"
      /usr/syno/bin/synopkg start   "PlexMediaServer"
    else
      printf '\n %s\n' "* Package download failed, skipping install.."
    fi
    printf "%s\n" "----------------------------------------"
    printf "\n"
    NowVersion=$(/usr/syno/bin/synopkg version "PlexMediaServer")
    printf '%16s %s\n'      "Update from:" "$RunVersion"
    printf '%16s %s'                   "to:" "$NewVersion"

    # REPORT PLEX UPDATE STATUS
    /usr/bin/dpkg --compare-versions "$NowVersion" gt "$RunVersion"
    if [ "$?" -eq "0" ]; then
      printf ' %s\n' "succeeded!"
      printf "\n"
      if [ -n "$NewVerAddd" ]; then
        # SHOW NEW PLEX FEATURES
        printf "%s\n" "NEW FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerAddd" | awk '{ print "* " $BASH_SOURCE }'
        printf "%s\n" "----------------------------------------"
      fi
      printf "\n"
      if [ -n "$NewVerFixd" ]; then
        # SHOW FIXED PLEX FEATURES
        printf "%s\n" "FIXED FEATURES:"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$NewVerFixd" | awk '{ print "* " $BASH_SOURCE }'
        printf "%s\n" "----------------------------------------"
      fi
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task completed successfully"}'
      ExitStatus=1
    else
      printf ' %s\n' "failed!"
      /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server\n\nSyno.Plex Update task failed. Installation not newer version."}'
      ExitStatus=1
    fi
  else
    printf ' %s\n' "Update newer than $MinimumAge days - skipping.."
  fi
else
  printf '                 %s\n' "* No new version found."
fi

printf "\n"

# CLOSE AND NORMALIZE THE LOGGING REDIRECTIONS
exec >&- 2>&- 1>&2

# EXIT NORMALLY BUT POSSIBLY WITH FORCED EXIT STATUS FOR SCRIPT NOTIFICATIONS
if [ -n "$ExitStatus" ]; then
  exit "$ExitStatus"
fi
