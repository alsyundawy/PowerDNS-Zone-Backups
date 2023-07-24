# PowerDNS Zone Backups Bash Script

PowerDNS uses a database backend by default (e.g. MySQL). Simply do a database dump of the configured database and you’ll have a snapshot of all zones for easy recovery. It is recommend to dump the database to backup on a regular basis so that you can recover in case of a server crash. How often you should take the backup depends in part on how actively the zones are being updated, once a day is a good rule of thumb.

However this is only good for doing a full restore of all zones to the point in time the backup was made. Restoring a single zone from a full database dump would be non-trivial. PowerDNS includes the pdnsutil command line tool that can be used to dump individual zone files. You can then restore individual zones to the state at the time of the specific export. This is useful if an single zone is accidentally deleted or incorrectly updated and you need to recover that specific zone only.

Following is a simple bash script that uses the pdnsutil command line tool to dump each zone in the database to an individual zone file, and to keep a copy of the each zone file for each of the previous 28 days.

wget -c https://raw.githubusercontent.com/alsyundawy/PowerDNS-Zone-backups/main/export-zones-pds.sh

Save the script as /usr/local/bin/export-zones-pds.sh and then add a cron job that runs once per day. For example, to dump the zones at 3:01 am every day add this cron job:
1 3 * * * /usr/local/bin/export-zones-pds.sh

To restore a zone use the pdnsutil command like this:
/usr/bin/pdnsutil load-zone example.com /var/lib/powerdns/zones/example.com-20230725.zone

You can easily adjust the retention (currently 28 days) by adjusting the -mtime option in the find command at the end of the script. With a little more work you could adjust the today var to include hours and possibly minutes if you wanted save the zones multiple times a day.

**Anda bebas untuk mengubah, mendistribusikan script ini untuk keperluan anda**


### Anda Memang Luar Biasa | Harry DS Alsyundawy | Kaum Rebahan Garis Keras & Militan
