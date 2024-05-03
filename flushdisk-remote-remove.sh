#!/bin/bash

#How to use:
#./flushdisk-remote-remove.sh [all, {SERVICE_NAME}]

# Edit this variable before running the flushdisk
FLUSHDISK_PATH=$(echo $PWD)

OPERATION=$1

SERVICE=
SSH_USERNAME=
SSH_HOST_ADDRESS=
FLUSHDISK_REMOTE_DIRECTORY=

source flushdisk-system-colors.sh

if [[ "${OPERATION}" == "" ]]
then
	echo ""
	echo -e "${ERROR} Invalid parameter, use: ./flushdisk-remote-remove.sh [all, {SERVICE_NAME}]"
	echo ""
	exit
fi

function listConfigurations {
    echo -e "${IMPORTANT} Maybe you will be requested to inform the root password to continue this process !"
    echo -e "Press [Enter] to continue"
    read ENTER
    sudo ls * >> /dev/null 2>&1
    ARRAY_SERVICES=(${FLUSHDISK_PATH}/remote-services-conf/*conf)
}

function readServiceConfiguration {
    SERVICE_CONFIG_FILE=$1
    CURRENT_FILE_CONFIG="${FLUSHDISK_PATH}/remote-services-conf/${SERVICE_CONFIG_FILE}.conf"

    if ls "${CURRENT_FILE_CONFIG}" >> /dev/null 2>&1
    then
        SERVICE=$(egrep "SERVICE=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\-]//g")
        SSH_USE_SUDO=$(egrep "SSH_USE_SUDO=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^a-z]//g")
        SSH_USERNAME=$(egrep "SSH_USERNAME=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\-]//g")
        SSH_HOST_ADDRESS=$(egrep "SSH_HOST_ADDRESS=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9\.]//g")
        SSH_PUB_KEY=$(egrep "SSH_PUB_KEY=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\.\-]//g")
        FLUSHDISK_REMOTE_DIRECTORY=$(egrep "FLUSHDISK_REMOTE_DIRECTORY=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\-]//g")

        if [[ "${SERVICE}" == "" ]]; then
            ERROR_MSG="${WARNING} SERVICE is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${ERROR_MSG}"
            echo ""
        fi

        if [[ "${SSH_USERNAME}" == "" ]]; then
            ERROR_MSG="${WARNING} SSH_USERNAME is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${ERROR_MSG}"
            echo ""
        fi

        if [[ "${SSH_HOST_ADDRESS}" == "" ]]; then
            ERROR_MSG="${WARNING} SSH_HOST_ADDRESS is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${ERROR_MSG}"
            echo ""
        fi

        if [[ "${FLUSHDISK_REMOTE_DIRECTORY}" == "" ]]; then
            ERROR_MSG="${WARNING} FLUSHDISK_REMOTE_DIRECTORY is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${ERROR_MSG}"
            echo ""
        fi

    else
        ERROR_MSG="${ERROR} File not found ${CURRENT_FILE_CONFIG}"
        echo ""
        echo -e "${ERROR_MSG}"
        echo ""
    fi
}

function remoteRemove {
    for (( i = 0; i < ${#ARRAY_SERVICES[@]}; i++ )); do
        ITEM_SERVICE=$(basename "${ARRAY_SERVICES[$i]}" | sed -e 's/\_/\-/g' | cut -d "." -f1)
        if [[ ${OPERATION} == "all" || ${OPERATION} == "${ITEM_SERVICE}" ]]
        then

            readServiceConfiguration ${ITEM_SERVICE}

            if [[ "${SERVICE}" != "" && ${SSH_USERNAME} != "" && "${FLUSHDISK_REMOTE_DIRECTORY}" != "" && "${SSH_HOST_ADDRESS}" != "" ]]
            then

                if [[ "${SSH_PUB_KEY}" != "" ]]
                then
                    SSH_PUB_KEY="-i ${SSH_PUB_KEY}"
                fi

                echo -ne "\n${YELLOW_TEXT_COLOR}Removing${COLOR_CLOSE} ${ITEM_SERVICE} "
                if [[ "${SSH_USE_SUDO}" == "true" ]]
                then
                    sudo ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "rm -rf ${FLUSHDISK_REMOTE_DIRECTORY}"
                else
                    ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "rm -rf ${FLUSHDISK_REMOTE_DIRECTORY}"
                fi
                if [[ "$?" == "0" ]]
                then
                    echo -ne "- ${OK}\n"
                else
                    echo -ne "- ${ERROR}\n"
                fi

            fi

        fi

    done
}

listConfigurations
remoteRemove
exit
