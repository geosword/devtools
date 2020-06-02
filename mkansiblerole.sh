#!/usr/bin/env bash
# Rudemintary check that we're being sourced. If you we dont source this script, then pip will NOT install
# to the virtualenvironment we just created
# https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
MOLECULESCAFFOLDURL="https://gitea.sectigo.net/dylanh/molecule-scaffold.git"
MASTERFOLDER=.molecule-scaffold

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
# check if this is a git repo already
if [[ -d .git ]]; then
	if ! git status | grep -q "nothing to commit"; then
		echo "Please commit or revert all changes before running this"
		return 1
	fi
fi

# PIP modules we want to run. molecule-ec2 adds ec2 support to molecule
PIPMODULES=(molecule molecule-ec2 docker boto boto3 botocore pre-commit)
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
	# create git repo assuming we're not already
	if [[ ! -d .git ]]; then
		# remove the stock molecule folder, we dont need it
		git init
		pre-commit install
		# we need to do an initial commit in order to allow adding of the molecule-scaffold via subtree
		# a subtree has been selected because it favours pulls over pushes in terms of simplicity.
		git add .
		git commit -n -m "initial commit"
		git subtree add --prefix=${MASTERFOLDER} --squash ${MOLECULESCAFFOLDURL} master
	fi
	if [[ ! -d "${MASTERFOLDER}" ]]; then
		echo "The expected folder ${MASTERFOLDER} was not present, please check the archive downloaded from source control"
		# return not exit because we are sourced, and dont want to kill the existing session
		return 1
	fi
	# copy in things which are reasonably likely to change
	[[ -f ${MASTERFOLDER}/.yamllint ]] && cp ${MASTERFOLDER}/.yamllint ./
	[[ -f ${MASTERFOLDER}/.gitignore ]] && cp ${MASTERFOLDER}/.gitignore ./
	[[ -f ${MASTERFOLDER}/meta-main.yml ]] && cp ${MASTERFOLDER}/meta-main.yml meta/main.yml
	if [[ -f ${MASTERFOLDER}/pre-commit-config.yaml ]]; then
		cp ${MASTERFOLDER}/pre-commit-config.yaml ./.pre-commit-config.yaml
	fi
	for i in converge.yml Dockerfile.j2 molecule.yml prepare.yml verify.yml; do
		[[ -f ${MASTERFOLDER}/molecule/default/${i} ]] && cp ${MASTERFOLDER}/molecule/default/${i} ./molecule/default/
	done
	# Symlink stuff that should remain reasonably static (or at least be updated in the molecule-scaffold repo)
	[[ -d ${MASTERFOLDER}/molecule/default/tasks ]] && ln -s ../../${MASTERFOLDER}/molecule/default/tasks ./molecule/default/tasks
	# SED the rolename into the converge playbook
	sed -i "s/\"rolename\"/\"${CWD}\"/g" molecule/default/converge.yml
	echo "Files have been modified, but not commited, use $ git status to check the situation"
	echo "If you already have a <insert favourite git hosting service here> you can add this to it with:"
	echo "$ git remote add origin https://git.example.com/user/repo.git"
	echo "$ git push origin master"
fi
