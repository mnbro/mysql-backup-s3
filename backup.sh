#!/bin/sh

set -eo pipefail

if [ "${S3_ACCESS_KEY_ID}" == "**None**" ] &&  [ "${S3_ACCESS_KEY_ID_FILE}" == "**None**" ]; then
  echo "Warning: You did not set the S3_ACCESS_KEY_ID or S3_ACCESS_KEY_ID_FILE environment variable."
fi

if [ "${S3_SECRET_ACCESS_KEY}" == "**None**" ] &&  [ "${S3_SECRET_ACCESS_KEY_FILE}" == "**None**" ]; then
  echo "Warning: You did not set the S3_SECRET_ACCESS_KEY environment variable."
fi

if [ "${S3_BUCKET}" == "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${MYSQL_HOST}" == "**None**" ]; then
  echo "You need to set the MYSQL_HOST environment variable."
  exit 1
fi

if [ "${MYSQL_USER}" == "**None**" ] && [ "${MYSQL_USER_FILE}" == "**None**" ]; then
  echo "You need to set the MYSQL_USER or MYSQL_USER_FILE environment variable."
  exit 1
fi

if [ "${MYSQL_PASSWORD}" == "**None**" ] && [ "${MYSQL_PASSWORD_FILE}" == "**None**" ]; then
  echo "You need to set the MYSQL_PASSWORD or MYSQL_PASSWORD_FILE environment variable or link to a container named MYSQL."
  exit 1
fi

if [ "${PASSPHRASE_FILE}" == "**None**" ]; then
  echo "You need to set the PASSPHRASE_FILE environment variable in order to encrypt the backup."
  exit 1
fi

if [ "${NOTIFICATIONS_SERVER_URL}" == "**None**" ]; then
  echo "You need to set the NOTIFICATIONS_SERVER_URL in order to receive alerts for failed backups"
  exit 1
fi

if [ "${WEBHOOK}" == "**None**" ]; then
  echo "You need to set the WEBHOOK environment variable in order to monitor backup execution."
  exit 1
fi

if [ "${S3_IAMROLE}" != "true" ]; then
  # env vars needed for aws tools - only if an IAM role is not used
  export AWS_DEFAULT_REGION=$S3_REGION

  if [ "${S3_SECRET_ACCESS_KEY_FILE}" == "**None**" ]; then
    export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
  else
    export AWS_SECRET_ACCESS_KEY=$(cat $S3_SECRET_ACCESS_KEY_FILE)
  fi

  if [ "${S3_ACCESS_KEY_ID_FILE}" == "**None**" ]; then
    export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
  else
    export AWS_ACCESS_KEY_ID=$(cat $S3_ACCESS_KEY_ID_FILE)
  fi
fi

if [ "${MYSQL_PASSWORD_FILE}" != "**None**" ]; then
    export MYSQL_PASSWORD=$(cat $MYSQL_PASSWORD_FILE)
fi

if [ "${MYSQL_USER_FILE}" != "**None**" ]; then
    export MYSQL_USER=$(cat $MYSQL_USER_FILE)
fi

MYSQL_HOST_OPTS="-h $MYSQL_HOST -P $MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD"
DUMP_START_TIME=$(date +"%Y-%m-%dT%H%M%SZ")
export PASSPHRASE=$(cat ${PASSPHRASE_FILE})

copy_s3 () {
  SRC_FILE=$1
  DEST_FILE=$2
  DB=$3

  if [ "${S3_ENDPOINT}" == "**None**" ]; then
    AWS_ARGS=""
  else
    AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
  fi

  echo "Uploading ${DEST_FILE} on S3..."

  cat $SRC_FILE | aws $AWS_ARGS s3 cp - s3://$S3_BUCKET/$DB/$DEST_FILE

  if [ $? -ne 0 ]; then
    >&2 curl -X POST -F "body=Error uploading ${DEST_FILE} on S3" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
  fi

  rm $SRC_FILE
}

