#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out LocalEnsembleDA (EnKF) solver stage for ensemble of first guess states
# note: must follow successful observer stage

date

# Process arguments
# =================
## args

# None

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/enkf.csh
source config/auto/workflow.csh
source config/auto/members.csh
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
set myBuildDir = ${EnKFBuildDir}
set myEXE = ${EnKFEXE}
set myYAML = ${self_WorkDir}/${appyaml}

setenv OMP_NUM_THREADS ${solverThreads}

# ================================================================================================

## change to run directory
set runDir = run
cd ${runDir}

# Link+Run the executable
# =======================
ln -sfv ${myBuildDir}/${myEXE} ./

# asSolver
cp $myYAML solver.yaml
sed -i 's@{{driver}}@asSolver@' solver.yaml
sed -i 's@{{ObsDataIn}}@ObsDataOut@' solver.yaml
sed -i 's@\ \+{{ObsDataOut}}@@' solver.yaml
sed -i 's@{{ObsOutSuffix}}@@' solver.yaml
sed -i 's@{{ObsSpaceDistribution}}@HaloDistribution@' solver.yaml
mpiexec ./${myEXE} solver.yaml ./solver.log >& solver.log.all

#WITH DEBUGGER
#module load arm-forge/19.1
#setenv MPI_SHEPHERD true
#ddt --connect ./${myEXE} $myYAML ./jedi.log

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' solver.log
if ( $status != 0 ) then
  echo "ERROR in $0 : enkf solver failed" > ./FAIL
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

date

exit 0
