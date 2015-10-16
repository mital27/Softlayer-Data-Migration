Before running the migration script you need to install python swift client on your system. Please refer "Steps to install swiftclient" to install it.

Once the client is installed follow below steps:
1) Download datamigration.sh to a VM.
2) Copy app.cfg at the same location where the script is downloaded.
3) Modify working directory to the location where you want to keep all the files.
4) Provide SL account and location details for the source and destination in app.cfg.
5) Provide thread count to be used while downloading the data (Default will be used as 10) in app.cfg.
6) Provide the chunk size that you want to use during the upload app.cfg. 
7) Provide container names to be migrated. Seperate with comma in case of multiple containers app.cfg.
8) Rename file "accountname_location.sh" to youraccountname_location.sh, and provide the details as per your SL account and location for source and destination.
9) Please keep source_objects to "all" always.