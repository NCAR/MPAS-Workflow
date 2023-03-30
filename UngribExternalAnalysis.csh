#!/bin/csh -f

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
source config/environmentJEDI.csh
source config/experiment.csh
source config/builds.csh
source config/applications/initic.csh
source config/externalanalyses.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

# static work directory
set WorkDir = ${ExternalAnalysisDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

## link Vtable file
ln -sfv ${externalanalyses__Vtable} Vtable

## copy/modify dynamic namelist
rm ${NamelistFileWPS}
cp -v $ModelConfigDir/$AppName/${NamelistFileWPS} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFileWPS
sed -i 's@{{UngribPrefix}}@'${externalanalyses__UngribPrefix}'@' $NamelistFileWPS

# Run the executable
# ==================
rm ./${ungribEXE}
ln -sfv ${WPSBuildDir}/${ungribEXE} ./
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
