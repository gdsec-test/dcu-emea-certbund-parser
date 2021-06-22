# certbund-parser

Parsing CERT-BUND reports and create separate mails per ip

Requests/Features/Bugs: wolfgang.stuermer@godaddy.com (GPG: ECA89874452B3091 - https://keys.openpgp.org/vks/v1/by-fingerprint/26D973412D15AA0300F10FC2ECA89874452B3091)

This will probably not work outside intergenia environment.

If you have not a system where this parser has already been set up, you need to clone this repository to a system, which is allowed to access the configured database host.

To setup the database connection, create a .db.conf into the main directory of this software with following content:
---

MY_SERVER=database_host ### ip or hostname of the database server
MY_USER=database_user ### username to access the database server
MY_PWD=database_password ### password for the database user
MY_DB=database ### database name where ip addresses are stored
---


At first you've to think of which report you want to sent out. Valid are all names stored in mail_templates/subject.txt
In the main directory, you've to create a plain textfile "module.iplist", where 'module' is the name of the service you want to notify (same as for the txt-file in mail_templates and the sudject-parameter in mail_templates/subject.txt).

--- example of an iplist ---

"asn","ip","timestamp","malware","src_port","dst_ip","dst_port","dst_host","proto"
"30083","69.64.52.38","2021-06-21 04:50:50","suppobox","54702","85.214.228.140","80","tradebranch.net","tcp"
"8972","92.204.55.85","2021-06-21 00:16:44","magecart","48120","208.100.26.245","443","","tcp"

--- /example of an iplist ---


Then you can run it like:
./mail.sh module # where module again is the name of the iplist and mail_template file.

--- example of execution ---

[15:46:27] wstuermer@supporttools1:/opt/CERTBUND$ ./mail.sh malware
ip seems not to be a valid IPv4 address. Skip.
69.64.52.38 reported to ig-abuse-24@heg.com
148.72.169.210 not found in Database. Skipping
148.72.169.210 has been skipped.
69.64.52.38 reported to ig-abuse-24@heg.com
69.64.52.38 reported to ig-abuse-24@heg.com
92.204.55.85 not found in Database. Skipping
92.204.55.85 has been skipped.
176.28.10.130 not found in Database. Skipping
176.28.10.130 has been skipped.
217.118.19.168 reported to ig-abuse-24@heg.com
69.64.52.38 reported to ig-abuse-24@heg.com
69.64.52.38 reported to ig-abuse-24@heg.com
69.64.52.38 reported to ig-abuse-24@heg.com
69.64.52.38 reported to ig-abuse-24@heg.com
69.64.52.38 reported to ig-abuse-24@heg.com

--- /example of execution ---


To do a test run, you can add 'stg' as 2nd parameter to mail.sh, which will sent all mails to abuse-mgmt@hosteurope.de instead of the configured address by module.
