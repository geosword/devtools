#!/usr/bin/env bash
source /usr/bin/virtualenvwrapper.sh
CWD=$(basename $PWD)
# pseudo from here onwards
mkvirtualenv $CWD
pip install molecule docker
pip freeze > requriements.txt
molecule init role $CWD
mv $CWD/$CWD/*
wget https://github.com/your_standard/gitignore
wget https://github.com/your_standard/Dockerfile - could perhaps allow a command line argument to specify this
