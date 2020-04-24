#!/usr/bin/env bash
source /usr/bin/virtualenvwrapper.sh
CWD=$(basename $PWD)
# pseudo from here onwards
mkvirtualenv $CWD
pip install molecule docker boto boto3 botocore
pip freeze > requriements.txt
molecule init role $CWD
## NOTE --template option of molecule is documented but not implemented in version 3.03
mv $CWD/* ./
curl -L https://github.com/geosword/molecule-scaffold/archive/master.zip --output master.zip
[[ -f master.zip ]] && unzip master.zip && rm -r ./molecule/default
[[ -d molecule-scaffold-master ]] && mv molecule-scaffold-master/molecule/default ./molecule/default && rm -r molecule-scaffold-master
# cleanup
rm master.zip