# mysqldump extra options
if [ ! -z "${MYSQLDUMP_EXTRA_OPTIONS}" ]; then
  MYSQLDUMP_OPTIONS="${MYSQLDUMP_OPTIONS} ${MYSQLDUMP_EXTRA_OPTIONS}"
fi

# Multi file: yes
if [ ! -z "$(echo $MULTI_FILES | grep -i -E "(yes|true|1)")" ]; then
  if [ "${MYSQLDUMP_DATABASE}" == "--all-databases" ]; then
    DATABASES=`mysql $MYSQL_HOST_OPTS -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys|innodb)"`
  else
    DATABASES=$MYSQLDUMP_DATABASE
  fi

  for DB in $DATABASES; do
    echo "Creating individual dump of ${DB} from ${MYSQL_HOST}..."

    DUMP_FILE="/tmp/${DB}.sql.gz"

    mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS --databases $DB | gzip > $DUMP_FILE

    if [ $? -eq 0 ]; then
      if [ "${S3_FILENAME}" == "**None**" ]; then
        echo "Encrypting backup..."
        gpg --symmetric --batch --passphrase "$PASSPHRASE" $DUMP_FILE
          if [ $? -eq 0 ]; then
            S3_FILE="${DUMP_START_TIME}.${DB}.sql.gz.gpg"
          else
            >&2 curl -X POST -F "body=Error encrypting dump of ${DB}" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
          fi
      else
        echo "Encrypting backup..."
        gpg --symmetric --batch --passphrase "$PASSPHRASE" $DUMP_FILE
          if [ $? -eq 0 ]; then
            S3_FILE="${S3_FILENAME}.${DB}.sql.gz.gpg"
          else
            >&2 curl -X POST -F "body=Error encrypting dump of ${DB}" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
          fi
      fi

      copy_s3 "${DUMP_FILE}.gpg" $S3_FILE "${DB}"
      rm -f "${DUMP_FILE}.gpg" "${DUMP_FILE}"
    else
      >&2 curl -X POST -F "body=Error creating dump of ${DB}" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
    fi
  done
# Multi file: no
else
  curl -X POST -F "body=Creating dump for ${MYSQLDUMP_DATABASE} from ${MYSQL_HOST}..." -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}

  DUMP_FILE="/tmp/dump.sql.gz"
  mysqldump $MYSQL_HOST_OPTS $MYSQLDUMP_OPTIONS $MYSQLDUMP_DATABASE | gzip > $DUMP_FILE

  if [ $? -eq 0 ]; then
    if [ "${S3_FILENAME}" == "**None**" ]; then
      echo "Encrypting backup..."
      gpg --symmetric --batch --passphrase "$PASSPHRASE" $DUMP_FILE
        if [ $? -eq 0 ]; then
          S3_FILE="${DUMP_START_TIME}.dump.sql.gz.gpg"
        else
          >&2 curl -X POST -F "body=Error encrypting dump of ${DB}" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
        fi
    else
      echo "Encrypting backup..."
      gpg --symmetric --batch --passphrase "$PASSPHRASE" $DUMP_FILE
        if [ $? -eq 0 ]; then
          S3_FILE="${S3_FILENAME}.sql.gz.gpg"
        else
          >&2 curl -X POST -F "body=Error encrypting dump of ${DB}" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
        fi
    fi

    copy_s3 "${DUMP_FILE}.gpg" $S3_FILE "${DB}"
    rm -f "${DUMP_FILE}.gpg" "${DUMP_FILE}"
  else
    >&2 curl -X POST -F "body=Error creating dump of all databases" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
  fi
fi

echo "SQL backup finished"

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws $AWS_ARGS s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws $AWS_ARGS s3 rm s3://"${S3_BUCKET}"/'KEY'
  if [ $? -eq 0 ]; then
    echo "Removal complete."
  else
    >&2 curl -X POST -F "body=Removal of old backups failed" -F 'title=Mysql Backup Error' ${NOTIFICATIONS_SERVER_URL}
  fi
fi

curl ${WEBHOOK}