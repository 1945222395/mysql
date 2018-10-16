#! /bin/bash
git remote rm origin
git init
git add .
git status
git commit -m "$(date +%F_%H:%M:%S) commit"
git remote add origin git@github.com:lyc2395/mysql.git
git push -u origin master
