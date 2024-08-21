![GitHub release (latest by date)](https://img.shields.io/github/v/release/michealespinola/syno.plexupdate)
![GitHub top language](https://img.shields.io/github/languages/top/michealespinola/syno.plexupdate)
![GitHub](https://img.shields.io/github/license/michealespinola/syno.plexupdate)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=2RYY4BETEQAJC)

 

![syno.plexupdate logo](./images/Syno.PLEX%20logo.png)

### Automatically Update Plex Media Server on the Synology NAS platform

# Description

This script addresses common issues with automatically updating Plex on Synology NAS, evolved significantly from the original "[martinorob/plexupdate](https://github.com/martinorob/plexupdate)" script. It has been overhauled to eliminate the need for Bash variable editing or SSH access, making it user-friendly for DSM web administration. The original fork from "martinorob/plexupdate" has been discontinued due because the current script was rewritten from the ground up with extensive modifications, resulting in a unique script with different support requirements.

The script is tailored specifically to update the official Synology package of Plex Media Server, as released by [Plex GmbH](https://www.plex.tv/). It uses Synology's built-in tools to automatically detect Plex's installation location, manage updates, and notify the system of any issues. If Plex is properly installed, no manual script editing is needed. The script respects the update channel settings (Public or Beta) configured in your Plex Media Server's 'General' settings.

Though primarily developed and tested on and against a DS1019+, the script is designed and written to work on any compatible Synology platform using DSM's command-line utilities. It reads the local hardware architecture and ensures compatibility with specific versions of Plex that are released for specific Synology hardware platforms. If the update is part of the official Plex public or beta channel, the script will apply it.

By default, the script only installs updates that are at least 7 days old, serving as a stability measure. Additionally, it retains previously downloaded and installed packages in an "Updates" archive for 60 days before automatic deletion to make rollbacks easier to find and perform.

### DSM 6 and DSM 7 Support Notes

DSM 7 is officially supported starting from v4.0.0 and the OS platform that the script is developed for. DSM 6 support culminated with the v3.x.x series of the script. Dual support may be considered in the future, but it is not at this time while the code is optimized and stablized for DSM 7, and after some new features are implimented. I welcome development collaboration if anyone is interested, but I do not use DSM 6 myself, so it makes my own work in this direction difficult and undesirable.

* The latest updated version supporting DSM 6 can be found here:
  <https://github.com/michealespinola/syno.plexupdate/tree/master/Tools>

# How-To Setup Example

### 1. Save the Script to Your NAS

Download the script and place it into a location of your choosing. As an example, if you are using the "`admin`" account for system administration tasks, you can place the script within that accounts home folder; such as in a nested directory location like this:

    /home/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh

-or-

    /homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh
    
**Note:** Synology recommends that you disable the default "`admin`" account for security reasons. In these examples, the admin directory structure is just a script storage location. You can run the script from here even if you disable the "`admin`" account (which you really should).

### 2. Add the Plex 'Public Key Certificate' in DSM 6

* *This step is not required for DSM 7*

Updates directly from Plex (which is what this script installs) are not installable in the Synology DSM 6 by default - because no 3rd-party applications are. To install updates directly from Plex, DSM 6 must be configured to allow packages from other trusted application publishers. To facilitate this, Plex's 'Public Key Certificate' must be installed to allow this securely and without simply allowing any and all application publishers to be installable. The full instructions for this can be found on Plex's website here:

> <https://support.plex.tv/articles/205165858-how-to-add-plex-s-package-signing-public-key-to-synology-nas-package-center/>

1. Download the Plex 'Public Key Certificate' file from here: https://downloads.plex.tv/plex-keys/PlexSign.key
1. Open the [DSM](https://www.synology.com/en-global/knowledgebase/DSM/help) web interface
1. Open the [Package Center](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/PkgManApp/PackageCenter_desc)
   1. Click the General tab and change the Trust Level to "Synology Inc. and trusted publishers"
   1. Click on the Certificate tab and click the Import button
   1. Supply the location of the downloaded key file and import it
1. Click OK

### 3. Setup a Scheduled Task in the DSM

1. Open the [DSM](https://www.synology.com/en-global/knowledgebase/DSM/help) web interface
1. Open the [Control Panel](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/AdminCenter/ControlPanel_desc)
1. Open [Task Scheduler](https://www.synology.com/en-global/knowledgebase/DSM/help/DSM/AdminCenter/system_taskscheduler)
   1. Click Create -> Scheduled Task -> User-defined script
   1. Enter Task: name as '`Syno.Plex Update`', and leave User: set to '`root`'
   1. Click Schedule tab and configure per your requirements
   1. Click Task Settings tab
   1. Enter 'User-defined script' similar to:    
   '`bash /volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh`'    
   ...if using the above script placement example. '`/volume1`' is the default storage volume on a Synology NAS. You can determine your script directory's full pathname by looking at the Location properties of the folder with the [File Station](https://www.synology.com/en-global/knowledgebase/DSM/help/FileStation/FileBrowser_desc) tool in the DSM:
      1. Right-click on the folder containing the script and choose Properties
      1. Copy the full directory path from the Location field
1. Click OK

# Script Logic Flow

1. Identify the "Plex Media Server" installation directory and other system-specific technical details
1. Create a "Packages" Archive directory if it does not exist, and remove old update package files
1. Extract Plex Token from local Preferences file for use to lookup available updates
1. Scrape JSON data to identify applicable updates specific to hardware architecture
1. Compare currently running version information against latest online version
1. If a new version exists and is older than the default 7-days - install the new version
1. Check if the upgrade was successful, update local changelog if applicable, and send appropriate notifications to the DSM and email (if configured for the DSM)
   * Notifications are only sent when an upgrade installation takes place

# Script Directory Structure

The script will automatically create directories and files as needed in the following directory structure based off of the location of the script, as per this example:

    /volume1/homes/admin/scripts/bash/plex/syno.plexupdate
    |   README.md
    |   syno.plexupdate.sh
    |
    \---Archive
       +---Packages
       |       changelog.txt
       |       PlexMediaServer-1.21.3.4021-5a0a3e4b2-x86_64.spk
       |       PlexMediaServer-1.21.3.4046-3c1c83ba4-x86_64.spk
       |       PlexMediaServer-1.21.4.4079-1b7748a7b-x86_64.spk
       |       PlexMediaServer-1.22.0.4163-d8c4875dd-x86_64.spk
       |       PlexMediaServer-1.22.1.4228-724c56e62-x86_64_DSM6.spk
       |       PlexMediaServer-1.22.2.4256-1e171f908-x86_64_DSM6.spk
       |       ...
       |
       \---Scripts
                syno.plexupdate.v2.3.1.sh
                syno.plexupdate.v2.3.2.sh
                syno.plexupdate.v2.3.3.sh
                syno.plexupdate.v2.9.9.sh
                syno.plexupdate.v2.9.9.1.sh
                syno.plexupdate.v2.9.9.2.sh
                ...

The Archive directory structure contains copies of update Packages as well as copies of the update Scripts that are running. However, the script archive is not a mirror of what is on GitHub. The script archive are a snapshot of running copies of the script. If you make modifications to the script, the copy in the script archive will be updated accordingly. The packages archive is similarly intended for manual rollback purposes.

The '`changelog.txt`' file is a historical changelog only for updates installed locally by the script. It will not contain any historical information for versions that were otherwised skipped by the script.

# Example Email Notification

    Dear user,

    Task Scheduler has completed a scheduled task.

    Task: Syno.Plex Update
    Start time: Tue, 20 Aug 2024 12:05:36 GMT
    Stop time: Tue, 20 Aug 2024 12:06:21 GMT
    Current status: 1 (Interrupted)
    Standard output/error:

    SYNO.PLEX UPDATE SCRIPT v4.4.1 for DSM 7

            Script: syno.plexupdate.sh
        Script Dir: /volume1/homes/admin/scripts/bash/plex/syno.plexupdate
       Running Ver: 4.4.1
        Online Ver: 4.5.0 (59/60)
          Released: 2024-08-20 18:30:14-07:00 (0+ days old)
                    * Newer version found!

    INSTALLING NEW SCRIPT:
    ----------------------------------------
    2024-08-20 19:09:07 URL:https://raw.githubusercontent.com/michealespinola/syno.plexupdate/v4.5.0/syno.plexupdate.sh [17155/17155] -> "/volume1/homes/admin/scripts/bash/plex/syno.plexupdate/Archive/Scripts/syno.plexupdate.sh" [1]
    '/volume1/homes/admin/scripts/bash/plex/syno.plexupdate/Archive/Scripts/syno.plexupdate.sh' -> '/volume1/homes/admin/scripts/bash/plex/syno.plexupdate/Archive/Scripts/syno.plexupdate.sh.cmp'
    renamed '/volume1/homes/admin/scripts/bash/plex/syno.plexupdate/Archive/Scripts/syno.plexupdate.sh' -> '/volume1/homes/admin/scripts/bash/plex/syno.plexupdate/syno.plexupdate.sh'
    ----------------------------------------
                    * Script update succeeded!

    RELEASE NOTES:
    ----------------------------------------
    1. Fixed bug introduced in Plex back end causing null data fields
    2. Added command line option for modifying MinimumAge variable
    3. Tweaked how TodaysDate variable is captured
    4. Tweaked how long SrceFolder variables are displayed
    ----------------------------------------
    Report issues to: https://github.com/michealespinola/syno.plexupdate/issues

          Synology: DS1019+ (x86_64), DSM 7.2.1-69057 Update 5
          Plex Dir: /volume4/PlexMediaServer/AppData/Plex Media Server
       Running Ver: 1.40.5.8854
        Online Ver: 1.40.5.8897 (Beta Channel)
          Released: 2024-08-20 08:51:24-07:00 (0+ days old)
                    * Newer version found!

        New Package: PlexMediaServer-1.40.5.8897-e5987a19d-x86_64_DSM7.spk
        Package Age: 0+ days old (0+ required for install)

    INSTALLING NEW PACKAGE:
    ----------------------------------------
    Downloading PlexMediaServer package:

    Stopping PlexMediaServer service:
    {"action":"stop","beta":false,"error":{"code":0},"finished":true,"language":"enu","last_stage":"stopped","package":"PlexMediaServer","pid":25669,"scripts":[{"code":0,"message":"","type":"stop"}],"stage":"stopped","status":"stop","status_code":324,"status_description":"translate from systemd status","success":true,"username":"","version":"1.40.5.8854-7000"}

    Installing PlexMediaServer update:
    {"error":{"code":0},"results":[{"action":"upgrade","beta":false,"betaIncoming":false,"error":{"code":0},"finished":true,"installReboot":false,"installing":true,"language":"enu","last_stage":"postupgrade","package":"PlexMediaServer","packageName":"Plex Media Server","pid":25843,"scripts":[{"code":0,"message":"","type":"preupgrade"},{"code":0,"message":"","type":"preuninst"},{"code":0,"message":"","type":"postuninst"},{"code":0,"message":"","type":"preinst"},{"code":0,"message":"Installation Successful!
    "type":"postinst"},{"code":0,"message":"","type":"postupgrade"}],"spk":"/volume1/homes/admin/scripts/bash/plex/syno.plexupdate/Archive/Packages/PlexMediaServer-1.40.5.8897-e5987a19d-x86_64_DSM7.spk","stage":"installed_and_stopped","status":"stop","status_code":273,"status_description":"translate from systemd status","success":true,"username":"","version":"1.40.5.8854-7000"}],"success":true}

    Starting PlexMediaServer service:
    {"action":"start","beta":false,"error":{"code":0},"finished":true,"language":"enu","last_stage":"started","package":"PlexMediaServer","pid":26409,"scripts":[{"code":0,"message":"","type":"start"}],"stage":"started","status":"running","success":true,"username":"","version":"1.40.5.8897-7000"}
    ----------------------------------------

        Update from: 1.40.5.8854
                to: 1.40.5.8897 succeeded!

    NEW FEATURES:
    ----------------------------------------
    * (Log) Reduced the number of log messages generated when starting playback on an NVIDIA device. (PM-1417)
    * (Windows) noautorestart command line parameter added which prevents PMS from restarting after an auto update (PM-1305)
    ----------------------------------------

    FIXED FEATURES:
    ----------------------------------------
    * (Analysis) Preview thumbnail generation would not run on newly added media regardless if the preference was set (PM-1782)
    * (Lyrics) Sidecar lyrics would fail to load (PM-1865)
    * (QNAP) PMS might not start in all cases after QTS/QuTS restart.
    * (ToneMapping) Tonemapping on linux with Gemini Lake devices would crash after a period of time. (PM-1934)
    * (ToneMapping) Tonemapping on linux with some Intel devices caused the transcoder to crash (PM-1934)
    * (View State Sync) Item plays could be duplicated when state synced from service.
    * (ViewStateSync) Fewer requests to plex.tv endpoints (PM-1958)
    * (Windows 64bit) Not all files were removed on uninstall (PM-1632)
    * Plex Media Server could crash when falling back to SW encoding. (#15026)
    ----------------------------------------




    From SYNOLOGY

# Default Settings (config.ini)

The script utilizes (4) default but user-configurable variables:

1. `MinimumAge=7`
   * A **7**-day age requirement for installing the latest version as a bug/issue deterrent
1. `OldUpdates=60`
   * A **60**-day age requirement for deleting old package installer files
1. `NetTimeout=900`
   * A **900**-second (15 minute) network timeout for hung network connections
1. `SelfUpdate=0`
   * A 0=off 1=on toggle to enable self-updating to the latest packaged release. Change this to **1** to enable self-updating that follows the same minimum age requirement as the Plex updates

# Known Non-Issues

* If the script runs successfully, the DSM Task status will show "`Interrupted (1)`" and the notification email will state "`Current status: 1 (Interrupted)`". This exit/error status of (1) is intentionally caused by the script in order to force the DSM to perform an email notification of a successful update (in the form of an interruption/error). The DSM otherwise would only send notifications of failed task events, and notifications of successful Plex updates would not be possible.
* If DSM 6 is not configured to allow 3rd-party "trusted publishers", the script will log "`error = [289]`" during the package installation process. Synology DSM 6 has been known to sporadically "lose" 3rd-party security certificates for unknown reasons. If this happens, you will have to re-add the Plex 'Public Key Certificate' to your system. DSM 7 no longer has this requirement.

# Common Mistakes

* Bash shell scripts running on Linux must be saved as LF (Line Feed) sequenced text. Alternatively, Windows typically uses CRLF (Carriage Return Line Feed). If you inadvertantly save your script with CRLF instead of LF sequencing, it will error with verbiage such as:
  * `'\r': command not found`
  * `syntax error near unexpected`
  
  To resolve this issue you will need to [re]save your copy of the script with LF sequencing, or download a new copy directly from GitHub.

# Thank You's

Many thanks to:

1. [j0nsplex](https://forums.plex.tv/u/j0nsplex) for starting it all
1. [martinorob](https://github.com/martinorob) for giving me a jumping-off point
1. [ChuckPa](https://forums.plex.tv/u/ChuckPa) and [trumpy81](https://forums.plex.tv/u/trumpy81) at Plex for being kind and encouraging to this endeavour
1. [Kynch](https://forums.plex.tv/u/Kynch) for the idea of self-updating the script
1. [SunMar](https://forums.plex.tv/u/SunMar) for the idea of a changelog
1. [turnmike2](https://github.com/turnmike2) for the idea of logged output to file

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=2RYY4BETEQAJC)
