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
source config/auto/observations.csh
source config/tools.csh
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

# come to the brunning directory
set runDir = run
cd ${self_WorkDir}/${runDir}

## link MPAS-Atmosphere lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end
## link stream_list.atmosphere.* files
ln -sfv ${self_WorkDir}/stream_list.atmosphere.* ./
## MPASJEDI variable configs
foreach file ($MPASJEDIVariablesFiles)
  ln -sfv $ModelConfigDir/$file . 
end

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
sed -i "s@{{SaveSingleMember}}@false@" solver.yaml
sed -i "s@{{SingleMemberNumber}}@0@" solver.yaml

mpiexec ./${myEXE} solver.yaml ./solver.log >& solver.log.all
rm solver.log.0*

# Update ensemble analyses
# =======================
#set member = 1
#while ( $member <= ${nMembers} )
#  set an = $CyclingDAOutDirs[$member]
#  set anFile = ${an}/${ANFilePrefix}.$thisMPASFileDate.nc
#  mv ${anFile} ${anFile}.new
#  mv ${anFile}.bak ${anFile}
#  $update_analysis_states -i ${anFile}.new -o ${anFile}
#  @ member++
#end

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' solver.log
if ( $status != 0 ) then
  echo "ERROR in $0 : enkf solver failed" > ./FAIL
  exit 1
endif

date

exit 0
