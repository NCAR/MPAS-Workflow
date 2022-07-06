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

echo "Getting GFS analysis from RDA"
# RDA GFS forecasts directory
set GFSgribdirRDA = /gpfs/fs1/collections/rda/data/ds084.1
# link ungribbed GFS
./${linkWPS} ${GFSgribdirRDA}/${yy}/${yymmdd}/gfs.${res}.${yymmdd}${hh}.f${fhour}.grib2

date

exit 0
