#!/bin/bash

workpath='/Users/runner/Code/Blog'

printHelp() {
    cat <<EOF
RunnerLee Blog

Usage:
  runnerlee.sh [command]

Commands:
  edit      open blog dictionary by vs code
  commit    commit change to remote repostiory
  new       create an new post
  serve     start jekyll serve
EOF
}

template() {
    cat <<EOF
---
layout: post
title: $2
date: $1
update_date: $1
summary: 
logo: 
---


EOF
}

if [ "$1" == 'edit' ]
then
    code ${workpath}
elif [ "$1" == 'commit' ]
then
    cd ${workpath}
    git add .
    git commit -m 'update'
    git push origin master
    git push coding master
elif [ "$1" == 'new' ]
then
    now=`date +%Y-%m-%d`
    filename=${workpath}"/_posts/"${now}-$2".md"
    template ${now} $3 > ${filename}
elif [ "$1" == 'serve' ]
then
    cd ${workpath}
    jekyll serve
else
    printHelp
fi