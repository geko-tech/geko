#!/usr/bin/bash

# TODO: Github
rm -rf /etc/apt/sources.list /etc/apt/sources.list.d
echo "deb [trusted=yes] REPLACE_ME jammy main restricted universe multiverse" >/etc/apt/sources.list &&
	echo "deb [trusted=yes] REPLACE_ME jammy-updates main restricted universe multiverse" >>/etc/apt/sources.list &&
	echo "deb [trusted=yes] REPLACE_ME jammy-backports main restricted universe multiverse" >>/etc/apt/sources.list &&
	echo "deb [trusted=yes] REPLACE_ME jammy-security main restricted universe multiverse" >>/etc/apt/sources.list

apt-get update && apt-get install -y s3cmd
