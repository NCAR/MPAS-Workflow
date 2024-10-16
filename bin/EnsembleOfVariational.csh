#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out variational minimization for multiple first guess states (EDA)
# ARGUMENTS:
# ArgInstance - EDA instance among nDAInstances, each handling an (EDAsize)-member ensemble of
#               Variational minimizations in a single EnsembleOfVariational executable

date

# Process arguments
# =================
## args
# ArgInstance: int, EDA instance [>= 1]
set ArgInstance = "$1"

## arg checks
set test = `echo $ArgInstance | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgInstance ($ArgInstance) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgInstance < 1 ) then
  echo "ERROR in $0 : ArgInstance ($ArgInstance) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/variational.csh
source config/auto/workflow.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${EnsembleOfVariationalBuildDir}
set myEXE = ${EnsembleOfVariationalEXE}
set myYAML = ${self_WorkDir}/eda_${ArgInstance}.yaml

if ( $ArgInstance > $nDAInstances ) then
  echo "ERROR in $0 : ArgInstance ($ArgInstance) must be <= nDAInstances ($nDAInstances)" > ./FAIL
  exit 1
endif

# ================================================================================================

# The EnsembleOfVariational application requires a top-level yaml listing all member yamls
echo "files:" > $myYAML
set instance = 1
set member = 1
while ( $instance <= ${nDAInstances} )
  set myMember = 1
  while ( $myMember <= ${EDASize} )
    if ( $instance == ${ArgInstance} ) then
      # add eda-member yaml name to list of member yamls
      set memberyaml = ${YAMLPrefix}${member}.yaml
      echo "  - ${self_WorkDir}/$memberyaml" >> $myYAML
    endif

    @ myMember++
    @ member++
  end
  @ instance++
end

# ================================================================================================

## create then move to single run directory
set instDir = `${memberDir} 2 ${ArgInstance} "${flowInstanceFmt}"`
set runDir = run${instDir}
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
  set member = 1
  while ( $member <= ${nMembers} )
    set memDir = `${memberDir} $nMembers $member`
    rm ${self_WorkDir}/${OutDBDir}${memDir}/${obsPrefix}*.h5
    rm ${self_WorkDir}/${OutDBDir}${memDir}/${geoPrefix}*.nc4
    rm ${self_WorkDir}/${OutDBDir}${memDir}/${diagPrefix}*.nc4
    @ member++
  end
endif

# Remove netcdf lock files
rm *.nc*.lock
rm */*.nc*.lock

# Remove copies of templated fields files for inner loop
if ("${TemplateFieldsFileInner}" != "${TemplateFieldsFileOuter}") then
  rm ${TemplateFieldsFileInner}*
endif

date

exit 0
