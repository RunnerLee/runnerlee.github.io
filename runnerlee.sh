#!/bin/bash

if [ -L $0 ]
then
    workpath=$(dirname `readlink $0`)
else
    workpath=$(cd `dirname $0`; pwd)
fi

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
  finder    open the blog folder in finder
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
elif [ "$1" == 'new' ]
then
    now=`date +%Y-%m-%d`
    filename=${workpath}"/_posts/"${now}-$2".md"
    touch ${filename}
    template ${now} $3 > ${filename}
    code ${workpath} ${filename}
elif [ "$1" == 'serve' ]
then
    cd ${workpath}
    jekyll serve
elif [ "$1" == 'finder' ]
then
    open ${workpath}
elif [ "$1" == 'path' ]
then
    echo $workpath
else
    printHelp
fi