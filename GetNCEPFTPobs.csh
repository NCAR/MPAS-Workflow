#!/bin/csh -f
# Get NCEP FTP BUFR/PrepBUFR files

date

# Setup environment
# =================
source config/workflow.csh
source config/observations.csh
source config/filestructure.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set ccyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set WorkDir = ${ObsDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

foreach inst ( ${convertToIODAObservations} )
  echo "Getting ${inst} from the NCEP FTP"
  # url for GDAS data
  set gdas_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gdas.${yymmdd}/${hh}/atmos
  # set name for the observation type
  if ( ${inst} == prepbufr ) then
    set THIS_FILE = gdas.t${hh}z.${inst}.nr
  else if ( ${inst} == gpsro ) then
    set THIS_FILE = gdas.t${hh}z.${inst}.tm00.bufr_d.nr
  else
    set THIS_FILE = gdas.t${hh}z.${inst}.tm00.bufr_d
  endif

  # check if the observation file is available
  if ( ! -e ${THIS_FILE}) then
    set ftp_file = ${gdas_ftp}/${THIS_FILE}
    wget -S --spider $ftp_file >&! log_check_${inst}
    grep "HTTP/1.1 200 OK" log_check_${inst}
    # if the file exists then download it
    # otherwise, exit with failure
    if ( $status == 0 ) then
     echo "Downloading $ftp_file ..."
     wget -r -np -nd $ftp_file
    else
     echo "$ftp_file not available yet -- exiting"
     exit 1
    endif
  else
    echo "$THIS_FILE is already in ${WorkDir}"
  endif
end

date

exit 0
