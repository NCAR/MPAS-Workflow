#!/bin/csh -f
# Remove observations after applying the thinning QC during the HOFX application

date

# Setup environment
# =================
source config/model.csh
source config/experiment.csh
source config/builds.csh
source config/applications/hofx.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = ${thisCycleDate}

source ./getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`

# static work directory
set WorkDir = ${ObsDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

echo "observationsToThinning = " ${observationsToThinning}
#set fhour = 000

#echo "Getting GDAS atm and sfc analyses from the NCEP FTP"
# url for GDAS data
#set gdas_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gdas.${ccyymmdd}/${hh}/atmos
#set gdasAnaInfix = (atm sfc sfluxgrb)

#foreach anaInfix ($gdasAnaInfix)

#end

date

exit 0
