#!/usr/bin/env bash
export PATH=$PATH:/usr/local/bin/:/usr/bin




###############################
##                           ##
## INITIATE SCRIPT FUNCTIONS ##
##                           ##
##  FUNCTIONS ARE EXECUTED   ##
##   AT BOTTOM OF SCRIPT     ##
##                           ##
###############################


#
# DOCUMENTS ARGUMENTS
#

usage() {
  echo -e "\nUsage: $0 [-d <days>]" 1>&2
  echo -e "\nOptions:\n"
  echo -e "    -d    Device name."
  echo -e "\n"
  echo -e "    -z    Device zone."
  echo -e "\n"
  echo -e "    -z    Device ID."
  echo -e "\n"
  echo -e "    -d    Number of snapshots to keep. Used of in conjunction with -n."
  echo -e "          Snapshots older than this number deleted."
  echo -e "          Default if not set: 7 [OPTIONAL]"
  echo -e "\n"
  echo -e "    -m    Days multiplier."
  echo -e "          Default if not set: 1 [OPTIONAL]"
  echo -e "\n"

  exit 1
}


#
# GETS SCRIPT OPTIONS AND SETS GLOBAL VAR $OLDER_THAN
#

setScriptOptions()
{
    while getopts ":d:n:m:z:i:" o; do
      case "${o}" in
        d)
          opt_d=${OPTARG}
          ;;
        m)
          opt_m=${OPTARG}
          ;;
	n)
	  opt_n=${OPTARG}
	  ;;
        z)
          opt_z=${OPTARG}
          ;;
        i)
          opt_i=${OPTARG}
          ;;
        *)
          usage
          ;;
      esac
    done
    #shift $((OPTIND-2))

    if [[ -n $opt_d ]];then
      OLDER_THAN=$opt_d
    else
      OLDER_THAN=7
    fi

    if [[ -n $opt_m ]];then
      DAYS_MULTIPLE=$opt_m
    else
      DAYS_MULTIPLE=1
    fi

    if [[ -n $opt_n ]];then
      DEVICE_NAME=$opt_n
    else
      echo "No device name given"
      usage
    fi

    if [[ -n $opt_z ]];then
      INSTANCE_ZONE=$opt_z
    else
      echo "No device zone given"
      usage
    fi

    if [[ -n $opt_i ]];then
      DEVICE_ID=$opt_i
    else
      echo "No device id given"
      usage
    fi

}


#
# RETURNS DEVICE NAME
#

getDeviceName()
{
    local vm_name="$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")"
    local device_name="$(gcloud compute disks list ${vm_name} --uri)"

    # local device_name="$(gcloud compute disks list --uri)"

    # strip device name out of response
    echo -e "${device_name##*/}"

    # Previous Method of getting device-name from MetaData
    #echo -e "$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/disks/0/device-name" -H "Metadata-Flavor: Google")"
}


#
# RETURNS DEVICE ID
#

getDeviceId()
{
    echo -e "$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")"
}


#
# RETURNS INSTANCE ZONE
#

getInstanceZone()
{
    local instance_zone="$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google")"

    # strip instance zone out of response
    echo -e "${instance_zone##*/}"
}


#
# RETURNS SNAPSHOT NAME
#

createSnapshotName()
{
    # create snapshot name
    local name="gcs-$1-$2-$3-$4"

    # google compute snapshot name cannot be longer than 62 characters
    local name_max_len=62

    # check if snapshot name is longer than max length
#    if [ ${#name} -ge ${name_max_len} ]; then

        # work out how many characters we require - prefix + device id + timestamp
#        local req_chars="gcs--$2-$3"

        # work out how many characters that leaves us for the device name
#        local device_name_len=`expr ${name_max_len} - ${#req_chars}`

        # shorten the device name
#        local device_name=${1:0:device_name_len}

        # create new (acceptable) snapshot name
#        name="gcs-${device_name}-$2-$3" ;

#   fi

    echo -e ${name}
}

#
# CREATES SNAPSHOT AND RETURNS OUTPUT
#
# input: ${DEVICE_NAME}, ${SNAPSHOT_NAME}, ${INSTANCE_ZONE}
#

createSnapshot()
{
 echo -e "$(gcloud compute disks snapshot $1 --snapshot-names $2 --zone $3)"
}


