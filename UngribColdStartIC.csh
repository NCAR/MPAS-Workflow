#!/bin/csh -f

date

# Setup environment
# =================
source config/environmentJEDI.csh
source config/experiment.csh
source config/modeldata.csh
source config/builds.csh
source config/applications/initic.csh
source config/externalanalyses.csh
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

## link Vtable file
ln -sfv ${externalanalyses__Vtable} Vtable

## copy/modify dynamic namelist
rm ${NamelistFileWPS}
cp -v $ModelConfigDir/$AppName/${NamelistFileWPS} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFileWPS

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
