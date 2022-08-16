#!/bin/csh -f

# Process arguments
# =================
## args
# ArgWorkDir: my location
set ArgWorkDir = "$1"

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

## link Vtable file
ln -sfv ${externalanalyses__Vtable} Vtable

## copy/modify dynamic namelist
rm ${NamelistFileWPS}
cp -v $ModelConfigDir/initic/${NamelistFileWPS} .
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