#
# GETS LIST OF SNAPSHOTS AND SETS GLOBAL ARRAY $SNAPSHOTS
#
# input: ${SNAPSHOT_REGEX}
# example usage: getSnapshots "(gcs-.*${DEVICE_ID}-.*)"
#

getSnapshots()
{
    # create empty array
    SNAPSHOTS=()

    # get list of snapshots from gcloud for this device
    local gcloud_response="$(gcloud compute snapshots list --regexp "$1" --uri)"

    # loop through and get snapshot name from URI
    while read line
    do
        # grab snapshot name from full URI
        snapshot="${line##*/}"

        # add snapshot to global array
        SNAPSHOTS+=(${snapshot})

    done <<< "$(echo -e "$gcloud_response")"

    # print out snapshots
    #echo -e ${SNAPSHOTS[@]}
}


#
# RETURNS SNAPSHOT CREATED DATE
#
# input: ${SNAPSHOT_NAME}
#

getSnapshotCreatedDate()
{
    local snapshot_datetime="$(gcloud compute snapshots describe $1 | grep "creationTimestamp" | cut -d " " -f 2 | tr -d \')"

    #  format date
    echo -e "$(date -d ${snapshot_datetime} +%Y%m%d)"
}


#
# RETURNS DELETION DATE FOR ALL SNAPSHOTS
#
# input: ${OLDER_THAN}
#

getSnapshotDeletionDate()
{
    echo -e "$(date -d "-$1 days" +"%Y%m%d")"
}


#
# RETURNS ANSWER FOR WHETHER SNAPSHOT SHOULD BE DELETED
#
# input: ${DELETION_DATE}, ${SNAPSHOT_CREATED_DATE}
#

checkSnapshotDeletion()
{
    if [ $1 -ge $2 ]

        then
            echo -e "1"
        else
            echo -e "2"

    fi
}


#
# DELETES SNAPSHOT
#
# input: ${SNAPSHOT_NAME}
#

deleteSnapshot()
{
echo 'Commented'
  #  echo -e "$(gcloud compute snapshots delete $1 -q)"
}


logTime()
{
    local datetime="$(date +"%Y-%m-%d %T")"
    echo -e "$datetime: $1"
}


#######################
##                   ##
## WRAPPER FUNCTIONS ##
##                   ##
#######################


createSnapshotWrapper()
{
    # log time
    logTime "Start of createSnapshotWrapper"

    # get date time
    DATE_TIME="$(date "+%s")"

    # get the device name
#    DEVICE_NAME=$(getDeviceName)

    # get the device id
#    DEVICE_ID=$(getDeviceId)

    # get the instance zone
#    INSTANCE_ZONE=$(getInstanceZone)
 
    # create snapshot name
    SNAPSHOT_NAME=$(createSnapshotName ${DAYS_MULTIPLE} ${DEVICE_NAME} ${DEVICE_ID} ${DATE_TIME})
    
    # create the snapshot
    OUTPUT_SNAPSHOT_CREATION=$(createSnapshot ${DEVICE_NAME} ${SNAPSHOT_NAME} ${INSTANCE_ZONE})
}

deleteSnapshotsWrapper()
{
    # log time
    logTime "Start of deleteSnapshotsWrapper"

    # get the deletion date for snapshots
    DELETION_DATE=$(getSnapshotDeletionDate "${OLDER_THAN}")

    # get list of snapshots for regex - saved in global array
    getSnapshots "(gcs-.*${DEVICE_ID}-.*)"

    # loop through snapshots
    for snapshot in "${SNAPSHOTS[@]}"
    do
        # get created date for snapshot
        SNAPSHOT_CREATED_DATE=$(getSnapshotCreatedDate ${snapshot})

        # check if snapshot needs to be deleted
        DELETION_CHECK=$(checkSnapshotDeletion ${DELETION_DATE} ${SNAPSHOT_CREATED_DATE})

        # delete snapshot
        if [ "${DELETION_CHECK}" -eq "1" ]; then
           OUTPUT_SNAPSHOT_DELETION=$(deleteSnapshot ${snapshot})
        fi

    done
}




##########################
##                      ##
## RUN SCRIPT FUNCTIONS ##
##                      ##
##########################

# log time
logTime "Start of Script"

# set options from script input / default value
setScriptOptions "$@"

# create snapshot
createSnapshotWrapper

# delete snapshots older than 'x' days
deleteSnapshotsWrapper

# log time
logTime "End of Script"
