#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out variational minimization for single first guess state
# ARGUMENTS:
# ArgMember - member index among nMembers

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
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/members.csh
source config/auto/variational.csh
source config/auto/workflow.csh
source config/auto/model.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${VariationalBuildDir}
set myEXE = ${VariationalEXE}
set myYAML = ${self_WorkDir}/${YAMLPrefix}${ArgMember}.yaml

if ( $ArgMember > $nMembers ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be <= nMembers ($nMembers)" > ./FAIL
  exit 1
endif

# Remove old netcdf lock files
rm *.nc*.lock
rm */*.nc*.lock

# ================================================================================================

## create then move to member-specific run directory
set memDir = `${memberDir} 2 ${ArgMember} "${flowMemFmt}"`
set runDir = run${memDir}
rm -r ${runDir}
mkdir -p ${runDir}
cd ${runDir}

## link MPAS-Atmosphere lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

if (${MicrophysicsOuter} == 'mp_thompson' ) then
  ln -svf $MPThompsonTablesDir/* .
endif

## link stream_list.atmosphere.* files
ln -sfv ${self_WorkDir}/stream_list.atmosphere.* ./

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file .
end

# Link+Run the executable
# =======================
ln -sfv ${myBuildDir}/${myEXE} ./

sed -i 's@{{ObsDataIn}}@ObsDataIn@' $myYAML
sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' $myYAML
sed -i 's@{{ObsOutSuffix}}@@' $myYAML

mpiexec ./${myEXE} $myYAML ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${myEXE} $myYAML ./jedi.log

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

# ================================================================================================

# Remove obs-database output files
# ================================
if ("$retainObsFeedback" != True) then
  set memDir = `${memberDir} $nMembers $ArgMember`
  echo "ls ${self_WorkDir}/${OutDBDir}${memDir}/"
  ls ${self_WorkDir}/${OutDBDir}${memDir}/
  echo "rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5"
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5
  echo "rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4"
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4
  echo "rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4"
  rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4
endif

# Remove netcdf lock files
rm *.nc*.lock
rm */*.nc*.lock

# Remove copies of templated fields files for inner loop
if ("${TemplateFieldsFileInner}" != "${TemplateFieldsFileOuter}") then
  echo "rm ${TemplateFieldsFileInner}*"
  rm ${TemplateFieldsFileInner}*
endif

date

exit 0
