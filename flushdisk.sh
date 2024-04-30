#!/bin/bash

## Crontab
##flushdisk: minute, hour, day, month, week_days, command
#0 6 * * * ${FLUSHDISK_PATH}/flushdisk.sh [all, SERVICE_NAME] [clear, check] [{0, 1}?] [FLUSHDISK_PATH] > /dev/null 2>&1

# Edit this variable before running the flushdisk
FLUSHDISK_PATH=$(echo $PWD)

TARGET_SERVICE=$1
CMD=$2
FORCE=$3 #force flushdisk to clean up the log path
FLUSHDISK_PATH_REMOTE=$4

HD_SIZE=0
HD_USED=0
HD_FREE=0
HD_FREE_SCALE=G
HD_PERCENT=0

INFO=
RESULT=""
OPERATION=""
CLEAN_EXECUTE=0
CMD_LIST="[check|clear|list]"

SERVICE=
LOG_NAME=
LOG_PATH=
TOMCAT_PATH=
HD_TYPE="nvme"
SHOW_DETAILS="false"
MIN_FREE_DISK=2
MAX_PERCENT_DISK=95
MAX_SIZE_LOGS=200
REMOTE_CONTROL=

function terminalPrint {
    if [[ "${REMOTE_CONTROL}" == "false" || "$2" == "print" ]]
    then
        echo -ne "\n$1"
    fi
}

function errorStarting {
    loadSystemColors

    terminalPrint "" "print"
    terminalPrint "${ERROR} Invalid parameter, use:" "print"
    terminalPrint "./flushdisk.sh [all, SERVICE_NAME] [clear, check] [{0, 1}?] [FLUSHDISK_PATH]" "print"
    terminalPrint "                ^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^   ^^^^^^^   ^^^^^^^^^^^^^^ " "print"
    terminalPrint "                     SERVICE           COMMAND      FORCE         PATH      " "print"
    terminalPrint "" "print"
    exit
}

function loadSystemColors {
    source ${FLUSHDISK_PATH}/flushdisk-system-colors.sh
}

function defineFlushdiskFinalPath {
    if [[ "${FLUSHDISK_PATH_REMOTE}" != "" ]]
    then
        FLUSHDISK_PATH=${FLUSHDISK_PATH_REMOTE}
    fi
    loadSystemColors
}

