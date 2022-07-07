#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

date

# Setup environment
# =================
source config/builds.csh
source config/experiment.csh
#source config/externalanalyses.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set WorkDir = ${ExternalAnalysisDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

set res = 0p25
set fhour = 000
set linkWPS = link_grib.csh
ln -sfv ${WPSBuildDir}/${linkWPS} .
rm -rf GRIBFILE.*

echo "Getting GFS analysis from the NCEP FTP"
# url for GFS data
set gfs_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.${yymmdd}/${hh}/atmos
set gfs_file = gfs.t${hh}z.pgrb2.${res}.f${fhour}
# check if the GFS analysis is available
if ( ! -e ${gfs_file}) then
  set gfs_ftp_file = ${gfs_ftp}/${gfs_file}
  wget -S --spider $gfs_ftp_file >&! log_check_gfs_f000
  grep "HTTP/1.1 200 OK" log_check_gfs_f000
  # if the file exists then download it
  # otherwise, exit with failure
  if ( $status == 0 ) then
    echo "Downloading $gfs_ftp_file ..."
    wget -r -np -nd $gfs_ftp_file
  else
    echo "$gfs_file not available yet -- exiting"
    exit 1
  endif
endif
# link ungribbed GFS
./${linkWPS} $gfs_file

date

exit 0
