#!/bin/csh -f

# Carry out variational minimization for either
# multiple first guess states (EDA)

date

# Setup environment
# =================
source config/builds.csh
source config/environment.csh
source config/mpas/variables.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${EnsembleOfVariationalBuildDir}
set myEXE = ${EnsembleOfVariationalEXE}
set myYAML = ${self_WorkDir}/$appyaml

# ================================================================================================

# The EnsembleOfVariational application requires a top-level yaml listing all member yamls
echo "files:" > $myYAML
set member = 1
while ( $member <= ${nEnsDAMembers} )
  # add eda-member yaml name to list of member yamls
  set memberyaml = variational_${member}.yaml
  echo "  - ${self_WorkDir}/$memberyaml" >> $myYAML
  @ member++
end

## create then move to single run directory
set runDir = run
rm -r ${runDir}
mkdir -p ${runDir}
cd ${runDir}

## link MPAS-Atmosphere lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link stream_list.atmosphere.* files
ln -sfv ${self_WorkDir}/stream_list.atmosphere.* ./

## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv ${ModelConfigDir}/${file} .
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

date

exit 0
