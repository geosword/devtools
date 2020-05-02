#!/usr/bin/env bash
# Rudemintary check that we're being sourced. If you we dont source this script, then pip will NOT install
# to the virtualenvironment we just created
# https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
sourced=0
if [ -n "$ZSH_EVAL_CONTEXT" ]; then
  case $ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
elif [ -n "$KSH_VERSION" ]; then
  [ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ] && sourced=1
elif [ -n "$BASH_VERSION" ]; then
  (return 0 2>/dev/null) && sourced=1
else # All other shells: examine $0 for known shell binary filenames
  # Detects `sh` and `dash`; add additional shell filenames as needed.
  case ${0##*/} in sh|dash) sourced=1;; esac
fi

if [[ "${sourced}" != "1" ]]; then
	echo "FATAL: You need to source this script, otherwise it will not work as intended"
	exit 1
fi

source /usr/bin/virtualenvwrapper.sh
CWD=$(basename $PWD)
# pseudo from here onwards
mkvirtualenv $CWD
pip install molecule docker boto boto3 botocore
pip freeze > requirements.txt
molecule init role $CWD
## NOTE --template option of molecule is documented but not implemented in version 3.03
mv $CWD/* ./
rm -r $PWD/$CWD
curl -L https://gitea.sectigo.net/dylanh/molecule-scaffold/archive/master.zip --output master.zip
MASTERFOLDER=$(unzip -Zl master.zip | sed '1,2d;$d' | awk '{print $10}' | head -n 1 | tr -d '/')
[[ -f master.zip ]] && unzip master.zip && rm -r ./molecule/default
if [[ ! -d "${MASTERFOLDER}" ]]; then
	echo "The expected master folder was not present, please check the archive downloaded from source control"
	# return not exit because we are sourced, and dont want to kill the existing session
	return 1
fi
[[ -f ${MASTERFOLDER}/.yamllint ]] && mv ${MASTERFOLDER}/.yamllint ./
[[ -f ${MASTERFOLDER}/meta-main.yml ]] && mv ${MASTERFOLDER}/meta-main.yml meta/main.yml
[[ -d ${MASTERFOLDER} ]] && mv ${MASTERFOLDER}/molecule/default ./molecule/default && rm -r ${MASTERFOLDER}
# SED the rolename into the converge playbook
sed -i "s/\"rolename\"/\"${CWD}\"/g" molecule/default/converge.yml
# needs to be a git repo for molecule to lint
[[ ! -d .git ]] && git init
# cleanup
rm master.zip
