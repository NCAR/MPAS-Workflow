#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out LocalEnsembleDA (EnKF) observer stage for ensemble of first guess states

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
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"
cd ${self_WorkDir}

# build, executable, yaml
set myBuildDir = ${EnKFBuildDir}
set myEXE = ${EnKFEXE}
set myYAML = ${self_WorkDir}/${appyaml}

# ================================================================================================

## create then change to run directory
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
  ln -sfv $ModelConfigDir/$file .
end

# Link+Run the executable
# =======================
ln -sfv ${myBuildDir}/${myEXE} ./

# asObserver
cp $myYAML observer.yaml
sed -i 's@{{driver}}@asObserver@' observer.yaml
##sed -i 's@{{ObsSpaceDistribution}}@RoundRobinDistribution@' observer.yaml # IHB: not working for ARO
sed -i 's@{{ObsSpaceDistribution}}@HaloDistribution@' observer.yaml
sed -i 's@{{ObsDataIn}}@ObsDataIn@' observer.yaml
sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' observer.yaml
sed -i 's@{{ObsOutSuffix}}@@' observer.yaml
mpiexec ./${myEXE} observer.yaml ./observer.log >& observer.log.all

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' observer.log
if ( $status != 0 ) then
  echo "ERROR in $0 : enkf observer failed" > ./FAIL
  exit 1
endif

date

exit 0
