#!/bin/csh -f

# Carry out variational minimization for either
# + single first guess state (mpasjedi_variational.x)
# + multiple first guess states (mpasjedi_eda.x)

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
# note: not currently used, but will be for independent EDA members
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
source config/builds.csh
source config/environment.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADirs[1]
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# ================================================================================================

# Link+Run the executable
# =======================
ln -sfv ${VariationalBuildDir}/${VariationalEXE} ./
mpiexec ./${VariationalEXE} $appyaml ./jedi.log >& jedi.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${VariationalEXE} $appyaml ./jedi.log

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' jedi.log
if ( $status != 0 ) then
  echo "ERROR in $0 : jedi application failed" > ./FAIL
  exit 1
endif

date

exit 0
