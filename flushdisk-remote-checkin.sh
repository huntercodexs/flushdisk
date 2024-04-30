#!/bin/bash

#How to use:
#./flushdisk-remote-checkin.sh [all, {SERVICE_NAME}]

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
	echo -e "${ERROR} Invalid parameter, use: ./flushdisk-remote-checkin.sh [all, {SERVICE_NAME}]"
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
        SSH_PUB_KEY=$(egrep "SSH_PUB_KEY=" "${CURRENT_FILE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\-]//g")
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

function remoteCheckin {
    COUNT_MD5_ERROR=0
    MD5_FLUSHDISK_SCRIPT=$(md5sum flushdisk.sh | cut -d " " -f1)
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

                echo -ne "\n${YELLOW_TEXT_COLOR}Checking${COLOR_CLOSE} ${ITEM_SERVICE} "
                if [[ "${SSH_USE_SUDO}" == "true" ]]
                then
                    sudo ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "ls -ltr ${FLUSHDISK_REMOTE_DIRECTORY}/"
                    echo -ne "${YELLOW_TEXT_COLOR}"
                    MD5_FLUSHDISK_SCRIPT_REMOTE=$(sudo ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "md5sum ${FLUSHDISK_REMOTE_DIRECTORY}/flushdisk.sh" | cut -d " " -f1)
                    echo -ne "${COLOR_CLOSE}"
                else
                    ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "ls -ltr ${FLUSHDISK_REMOTE_DIRECTORY}/"
                    echo -ne "${YELLOW_TEXT_COLOR}"
                    MD5_FLUSHDISK_SCRIPT_REMOTE=$(ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "md5sum ${FLUSHDISK_REMOTE_DIRECTORY}/flushdisk.sh" | cut -d " " -f1)
                    echo -ne "${COLOR_CLOSE}"
                fi
                if [[ "$?" == "0" && "${MD5_FLUSHDISK_SCRIPT}" == "${MD5_FLUSHDISK_SCRIPT_REMOTE}" ]]
                then
                    echo -ne "${OK}\n"
                else
                    echo -ne "${ERROR} [${MD5_FLUSHDISK_SCRIPT} - ${MD5_FLUSHDISK_SCRIPT_REMOTE}]\n"
                    COUNT_MD5_ERROR=1
                fi

            fi

        fi

    done

    if [[ "${COUNT_MD5_ERROR}" > 0 ]]
    then
        echo -ne "${ERROR} There is one or more flushdisk instance with wrong installation\n\n"
    else
        echo -ne "${BIGreen}Everything is fine !${COLOR_CLOSE} - MD5: ${MD5_FLUSHDISK_SCRIPT}\n\n"
    fi
}

listConfigurations
remoteCheckin
exit
