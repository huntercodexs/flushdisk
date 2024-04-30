#!/bin/bash

## Crontab
##flushdisk: minute, hour, day, month, week_days, command
##GMT(-03:00)
#0 9 * * * ${FLUSHDISK_PATH}/flushdisk-remote.sh [all,{SERVICE_NAME}] [clear, check] [{0,1}?] [{0,1}?] > /dev/null 2>&1

# Edit this variable before running the flushdisk
FLUSHDISK_PATH=$(echo $PWD)

OPERATION=$1
COMMAND=$2
AUTOMATIC=$3
FORCE=$4

SERVICE=
SSH_USERNAME=
SSH_HOST_ADDRESS=
FLUSHDISK_REMOTE_DIRECTORY=

TIMER_IN_SECONDS=1

function loadSystemColors {
    source flushdisk-system-colors.sh
}

function errorStarting {
    loadSystemColors
    echo ""
    echo -e "${ERROR} Invalid parameter, use:"
    echo -e "./flushdisk-remote.sh [all,{SERVICE_NAME}] [clear, check] [{0,1}?] [{0,1}?]"
    echo -e "                       ^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^   ^^^^^^   ^^^^^^"
    echo -e "                           OPERATION           COMMAND    AUTOMATIC  FORCE"
    echo ""
    exit
}

function makeLog {
    STATUS=$1
    MESSAGE=$2
    DATETIME_LOG=$(date +"%Y-%m-%d %T")

    REQUEST_TYPE="- MANUALLY"
    if [[ "${AUTOMATIC}" == "1" ]]
    then
        REQUEST_TYPE="- AUTOMATIC"
    fi

    if [[ "${STATUS}" == "start" ]]; then
        echo "${DATETIME_LOG} | INFO | flushdisk is Starting ${REQUEST_TYPE}" >> "${FLUSHDISK_PATH}/flushdisk-remote.log" 2>&1
    fi

    if [[ "${STATUS}" == "end" ]]; then
        echo "${DATETIME_LOG} | INFO | flushdisk is Finishing ${REQUEST_TYPE}" >> "${FLUSHDISK_PATH}/flushdisk-remote.log" 2>&1
    fi

    if [[ "${STATUS}" == "info" ]]; then
        echo "${DATETIME_LOG} | INFO | ${MESSAGE}" >> "${FLUSHDISK_PATH}/flushdisk-remote.log" 2>&1
    fi

    if [[ "${STATUS}" == "error" ]]; then
        echo "${DATETIME_LOG} | ERROR | ${MESSAGE}" >> "${FLUSHDISK_PATH}/flushdisk-remote.log" 2>&1
    fi
}

function sleeper {
    OP1=$1
    OP2=$2
    sleep $TIMER_IN_SECONDS
    if [[ "${OP1}" == "${OP2}" ]]
    then
        makeLog "info" "$OP1 is done"
    else
        makeLog "info" "$OP2 is done"
    fi
}

function listConfigurations {
    if [[ "${AUTOMATIC}" == "0" ]]
    then
        echo -e "${IMPORTANT} Maybe you will be requested to inform the root password to continue this process !"
        echo -e "Press [Enter] to continue"
        read ENTER
        sudo ls * >> /dev/null 2>&1
    fi
    ARRAY_SERVICES=(${FLUSHDISK_PATH}/remote-services-conf/*conf)
}

function createDirs {
    for (( i = 0; i < ${#ARRAY_SERVICES[@]}; i++ )); do
        ITEM_SERVICE=$(basename "${ARRAY_SERVICES[$i]}" | sed -e 's/\_/\-/g' | cut -d "." -f1)
        mkdir -p "${FLUSHDISK_PATH}/backup/${ITEM_SERVICE}"
    done
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
            ERROR_MSG="SERVICE is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${WARNING} ${ERROR_MSG}"
            echo ""
            makeLog "error" "${ERROR_MSG}"
        fi

        if [[ "${SSH_USERNAME}" == "" ]]; then
            ERROR_MSG="SSH_USERNAME is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${WARNING} ${ERROR_MSG}"
            echo ""
            makeLog "error" "${ERROR_MSG}"
        fi

        if [[ "${SSH_HOST_ADDRESS}" == "" ]]; then
            ERROR_MSG="SSH_HOST_ADDRESS is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${WARNING} ${ERROR_MSG}"
            echo ""
            makeLog "error" "${ERROR_MSG}"
        fi

        if [[ "${FLUSHDISK_REMOTE_DIRECTORY}" == "" ]]; then
            ERROR_MSG="FLUSHDISK_REMOTE_DIRECTORY is undefined in the configuration file ${CURRENT_FILE_CONFIG}"
            echo ""
            echo -e "${WARNING} ${ERROR_MSG}"
            echo ""
            makeLog "error" "${ERROR_MSG}"
        fi

    else
        ERROR_MSG="${ERROR} File not found ${CURRENT_FILE_CONFIG}"
        echo ""
        echo -e "${ERROR_MSG}"
        echo ""
        makeLog "error" "${ERROR_MSG}"
    fi
}

function remoteFlushdisk {
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

                echo -ne "\n${YELLOW_TEXT_COLOR}Flushing Remotely${COLOR_CLOSE} ${ITEM_SERVICE} "
                if [[ "${SSH_USE_SUDO}" == "true" ]]
                then
                    sudo ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "${FLUSHDISK_REMOTE_DIRECTORY}/flushdisk.sh ${SERVICE} ${COMMAND} ${FORCE} ${FLUSHDISK_REMOTE_DIRECTORY}"
                    sudo scp ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS}:${FLUSHDISK_REMOTE_DIRECTORY}/backup/*.tar.gz ${FLUSHDISK_PATH}/backup/${ITEM_SERVICE}/ >> /dev/null 2>&1
                    sudo ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "rm -rf ${FLUSHDISK_REMOTE_DIRECTORY}/backup/*.tar.gz" >> /dev/null 2>&1
                else
                    ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "${FLUSHDISK_REMOTE_DIRECTORY}/flushdisk.sh ${SERVICE} ${COMMAND} ${FORCE} ${FLUSHDISK_REMOTE_DIRECTORY}"
                    scp ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS}:${FLUSHDISK_REMOTE_DIRECTORY}/backup/*.tar.gz ${FLUSHDISK_PATH}/backup/${ITEM_SERVICE}/ >> /dev/null 2>&1
                    ssh ${SSH_PUB_KEY} ${SSH_USERNAME}@${SSH_HOST_ADDRESS} "rm -rf ${FLUSHDISK_REMOTE_DIRECTORY}/backup/*.tar.gz" >> /dev/null 2>&1
                fi
                echo -e "${OK}\n"

                sleeper ${OPERATION} "${SERVICE}"
            fi

        fi

    done
}

if [[ "${OPERATION}" == "" || "${COMMAND}" == "" || "${AUTOMATIC}" == "" || "${FORCE}" == "" ]]
then
    errorStarting
fi

if [[ "${COMMAND}" != "clear" && "${COMMAND}" != "check" ]]
then
    errorStarting
fi

makeLog "start"
loadSystemColors
listConfigurations
createDirs
remoteFlushdisk
makeLog "end"

exit
