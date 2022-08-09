#!/bin/sh

action=$1
argv_second=$2


RED_COLOR='\033[1;31m' #red
GREEN_COLOR='\033[1;32m' #grreen
YELOW_COLOR='\033[1;33m' #yellow
BLUE_COLOR='\033[1;34m' #blue
PINK='\033[1;35m' #pink
RES='\033[0m' #reset


ARGV_HELP="--help"
SELF_NAME="podspec.sh"

PWD_PATH=`pwd`
DIR_NAME=`dirname $0`

ROOT_PATH=${PWD_PATH}
if [[ ${DIR_NAME} != '.' ]]; then
    ROOT_PATH="${PWD_PATH}/${DIR_NAME}"
fi
echo "ROOT_PATH: ${ROOT_PATH}"


PODSPEC_FILE_NAME='MIWireSessioniOS'
PACKAGE_SHELL_SCRIPT_PATH="${ROOT_PATH}/packageShell/build.sh"
SCRIPTS_DIR="${ROOT_PATH}/scripts"
EDIT_CODE_REPO_SCRIPT_PATH="${SCRIPTS_DIR}/EditCodeRepoInfo.py"


func_top_help ()
{
    echo "
Usage:
\t${GREEN_COLOR}sh ${SELF_NAME} <action> ${RES}${PINK}<params>${RES}

Actions:
\t${GREEN_COLOR}lint${RES}\tcheck pod validation, no need params
\t${GREEN_COLOR}push${RES}\tpublish pod, and add git tag if need"
    exit 0
}


func_lint ()
{
    param=$1
    if [[ "${ARGV_HELP}" = "${param}" ]]; then
        echo "
Usage:
\t${GREEN_COLOR}sh ${SELF_NAME} lint${RES}
\tcheck pod validation, no need params"
        exit 0
    fi
    pod lib lint ${PODSPEC_FILE_NAME}.podspec --verbose --allow-warnings --no-clean
}


func_push ()
{
    param=$1
    if [[ "${ARGV_HELP}" = "${param}" ]]; then
    echo "
Usage:
\t${GREEN_COLOR}sh ${SELF_NAME} push ${RES}${PINK}<tag>${RES}
\tpublish pod, and add git tag if need

Params:
\t${PINK}<tag>${RES}\tavaliable, add git tag if not null"
        exit 0
    fi

    if [[ "123${param}" != "123" ]]; then
        tag_name="iOS-${param}"
        echo "add tag ${tag_name} ..."
        tag_exist_check=$(git tag -l | grep ^${tag_name}$)
        if [[ "${tag_exist_check}" = "${tag_name}" ]]; then
            echo "${RED_COLOR}tag already existed!${RES}"
            exit 1
        fi
        git tag -a ${tag_name} -m "${tag_name}"
        git push --tags
        echo "add tag finished"
    fi
    echo "publish..."
    pod trunk push ${PODSPEC_FILE_NAME}.podspec --verbose --allow-warnings
}


if [[ "$action" = "${ARGV_HELP}" ]]; then
    func_top_help
elif [[ "$action" = "lint" ]]; then
    func_lint ${argv_second}
elif [[ "$action" = "push" ]]; then
    func_push ${argv_second}
else
    echo "${RED_COLOR}Invalid action!${RES}\nTry --help to get more information."
fi
