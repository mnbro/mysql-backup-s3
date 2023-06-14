# mysql-backup-s3

Backup MySQL to S3 (supports periodic backups, multi files, encryption and retention)

## Basic usage

```sh
$ docker run -e S3_ACCESS_KEY_ID=key -e S3_SECRET_ACCESS_KEY=secret -e S3_BUCKET=my-bucket -e S3_PREFIX=backup -e MYSQL_USER=user -e MYSQL_PASSWORD=password -e MYSQL_HOST=localhost schickling/mysql-backup-s3
```

## Environment variables

- `MYSQLDUMP_OPTIONS` mysqldump options (default: --quote-names --quick --add-drop-table --add-locks --allow-keywords --disable-keys --extended-insert --single-transaction --create-options --comments --net_buffer_length=16384)
- `MYSQLDUMP_EXTRA_OPTIONS` add mysqldump options without overriding the default `MYSQLDUMP_OPTIONS` (default: empty)
- `MYSQLDUMP_DATABASE` list of databases you want to backup (default: --all-databases)
- `MYSQL_HOST` the mysql host *required*
- `MYSQL_PORT` the mysql port (default: 3306)
- `MYSQL_USER` the mysql user *required*
- `MYSQL_PASSWORD` the mysql password *required*
- `MYSQL_USER_FILE` the mysql user if you use a docker swarm secret *required*
- `MYSQL_PASSWORD_FILE` the mysql password if you use a docker swarm secret *required*
- `PASSPHRASE_FILE` the file containing password used to encrypt dumps *required*
- `S3_ACCESS_KEY_ID` your AWS access key *required*
- `S3_SECRET_ACCESS_KEY` your AWS secret key *required*
- `S3_ACCESS_KEY_ID_FILE` your AWS access key if you use a docker swarm secret *required*
- `S3_SECRET_ACCESS_KEY_FILE` your AWS secret key if you use a docker swarm secret*required*
- `S3_BUCKET` your AWS S3 bucket path *required*
- `NOTIFICATIONS_SERVER_URL` your apprise-api server URL *required*
- `S3_FILENAME` a consistent filename to overwrite with your backup.  If not set will use a timestamp.
- `S3_REGION` the AWS S3 bucket region (default: us-west-1)
- `S3_ENDPOINT` the AWS Endpoint URL, for S3 Compliant APIs such as [minio](https://minio.io) (default: none)
- `S3_ENSURE_BUCKET_EXISTS` set to `no` to assume the bucket exists, avoiding the need of S3 read permissions (default: yes)
- `S3_S3V4` set to `yes` to enable AWS Signature Version 4, required for [minio](https://minio.io) servers (default: no)
- `MULTI_FILES` Allow to have one file per database if set `yes` default: no)
- `SCHEDULE` backup schedule time in [cron format](https://crontab.guru) like `7 2,14 * * *`
- `BACKUP_KEEP_DAYS` if set, backups older than this many days will be deleted from S3
- `WEBHOOK` these will be passed to curl and executed at the end of backup script 
