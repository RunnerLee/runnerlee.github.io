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
else
    printHelp
fi