#!/bin/csh -f
# Get GFS analysis (0-h forecast) from Xingren's control run for cold start initial conditions

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/builds.csh
source config/experiment.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
set prevValidDate = `$advanceCYMDH ${thisCycleDate} -6`

source ./getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set ccyy = `echo ${thisValidDate} | cut -c 1-4`
set vhour = `echo ${thisValidDate} | cut -c 9-10`

set res = 0p25
set fhour = 000
set gribFile = gfs.${thisValidDate}/gfs.t${vhour}z.pgrb2b.${res}.f${fhour}

# static work directory
set WorkDir = ${ExternalAnalysisDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

set linkWPS = link_grib.csh
ln -sfv ${WPSBuildDir}/${linkWPS} .
rm -rf GRIBFILE.*

echo "Getting GFS analysis from SIOCW3E"
# SIOCW3E GFS forecasts directory
set GFSgribdirSIOCW3E = /glade/scratch/ivette/sio/ctrl

if ( ! -e ${GFSgribdirSIOCW3E}/${gribFile} ) then
   set preVyymmdd = `echo ${prevValidDate} | cut -c 1-8`
   set preVyy = `echo ${prevValidDate} | cut -c 1-4`
   set preVhh = `echo ${prevValidDate} | cut -c 9-10`
   set nexTfhour = 006
   set gribFile = gfs.${preVyymmdd}${preVhh}/gfs.t${preVhh}z.pgrb2b.${res}.f${nexTfhour}
endif

# link ungribbed GFS
./${linkWPS} ${GFSgribdirSIOCW3E}/${gribFile}

# check if the gribFile was linked
if ( ! -e "GRIBFILE.AAA") then
   echo "GRIBFILE.AAA is not in folder -- exiting"
   exit 1
endif

date

exit 0