function listConfigurationFiles {
    defineFlushdiskFinalPath
    ARRAY_SERVICES=(${FLUSHDISK_PATH}/services-conf/*conf)
}

function makeLog {
    STATUS=$1
    MESSAGE=$2
    DATETIME_LOG=$(date +"%Y-%m-%d %T")

    if [[ "${STATUS}" == "start" ]]; then
        echo "${DATETIME_LOG} | INFO | flushdisk is Starting" >> "${FLUSHDISK_PATH}/flushdisk.log" 2>&1
    fi

    if [[ "${STATUS}" == "end" ]]; then
        echo "${DATETIME_LOG} | INFO | flushdisk is Finishing" >> "${FLUSHDISK_PATH}/flushdisk.log" 2>&1
    fi

    if [[ "${STATUS}" == "info" ]]; then
        echo "${DATETIME_LOG} | INFO | ${MESSAGE}" >> "${FLUSHDISK_PATH}/flushdisk.log" 2>&1
    fi

    if [[ "${STATUS}" == "error" ]]; then
        echo "${DATETIME_LOG} | ERROR | ${MESSAGE}" >> "${FLUSHDISK_PATH}/flushdisk.log" 2>&1
    fi
}

function list {
    echo -ne "${YELLOW_TEXT_COLOR}"
    for (( i = 0; i < ${#ARRAY_SERVICES[@]}; i++ )); do
        ID=$(printf "%2d" $i)
        ITEM_SERVICE=$(basename "${ARRAY_SERVICES[$i]}" | sed -e 's/\_/\-/g' | cut -d "." -f1)
        echo -ne "\n${ID} - ${ITEM_SERVICE}"
    done
    echo -ne "${COLOR_CLOSE}\n\n"
}

function operation {
    case $1 in

        "check")
            OPERATION="Checking "
            ;;
        "clear")
            OPERATION="Cleaning "
            ;;
        *)
            OPERATION=""
            ;;
    esac

    if [[ "${OPERATION}" == "" ]]; then
        echo -e "${ERROR} Invalid parameter, use: ./flushdisk.sh ${CMD_LIST}"
        makeLog "error" "Invalid parameter, use: ./flushdisk.sh ${CMD_LIST}"
        exit
    fi
}

function result {

    if [[ $2 == 200 ]]; then

        case $1 in

            "list")
                RESULT="${UP}"
                ;;
            "check")
                RESULT="${CLEAN}"
                ;;
            "clear")
                RESULT="${DONE}"
                ;;
            *)
                RESULT="${UNKNOWN}"
                ;;
        esac

    elif [[ $2 == 400 || $2 == 144 ]]; then

        case $1 in

            "list")
                RESULT="${CHECK}"
                ;;
            "check")
                RESULT="${DIRTY}"
                ;;
            "clear")
                RESULT="${ERROR}"
                ;;
            *)
                RESULT="${UNKNOWN}"
                ;;
        esac

    elif [[ $2 == 404 || $2 == 148 ]]; then

        case $1 in

            "list")
                RESULT="${EMPTY}"
                ;;
            "check")
                RESULT="${EMPTY}"
                ;;
            "clear")
                RESULT="${EMPTY}"
                ;;
            *)
                RESULT="${UNKNOWN}"
                ;;
        esac

    elif [[ $2 == 500 ]]; then

        case $1 in

            "list")
                RESULT="${ERROR}"
                ;;
            "check")
                RESULT="${ERROR}"
                ;;
            "clear")
                RESULT="${ERROR}"
                ;;
            *)
                RESULT="${UNKNOWN}"
                ;;
        esac
    fi
}

function details {

    if [[ "${SHOW_DETAILS}" == "true" ]]; then

        HD_SIZE_LITERAL=$(df -h | grep "${HD_TYPE}" | egrep -o "([0-9]+[.]?)+[MG]" | head -1)
        HD_USED_LITERAL=$(df -h | grep "${HD_TYPE}" | egrep -o "([0-9]+[.]?)+[MG]" | head -2 | tail -1)
        HD_FREE_LITERAL=$(df -h | grep "${HD_TYPE}" | egrep -o "([0-9]+[.]?)+[MG]" | tail -1)
        HD_PERCENT_LITERAL=$(df -h | grep "${HD_TYPE}" | egrep -o "[0-9]+%")

        echo ""
        echo -e "${YELLOW_TEXT_COLOR}--------- DETAILS ---------${COLOR_CLOSE}"

        echo -e "${GREEN_TEXT_COLOR}[configuration]${COLOR_CLOSE}"
        echo "HD_TYPE: ${HD_TYPE}"
        echo "MIN_FREE_DISK: ${MIN_FREE_DISK}G"
        echo "MAX_PERCENT_DISK: ${MAX_PERCENT_DISK}%"
        echo "MAX_SIZE_LOGS: ${MAX_SIZE_LOGS}M"

        echo -e "${GREEN_TEXT_COLOR}[System]${COLOR_CLOSE}"
        echo "HD_SIZE: ${HD_SIZE_LITERAL}"
        echo "HD_USED: ${HD_USED_LITERAL}"
        echo "HD_FREE: ${HD_FREE_LITERAL}"
        echo "HD_PERCENT: ${HD_PERCENT_LITERAL}"

        echo ""
        echo -e "${BICyan}SHOW_DETAILS is [yes], you can set this field as [no] to ignore this advise${COLOR_CLOSE}"
        echo "Press [Enter] to continue: "
        read KEYBOARD
    fi

    if [[ "${REMOTE_CONTROL}" == "false" ]]
    then
        echo -e "${IMPORTANT} Maybe you will be requested to inform the root password to continue this process !"
        echo -e "Press [Enter] to continue"
        read ENTER
        sudo ls * >> /dev/null 2>&1
    fi

}

function readInitialConfiguration {
    if ls "${FLUSHDISK_PATH}/flushdisk.conf" >> /dev/null 2>&1
    then
        SHOW_DETAILS=$(egrep "SHOW_DETAILS=" "${FLUSHDISK_PATH}/flushdisk.conf" | cut -d "=" -f2 | sed -e "s/[^a-z]//g")
        HD_TYPE=$(egrep "HD_TYPE=" "${FLUSHDISK_PATH}/flushdisk.conf" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z]//g")
        MIN_FREE_DISK=$(egrep "MIN_FREE_DISK=" "${FLUSHDISK_PATH}/flushdisk.conf" | cut -d "=" -f2 | sed -e "s/[^0-9]//g")
        MAX_PERCENT_DISK=$(egrep "MAX_PERCENT_DISK=" "${FLUSHDISK_PATH}/flushdisk.conf" | cut -d "=" -f2 | sed -e "s/[^0-9]//g")
        MAX_SIZE_LOGS=$(egrep "MAX_SIZE_LOGS=" "${FLUSHDISK_PATH}/flushdisk.conf" | cut -d "=" -f2 | sed -e "s/[^0-9]//g")
        REMOTE_CONTROL=$(egrep "REMOTE_CONTROL=" "${FLUSHDISK_PATH}/flushdisk.conf" | cut -d "=" -f2 | sed -e "s/[^a-z]//g")
    else
        ERROR_MSG="[START]: File not found ${FLUSHDISK_PATH}/flushdisk.conf"
        echo ""
        echo -e "${CRITICAL} ${ERROR_MSG}"
        echo ""
        makeLog "error" "${ERROR_MSG}"
        makeLog "error" "Leaving..."
        exit
    fi
}

function readServiceConfiguration {

    CLEAN_EXECUTE=1
    SERVICE_CONFIG_FILE=$1
    SERVICE_CONFIG="${FLUSHDISK_PATH}/services-conf/${SERVICE_CONFIG_FILE}.conf"

    if ls "${SERVICE_CONFIG}" >> /dev/null 2>&1
    then

        SERVICE=$(egrep "SERVICE=" "${SERVICE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\-]//g")
        LOG_NAME=$(egrep "LOG_NAME=" "${SERVICE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\-]//g")
        LOG_PATH=$(egrep "LOG_PATH=" "${SERVICE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\-]//g")
        TOMCAT_PATH=$(egrep "TOMCAT_PATH=" "${SERVICE_CONFIG}" | cut -d "=" -f2 | sed -e "s/[^0-9a-zA-Z\_\/\-]//g")

        if [[ "${SERVICE}" == "" ]]; then
            ERROR_MSG="Service Name is undefined in the configuration file ${SERVICE_CONFIG}"
            echo ""
            echo -e "${WARNING} ${ERROR_MSG}"
            echo ""
            makeLog "error" "${ERROR_MSG}"
            CLEAN_EXECUTE=0
        fi

    else
        ERROR_MSG="[SERVICE] File not found ${SERVICE_CONFIG}"
        echo ""
        echo -e "${CRITICAL} ${ERROR_MSG}"
        echo ""
        makeLog "error" "${ERROR_MSG}"
        CLEAN_EXECUTE=0
    fi
}

function loadSystemInformation {
    HD_SIZE=$(df -h | grep "${HD_TYPE}" | egrep -o "[0-9][.]?[0-9][G]" | head -1 | sed -e "s/[^0-9]//g")
    HD_USED=$(df -h | grep "${HD_TYPE}" | egrep -o "[0-9][.]?[0-9][G]" | head -2 | tail -1 | sed -e "s/[^0-9]//g")
    HD_FREE=$(df -h | grep "${HD_TYPE}" | egrep -o "[0-9][.]?[0-9][G]" | tail -1 | sed -e "s/\.[0-9]*//g" | sed -e "s/[^0-9]//g")
    HD_PERCENT=$(df -h | grep "${HD_TYPE}" | egrep -o "[0-9]+%" | sed -e "s/[^0-9]//g")
}

function defineCleanExecute {
    if [[ "${HD_FREE}" -le "${MIN_FREE_DISK}" || "${HD_PERCENT}" -ge "${MAX_PERCENT_DISK}" || "${FORCE}" == "1" ]]; then
        terminalPrint "Flush Disk: Running !"
        details
        echo ""
        mkdir -p "${FLUSHDISK_PATH}/backup"
        CLEAN_EXECUTE=1
    else
        terminalPrint "Flush Disk: Everything is ${OK} !"
        details
        terminalPrint "Flush Disk: Leaving..."
        makeLog "info" "Flush Disk: Everything is OK !"
        exit
    fi
}

function loading {

    terminalPrint ""
    terminalPrint "Flush Disk: Loading system information"
    terminalPrint ""
    sleep 1
    
    readInitialConfiguration
    loadSystemInformation
}

function checkGzLog {

    if [[ ${CLEAN_EXECUTE} == 0 ]]; then
        return 200
    fi

	if ls ${LOG_PATH}/${LOG_NAME}*.gz >> /dev/null 2>&1
	then

		cd ${LOG_PATH}/ >> /dev/null 2>&1

		LOGS_AMOUNT=$(du -csh ${LOG_PATH}/${LOG_NAME}*.gz | tail -1)
		NUMERIC_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/\.[0-9]//g" | sed -e "s/[^0-9]//g")
		SCALE_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/[^KMG]//g")

        if [[ "${SCALE_SIZE}" == "G" ]] #Giga Byte
        then
            NUMERIC_SIZE=$(expr ${NUMERIC_SIZE} \* 1024) #Convert to MB
        fi

		if [[ "${NUMERIC_SIZE}" -gt "${MAX_SIZE_LOGS}" && "${SCALE_SIZE}" != "K" ]]; then
            INFO="LOGS_SIZE(GZ): ${NUMERIC_SIZE}MB, MAX_SIZE_LOGS: ${MAX_SIZE_LOGS}MB"
            return 400
		fi

		cd - >> /dev/null 2>&1
		return 200

	else
		return 404
	fi
}

function checkLog {

    if [[ ${CLEAN_EXECUTE} == 0 ]]; then
        return 200
    fi

	if ls ${LOG_PATH}/${LOG_NAME}*.log >> /dev/null 2>&1
	then
		
		cd ${LOG_PATH}/ >> /dev/null 2>&1
		
		LOGS_AMOUNT=$(du -csh ${LOG_PATH}/${LOG_NAME}*.log | tail -1)
		NUMERIC_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/\.[0-9]//g" | sed -e "s/[^0-9]//g")
		SCALE_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/[^KMG]//g")

        if [[ "${SCALE_SIZE}" == "G" ]] #Giga Byte
        then
            NUMERIC_SIZE=$(expr ${NUMERIC_SIZE} \* 1024) #Convert to MB
        fi

		if [[ "${NUMERIC_SIZE}" -gt "${MAX_SIZE_LOGS}" && "${SCALE_SIZE}" != "K" ]]; then
            INFO="LOGS_SIZE: ${NUMERIC_SIZE}MB, MAX_SIZE_LOGS: ${MAX_SIZE_LOGS}MB"
            return 400
		fi

		cd - >> /dev/null 2>&1
		return 200

	else
		return 404
	fi
}

function clearGzLog {

    if [[ ${CLEAN_EXECUTE} == 0 ]]; then
        return 200
    fi

    if ls ${LOG_PATH}/${LOG_NAME}*.gz >> /dev/null 2>&1
    then

        cd ${LOG_PATH}/ >> /dev/null 2>&1

        LOGS_AMOUNT=$(du -csh ${LOG_PATH}/${LOG_NAME}*.gz | tail -1)
        NUMERIC_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/\.[0-9]//g" | sed -e "s/[^0-9]//g")
        SCALE_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/[^KMG]//g")

        if [[ "${SCALE_SIZE}" == "G" ]] #Giga Byte
        then
            NUMERIC_SIZE=$(expr ${NUMERIC_SIZE} \* 1024) #Convert to MB
        fi

        if [[ "${NUMERIC_SIZE}" -gt "${MAX_SIZE_LOGS}" && "${SCALE_SIZE}" != "K" || "${FORCE}" == "1" ]]; then

            MSG="LOGS_SIZE(GZ): ${NUMERIC_SIZE}MB, MAX_SIZE_LOGS: ${MAX_SIZE_LOGS}MB"

            DATETIME=$(date +"%Y-%m-%d %T" | sed -e "s/[^0-9]//g")
            TAR_FILENAME="${DATETIME}-${LOG_NAME}-backup.log.gz.tar.gz"
            tar -czf ${TAR_FILENAME} ${LOG_NAME}*.gz >> /dev/null 2>&1
            R_TAR=$?

            ls ${LOG_PATH}/${TAR_FILENAME} >> /dev/null 2>&1
            R_LIST=$?

            if [[ ${R_TAR} == 0 || ${R_LIST} == 0 ]]; then

                cd - >> /dev/null 2>&1
                mv ${LOG_PATH}/${TAR_FILENAME} "${FLUSHDISK_PATH}/backup/" >> /dev/null 2>&1
                rm -f ${LOG_PATH}/${LOG_NAME}*.log*.gz >> /dev/null 2>&1

                makeLog "info" "${LOG_PATH}/ | ${MSG}"

                return 200

            else

                cd - >> /dev/null 2>&1
                INFO="(GZ Files) Something went wrong during the flushdisk"
                makeLog "error" "(GZ Files) Something went wrong during the flushdisk: ${R_TAR}, ${R_LIST}"

                return 500

            fi

        fi

        cd - >> /dev/null 2>&1
        return 200

    else
        return 404
    fi
}

function clearLog {

    if [[ ${CLEAN_EXECUTE} == 0 ]]; then
        return 200
    fi

    if ls ${LOG_PATH}/${LOG_NAME}*.log >> /dev/null 2>&1
    then

        cd ${LOG_PATH}/ >> /dev/null 2>&1

        LOGS_AMOUNT=$(du -csh ${LOG_PATH}/${LOG_NAME}*.log | tail -1)
        NUMERIC_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/\.[0-9]//g" | sed -e "s/[^0-9]//g")
        SCALE_SIZE=$(echo ${LOGS_AMOUNT} | sed -e "s/[^KMG]//g")

        if [[ "${SCALE_SIZE}" == "G" ]] #Giga Byte
        then
            NUMERIC_SIZE=$(expr ${NUMERIC_SIZE} \* 1024) #Convert to MB
        fi

        if [[ "${NUMERIC_SIZE}" -gt "${MAX_SIZE_LOGS}" && "${SCALE_SIZE}" != "K" || "${FORCE}" == "1" ]]; then

            MSG="LOGS_SIZE: ${NUMERIC_SIZE}MB, MAX_SIZE_LOGS: ${MAX_SIZE_LOGS}MB"

            DATETIME=$(date +"%Y-%m-%d %T" | sed -e "s/[^0-9]//g")
            TAR_FILENAME="${DATETIME}-${LOG_NAME}-backup.log.tar.gz"
            tar -czf ${TAR_FILENAME} ${LOG_NAME}*.log >> /dev/null 2>&1
            R_TAR=$?

            ls ${LOG_PATH}/${TAR_FILENAME} >> /dev/null 2>&1
            R_LIST=$?

            if [[ ${R_TAR} == 0 || ${R_LIST} == 0 ]]; then

                cd - >> /dev/null 2>&1
                mv ${LOG_PATH}/${TAR_FILENAME} "${FLUSHDISK_PATH}/backup/" >> /dev/null 2>&1
                rm -f ${LOG_PATH}/${LOG_NAME}-*.log >> /dev/null 2>&1
                rm -f ${LOG_PATH}/${LOG_NAME}.*.log >> /dev/null 2>&1

                makeLog "info" "${LOG_PATH}/ | ${MSG}"

                return 200

            else

                cd - >> /dev/null 2>&1
                INFO="Something went wrong during the flushdisk"
                makeLog "error" "Something went wrong during the flushdisk: ${R_TAR}, ${R_LIST}"

                return 500

            fi

        fi

        cd - >> /dev/null 2>&1
        return 200

    else
        return 404
    fi
}

function check {
    for (( i = 0; i < ${#ARRAY_SERVICES[@]}; i++ )); do
        ITEM_SERVICE=$(basename "${ARRAY_SERVICES[$i]}" | sed -e 's/\_/\-/g' | cut -d "." -f1)

        if [[ "${TARGET_SERVICE}" == "all" || "${ITEM_SERVICE}" == "${TARGET_SERVICE}" ]]
        then
            readServiceConfiguration "${ITEM_SERVICE}"

            echo -ne "\nGZ Logs ${OPERATION} ${ITEM_SERVICE} - "
            checkGzLog
            result "check" $?
            echo -ne "${RESULT} ${RED_TEXT_COLOR}${INFO}${COLOR_CLOSE}\n"
            INFO=""

            echo -ne "\nLogs ${OPERATION} ${ITEM_SERVICE} - "
            checkLog
            result "check" $?
            echo -ne "${RESULT} ${RED_TEXT_COLOR}${INFO}${COLOR_CLOSE}\n"
            INFO=""
        fi
    done
}

function clear {
    for (( i = 0; i < ${#ARRAY_SERVICES[@]}; i++ )); do
        ITEM_SERVICE=$(basename "${ARRAY_SERVICES[$i]}" | sed -e 's/\_/\-/g' | cut -d "." -f1)

        if [[ "${TARGET_SERVICE}" == "all" || "${ITEM_SERVICE}" == "${TARGET_SERVICE}" ]]
        then
            readServiceConfiguration "${ITEM_SERVICE}"

            echo -ne "\nGZ Logs ${OPERATION} ${ITEM_SERVICE} - "
            clearGzLog "${ITEM_SERVICE}"
            result "clear" $?
            echo -ne "${RESULT} ${RED_TEXT_COLOR}${INFO}${COLOR_CLOSE}\n"
            INFO=""

            echo -ne "\nLogs ${OPERATION} ${ITEM_SERVICE} - "
            clearLog "${ITEM_SERVICE}"
            result "clear" $?
            echo -ne "${RESULT} ${RED_TEXT_COLOR}${INFO}${COLOR_CLOSE}\n"
            INFO=""
        fi
    done

    echo ""
    echo -e "${YELLOW_TEXT_COLOR}Your current backup log files in: ${FLUSHDISK_PATH}/backup${COLOR_CLOSE}"
    echo "---------------------------------------------------------------------"
    ls -ltr ${FLUSHDISK_PATH}/backup/
    echo ""
}

function flushdisk {

    listConfigurationFiles

    if [[ $1 == "list" ]]; then
        list
        exit
    fi

    loading
    operation $1
    defineCleanExecute

    if [[ $1 == "check" ]]; then
	    check
	fi

    if [[ $1 == "clear" ]]; then
	    clear
	fi
}

makeLog "start"

if [[ "${CMD}" == "check" || "${CMD}" == "clear" || "${CMD}" == "list" ]]; then
    flushdisk ${CMD}
    terminalPrint ""
    terminalPrint "Finished !"
    terminalPrint ""
    makeLog "end"
    exit
else
    errorStarting
fi
