#!/usr/bin/env bash
mkdir -p ~/log
mongod --smallfiles --fork --logpath ~/log/mongodb.log --dbpath /data/db/
mongo < /opt/configure_users.js
mongod --shutdown