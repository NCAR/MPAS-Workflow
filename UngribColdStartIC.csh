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
echo "WorkDir = ${InitICDir}"
mkdir -p ${InitICDir}
cd ${InitICDir}

# ================================================================================================

## link ungribbed GFS
set fhour = 000
set Vtable = Vtable.GFS_FV3
set linkWPS = link_grib.csh
set GFSprefix = gfs.0p25
rm -rf GRIBFILE.*
ln -sfv ${WPSBuildDir}/${linkWPS} .
./${linkWPS} ${GFSgribdirRDA}/${yy}/${yymmdd}/${GFSprefix}.${yymmdd}${hh}.f${fhour}.grib2

## copy Vtable
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
