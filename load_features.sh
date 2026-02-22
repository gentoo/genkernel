SCRIPT_DIR=$(dirname $0)
ls ${SCRIPT_DIR}/features/*/$1 > /dev/null 2>&1 && cat ${SCRIPT_DIR}/features/*/$1
