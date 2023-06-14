#!/bin/sh

# exit if a command fails
set -eo pipefail

apk update

# install mysqldump
apk add mysql-client
apk add mariadb-connector-c

# install gpg
apk add gnupg

# install curl
apk add curl

# install s3 tools
apk add python3 py3-pip
pip install awscli

# cleanup
rm -rf /var/cache/apk/*
