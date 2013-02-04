#!/bin/bash
 
# Zimbra Backup Script
# This script is intended to run from the crontab as root
# Date outputs and su vs sudo corrections by other contributors, thanks, sorry I don't have names to attribute!
# Free to use and free of any warranty!  Daniel W. Martin, 5 Dec 2008
# Updated by Scott Harwell on 02/03/2013 to try to circumvent ldap 85 GB allocated file.
# Also, this backup only backs up locally; ncftp has been commented out.

 
# Outputs the time the backup started, for log/tracking purposes
echo Time backup started = $(date +%T)
before="$(date +%s)"

# Live sync before stopping Zimbra to minimize sync time with the services down
# Comment out the following line if you want to try single cold-sync only
rsync -avHK --exclude 'data/ldap/mdb/db' --delete /opt/zimbra/ /media/backup/zimbra_backup 

# which is the same as: /opt/zimbra /backup 
# Including --delete option gets rid of files in the dest folder that don't exist at the src 
# this prevents logfile/extraneous bloat from building up overtime.

# Now we need to shut down Zimbra to rsync any files that were/are locked
# whilst backing up when the server was up and running.
before2="$(date +%s)"

# Stop Zimbra Services
su - zimbra -c"/opt/zimbra/bin/zmcontrol stop"
sleep 30

# Kill any orphaned Zimbra processes
ORPHANED=`ps -u zimbra -o "pid="` && kill -9 $ORPHANED

# Only enable the following command if you need all Zimbra user owned
# processes to be killed before syncing
# ps auxww | awk '{print $1" "$2}' | grep zimbra | kill -9 `awk '{print $2}'`
 
# Sync to backup directory
rsync -avHKS --exclude 'data/ldap/mdb/db' --delete /opt/zimbra/ /media/backup/zimbra_backup

# Sync LDAP Sparse Files (cp copies sparse files properly)
cp -r /opt/zimbra/data/ldap/mdb/db /media/backup/zimbra_backup/data/ldap/mdb/

# Restart Zimbra Services
su - zimbra -c "/opt/zimbra/bin/zmcontrol start"

# Calculates and outputs amount of time the server was down for
after="$(date +%s)"
elapsed="$(expr $after - $before2)"
hours=$(($elapsed / 3600))
elapsed=$(($elapsed - $hours * 3600))
minutes=$(($elapsed / 60))
seconds=$(($elapsed - $minutes * 60))
echo Server was down for: "$hours hours $minutes minutes $seconds seconds"

# Create a txt file in the backup directory that'll contains the current Zimbra
# server version. Handy for knowing what version of Zimbra a backup can be restored to.
su - zimbra -c "zmcontrol -v > /media/backup/zimbra_backup/conf/zimbra_version.txt"
# or examine your /opt/zimbra/.install_history

# Display Zimbra services status
echo Displaying Zimbra services status...
su - zimbra -c "/opt/zimbra/bin/zmcontrol status"
 
# Create archive of backed-up directory for offsite transfer
# cd /backup/zimbra
umask 0177
today="$(date +%m-%d-%y)"
tar -zcvf "/media/backup/zimbra_backup_tars/mail.backup.$today.tgz" -C /media/backup/zimbra_backup .
 
####### SCOTT COMMENTED OUT AS NO TRANSFER AT THIS POINT
# Transfer file to backup server
#ncftpput -u <username> -p <password> <ftpserver> /<desired dest. directory> /tmp/mail.backup.tgz
#
#rm /tmp/mail.backup.tgz
#######

# Outputs the time the backup finished
echo Time backup finished = $(date +%T)

# Calculates and outputs total time taken
after="$(date +%s)"
elapsed="$(expr $after - $before)"
hours=$(($elapsed / 3600))
elapsed=$(($elapsed - $hours * 3600))
minutes=$(($elapsed / 60))
seconds=$(($elapsed - $minutes * 60))
echo Time taken: "$hours hours $minutes minutes $seconds seconds"