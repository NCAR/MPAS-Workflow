#!/bin/csh -f

date

# Setup environment
# =================
source config/environment.csh
source config/filestructure.csh
source config/modeldata.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set WorkDir = ${InitICWorkDir}/${thisValidDate}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

## link Vtable
set Vtable = Vtable.GFS_FV3
ln -sfv ${VtableDir}/${Vtable} Vtable

## copy/modify dynamic namelist
rm ${NamelistFileWPS}
cp -v ${initModelConfigDir}/${NamelistFileWPS} .
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
