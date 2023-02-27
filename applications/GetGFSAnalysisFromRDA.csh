#!/bin/csh -f
# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: my location
set ArgWorkDir = "$2"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/auto/build.csh
source config/auto/experiment.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
set prevValidDate = `$advanceCYMDH ${thisCycleDate} -6`

source ./getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set ccyy = `echo ${thisValidDate} | cut -c 1-4`

set res = 0p25
set fhour = 000
set gribFile = ${ccyy}/${ccyymmdd}/gfs.${res}.${thisValidDate}.f${fhour}.grib2

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

if ( -e GETSUCCESS ) then
  echo "$0 (INFO): GETSUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the output files is desired, delete GETSUCCESS"

  date

  exit 0
endif

# ================================================================================================

set linkWPS = link_grib.csh
ln -sfv ${WPSBuildDir}/${linkWPS} .
rm -rf GRIBFILE.*

echo "Getting GFS analysis from RDA"
# RDA GFS forecasts directory
set GFSgribdirRDA = /gpfs/fs1/collections/rda/data/ds084.1

if ( ! -e ${GFSgribdirRDA}/${gribFile} ) then
   set preVyymmdd = `echo ${prevValidDate} | cut -c 1-8`
   set preVyy = `echo ${prevValidDate} | cut -c 1-4`
   set preVhh = `echo ${prevValidDate} | cut -c 9-10`
   set nexTfhour = 006
   set gribFile = ${preVyy}/${preVyymmdd}/gfs.${res}.${preVyymmdd}${preVhh}.f${nexTfhour}.grib2
endif

# link ungribbed GFS
./${linkWPS} ${GFSgribdirRDA}/${gribFile}

# check if the gribFile was linked
if ( ! -e "GRIBFILE.AAA") then
   echo "GRIBFILE.AAA is not in folder -- exiting"
   exit 1
endif

date

touch GETSUCCESS

exit 0
