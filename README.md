# Description  

### Automatically update Plex Media Server on the Synology NAS platform

This script takes into account many if not all of the issues I have previously read about for automatically updating Plex on the Synology NAS platform. This is a heavily-modified/overhauled version of the "[martinorob/plexupdate](https://github.com/martinorob/plexupdate)" script, with the specific intent to simplify its use to not require any Bash script variable editing or SSH access to the Synology NAS. This script originally started as a simple fork, but over the generations has turned into a wholly different script aside from the core task of updating Plex Media Server.  The "fork" has been officially discontinued because it no longer resembles the original code, and has different support requirements.

Everything you need to do to get this script running is accomplishable via the most basic DSM web administration by dropping this script onto the NAS and configuring a scheduled Task. This script is specifically for the update of the official Synology package of the Plex Media Server. It utilizes Synology’s built-in tools to self-determine everything it needs to know about where Plex is located, how to update it, and to notify the system of updates or failures to update. If Plex is installed and properly configured, you will not have to edit this script for any details about the installation location of Plex. Public or Beta Update Channel selection follows what you have configured in the Plex Media Server general settings.

Although only personally tested on my DS1019+, this script has been written with the intent to work on any compatible Synology platform. It reads your hardware architecture from the system and matches it against what is compatible with Plex. If its a part of the official Plex public or beta channel, this script will update it.

The default yet modifiable settings are that the script will not install an update unless it is 7 days old. This is a stability safety-catch so that if a release has a bug, it is assumed it will be discovered and fixed within 7 days. Otherwise, it keeps installation packages in its "Updates" directory for 60 days before automatic deletion.

# How-To Example

### Script File Placement

Download the script and place it into a location of your choosing. As an example, if you are using the "`admin`" account for system administration tasks, place the script within that accounts home folder such as in a nested folder location like this:

    \\SYNOLOGY\home\scripts\bash\plex\plexupdate\plexupdate.sh

-aka-

    \\SYNOLOGY\homes\admin\scripts\bash\plex\plexupdate\plexupdate.sh

### DSM Task Scheduler Setup

1. Open the [DSM](https://www.synology.com/en-global/knowledgebase/DSM/help) web interface
1. Open the [Control Panel](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/AdminCenter/ControlPanel_desc)
1. Open [Task Scheduler](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/AdminCenter/system_taskscheduler)
   1. Click Create -> Scheduled Task -> User-defined script
   1. Enter Task: name as '`Plex Update`', and leave User: set to '`root`'
   1. Click Schedule tab and configure per your requirements
   1. Click Task Settings tab
   1. Enter 'User-defined script' as '`bash /var/services/homes/admin/scripts/bash/plex/plexupdate/plexupdate.sh`' if using the above script placement example. '`/var/services/homes`' is the base location of user home directories
1. Click OK

# Script Logic Flow

1. Identify the "Plex Media Server" installation directory and other system-specific technical details
1. Create default Plex "Updates" directory if it does not exist, and remove old updates installer files
1. Extract Plex Token from local Preferences file for use to lookup available updates
1. Scrape JSON data to identify applicable updates specific to hardware architecture
1. Compare currently running version information against latest online version
1. If a new version exists and is older than the default 7-days - install the new version
1. Check if the upgrade was successful and send appropriate notifications

# To Do  

The code currently has (2) hardcoded variables.  A 7-day age requirement for installing the latest version as a bug/issue deterrent, and a 60-day age timer for deleting old package installer files. These number values are located near the top of the script and can be modified, but will soon be codified as parameter values. This fork intends to never have to modify the base script for anything and do not have to SSH to anything either.

# Thanks!

Historical thanks to https://forums.plex.tv/u/j0nsplex !