#!/bin/csh -f

# Carry out LocalEnsembleDA (EnKF) for ensemble of first guess states

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
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${EnKFBuildDir}
set myEXE = ${EnKFEXE}
set myYAML = ${self_WorkDir}/${appyaml}

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

# above results in many extra lines in jedi.log that look like this:
#Point: {331.052,-26.6242} distance to center: {58.1612,49.5563} = 1.20277e+07
#Point: {331.214,-26.6555} distance to center: {58.1612,49.5563} = 1.20193e+07
#Point: {332.038,-26.8133} distance to center: {58.1612,49.5563} = 1.19765e+07
#Point: {332.359,-26.6972} distance to center: {58.1612,49.5563} = 1.19454e+07
#Point: {333.49,-26.8737} distance to center: {58.1612,49.5563} = 1.18839e+07
#Point: {333.695,-26.9978} distance to center: {58.1612,49.5563} = 1.18804e+07
#Point: {334.204,-26.96} distance to center: {58.1612,49.5563} = 1.18432e+07
#Point: {339.462,-27.1646} distance to center: {58.1612,49.5563} = 1.15146e+07
#Point: {339.843,-27.4158} distance to center: {58.1612,49.5563} = 1.15112e+07
#Point: {321.592,-26.4738} distance to center: {58.1612,49.5563} = 1.26689e+07
#Point: {322.072,-26.5844} distance to center: {58.1612,49.5563} = 1.2644e+07
#Point: {323.352,-26.8225} distance to center: {58.1612,49.5563} = 1.25734e+07

#ioda/src/distribution/Halo.cc:    oops::Log::debug() << "Point: " << point << " distance to center: " << center_ << " = " << dist << std::endl;
#
# but OOPS_DEBUG is set to 0!  Why are these messages written?
# solution: modify ioda/src/distribution/Halo.cc
#mpiexec ./${myEXE} $myYAML >& jedi.log.all

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

date

exit 0
