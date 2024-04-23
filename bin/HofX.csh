#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

# ArgWorkDir: str, where to run
set ArgWorkDir = "$3"

# ArgStateDir: directory of model state input
set ArgStateDir = "$4"

# ArgStatePrefix: prefix of model state input
set ArgStatePrefix = "$5"

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

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

# Setup environment
# =================
source config/environmentJEDI.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/hofx.csh
source config/auto/model.csh
source config/auto/staticstream.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

if ( "$ArgStateDir" =~ "*prevCycleDate*" ) then
  set StateDir = ${ExperimentDirectory}/`echo "$ArgStateDir" \
    | sed 's@{{prevCycleDate}}@'${prevCycleDate}'@' \
    `
else if ( "$ArgStateDir" =~ "*thisCycleDate*" ) then
  set StateDir = ${ExperimentDirectory}/`echo "$ArgStateDir" \
    | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
    `
else
  set StateDir = ${ExperimentDirectory}/$ArgStateDir
endif

# build, executable, yaml
set myBuildDir = ${HofXBuildDir}
set myEXE = ${HofXEXE}
set myYAML = ${WorkDir}/$appyaml

# Remove old logs
rm jedi.log*

# Remove old netcdf lock files
rm *.nc*.lock

# Remove old static fields in case this directory was used previously
rm ${localStaticFieldsPrefix}*.nc*

# ==================================================================================================

## copy static fields
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
set StaticMemDir = `${memberDir} 2 $ArgMember "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# Link/copy bg from other directory
# =================================
set bg = ./${backgroundSubDir}
mkdir -p ${bg}

set bgFileOther = ${StateDir}/${ArgStatePrefix}.$thisMPASFileDate.nc
set bgFile = ${bg}/${BGFilePrefix}.$thisMPASFileDate.nc

rm ${bgFile}${OrigFileSuffix} ${bgFile}
ln -sfv ${bgFileOther} ${bgFile}${OrigFileSuffix}
ln -sfv ${bgFileOther} ${bgFile}

# use the background as the TemplateFieldsFileOuter
ln -sfv ${bgFile} ${TemplateFieldsFileOuter}

# Run the executable
# ==================
ln -sfv ${myBuildDir}/${myEXE} ./
mpiexec ./${myEXE} $myYAML ./jedi.log >& jedi.log.all


# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

# ================================================================================================

## change static fields to a link, keeping for transparency
rm ${localStaticFieldsFile}
mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}

# Remove netcdf lock files
rm *.nc*.lock

# Remove unnecessary model state files
# ====================================
rm ${WorkDir}/${backgroundSubDir}/${BGFilePrefix}.$thisMPASFileDate.nc

# Remove obs-database output files
# ================================
if ("$retainObsFeedback" != True) then
  rm ${WorkDir}/${OutDBDir}/${obsPrefix}*.h5
  rm ${WorkDir}/${OutDBDir}/${geoPrefix}*.nc4
  rm ${WorkDir}/${OutDBDir}/${diagPrefix}*.nc4
endif

date

exit 0
