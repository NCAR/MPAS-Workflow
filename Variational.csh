#!/bin/csh -f

# Carry out variational minimization for single first guess state
# ARGUMENTS:
# ArgMember - member index among nEnsDAMembers

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
source config/experiment.csh
source config/builds.csh
source config/environment.csh
source config/mpas/variables.csh
source config/filestructure.csh
source config/tools.csh ${mainScriptDir}
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
set myBuildDir = ${VariationalBuildDir}
set myEXE = ${VariationalEXE}
set myYAML = ${self_WorkDir}/variational_${ArgMember}.yaml

if ( $ArgMember > $nEnsDAMembers ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be <= nEnsDAMembers ($nEnsDAMembers)" > ./FAIL
  exit 1
endif

# ================================================================================================

## create then move to member-specific run directory
set memDir = `${memberDir} ens ${ArgMember} "${flowMemFmt}"`
set runDir = run${memDir}
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
