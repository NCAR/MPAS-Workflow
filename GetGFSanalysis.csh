#!/bin/csh -f
# Get GFS analysis for cold start initial conditions

date

# Setup environment
# =================
source config/workflow.csh
source config/model.csh
source config/observations.csh
source config/filestructure.csh
source config/builds.csh
source config/${InitializationType}ModelData.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
echo "WorkDir = ${InitICWorkDir}/${thisValidDate}"
mkdir -p ${InitICWorkDir}/${thisValidDate}
cd ${InitICWorkDir}/${thisValidDate}

# ================================================================================================

set res = 0p25
set fhour = 000
set linkWPS = link_grib.csh
ln -sfv ${WPSBuildDir}/${linkWPS} .
rm -rf GRIBFILE.*

if ( ${AnaSource} == "GFSRDAOnline" ) then
  ## RDA GFS forecasts}
  set GFSgribdirRDA = /gpfs/fs1/collections/rda/data/ds084.1 #${GFSRDADirectory}
  ## link ungribbed GFS
  ./${linkWPS} ${GFSgribdirRDA}/${yy}/${yymmdd}/gfs.${res}.${yymmdd}${hh}.f${fhour}.grib2
else if ( ${AnaSource} == "GFSNCEPFTPOnline" ) then
  set gfs_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gfs.${yymmdd}/${hh}/atmos
  set gfs_file = gfs.t${hh}z.pgrb2.${res}.f${fhour}
  echo $gfs_file
  if ( ! -e ${gfs_file}) then
    set gfs_ftp_file = ${gfs_ftp}/${gfs_file}
    wget -S --spider $gfs_ftp_file >&! log_check_gfs_f000
    grep "HTTP/1.1 200 OK" log_check_gfs_f000
    if ( $status == 0 ) then
     echo "Downloading $gfs_ftp_file ..."
     wget -r -np -nd $gfs_ftp_file
    else
     echo "$gfs_file not available yet -- waiting"
     exit 1
    endif
  else
    echo "$gfs_file is already in ${WorkDir}"
  endif
  ## link ungribbed GFS
  ./${linkWPS} $gfs_file
endif

date

exit 0
