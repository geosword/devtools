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

# PIP modules we want to run. molecule-ec2 adds ec2 support to molecule
PIPMODULES=(molecule molecule-ec2 docker boto boto3 botocore)
CWD=$(basename $PWD)
# TODO check if we are already in a virtual environment called this, skip if so, fail with message if its
# a virtual environment thats NOT called basename $PWD
if [ ! -z "${VIRTUAL_ENV}" ]; then
	# we're ARE in a virtual environment (! -z == is NOT blank)
	# check if the virtual environment is "for" our PWD
	VENVNAME=$(basename ${VIRTUAL_ENV})
	if [ "${VENVNAME}" != "${CWD}" ]; then
		echo "I've detected you're in an existing virtual environment which is not ${CWD}, so Im refusing to go any further"
		return 1
	fi

	# Assume all the modules we want are installed, then check to see if any are not
	PIPINSTALLMODS=0
	# If we get here, we're already in a VENV, so check the modules we want are present
	PIPMODSINSTALLED=$(pip list | grep -vE "Package|--" | awk '{print $1}')
	for i in "${PIPMODULES[@]}"; do
		if ! echo ${PIPMODSINSTALLED} | grep -qE "^${i}$"; then
			# something is not installed, and should be, so install the lot, but only once
			PIPINSTALLMODS=1
			break
		fi
	done
else
	# we're not in a virtual environment, so crack on
	source /usr/bin/virtualenvwrapper.sh
	mkvirtualenv $CWD
	PIPINSTALLMODS=1
fi

if [[ "${PIPINSTALLMODS}" = 1 ]]; then
	pip install ${PIPMODULES[@]}
	pip freeze > requirements.txt
fi

# TODO. Do we need to even molecule init?
# https://github.com/ansible-community/molecule/issues/2657
# Could potentially just ansible galaxy (init?) and then copy in your molecule scaffold
# Dont run molecule init if a molecule folder already exists
if [[ ! -d molecule ]]; then
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
	[[ -f ${MASTERFOLDER}/.gitignore ]] && mv ${MASTERFOLDER}/.gitignore ./
	[[ -f ${MASTERFOLDER}/meta-main.yml ]] && mv ${MASTERFOLDER}/meta-main.yml meta/main.yml
	[[ -d ${MASTERFOLDER} ]] && mv ${MASTERFOLDER}/molecule/default ./molecule/default && rm -r ${MASTERFOLDER}
	# SED the rolename into the converge playbook
	sed -i "s/\"rolename\"/\"${CWD}\"/g" molecule/default/converge.yml
	# needs to be a git repo for molecule to lint. Also we skip this if its already a git repo
	[[ ! -d .git ]] && git init
	# cleanup
	rm master.zip
fi
