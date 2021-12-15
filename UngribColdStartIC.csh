#!/bin/csh -f

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/filestructure.csh
source config/modeldata.csh
source config/builds.csh
source config/environment.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $FirstICDirs[$ArgMember]
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# static variables
set self_InitICConfigDir = $initICModelConfigDir
# ================================================================================================

## link ungribbed GFS
rm -rf GRIBFILE.*
set fhour = 000
ln -sfv ${linkWPSdir}/${linkWPS} ${linkWPS} 
./${linkWPS} ${GFSgribdirRDA}/${yy}/${yymmdd}/${GFSprefix}.${yymmdd}${hh}.f${fhour}.grib2

## copy Vtable
ln -sfv ${VtableDir}/${Vtable} Vtable

## copy/modify dynamic namelist
rm ${NamelistFileWPS}
cp -v ${self_InitICConfigDir}/${NamelistFileWPS} ${NamelistFileWPS}
sed -i 's@startTime@'${NMLDate}'@' $NamelistFileWPS

# Run the executable
# ==================
rm ./${ungribEXE}
ln -sfv ${ungribBuildDir}/${ungribEXE} ./
./${ungribEXE}

# Check status
# ============
grep "Successful completion of program ${ungribEXE}" ungrib.log
if ( $status != 0 ) then
  echo "ERROR in $0 : Ungrib failed" > ./FAIL
  exit 1
endif

date

exit 0
