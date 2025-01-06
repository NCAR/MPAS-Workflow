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
set ArgObserverMode = "$1"

# None

# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/enkf.csh
source config/auto/workflow.csh
source config/auto/model.csh
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
if ( "$ArgObserverMode" == OMB ) then
  rm -r ${runDir}
  mkdir -p ${runDir}
endif

# direct to the run directory
cd ${runDir}

if ( "$ArgObserverMode" == OMB ) then

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

endif

# asObserver or asDiagOMA
if ( "$ArgObserverMode" == OMA ) then
   set appName = "diagoma"
else
   set appName = "observer"
endif

cp $myYAML ${appName}.yaml
sed -i 's@{{driver}}@asObserver@' ${appName}.yaml
sed -i 's@{{ObsSpaceDistribution}}@RoundRobinDistribution@' ${appName}.yaml
sed -i 's@{{ObsDataIn}}@ObsDataIn@' ${appName}.yaml
sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' ${appName}.yaml
sed -i 's@{{ObsOutSuffix}}@@' ${appName}.yaml
## For OMA, only calculating HofXs of original memebrs and saving to dbAna
if ( "$ArgObserverMode" == OMA ) then
   sed -i 's@dbOut@dbAna@g' ${appName}.yaml
   sed -i 's@*asGETKF@*asLETKF@' ${appName}.yaml
endif

mpiexec ./${myEXE} ${appName}.yaml ./${appName}.log >& ${appName}.log.all

# Check status
# ============
grep 'Run: Finishing oops.* with status = 0' ${appName}.log
if ( $status != 0 ) then
  echo "ERROR in $0 : enkf ${appName} failed" > ./FAIL
  exit 1
else
  rm ${appName}.log.0*
endif

date

exit 0
