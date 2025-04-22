#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out LocalEnsembleDA (EnKF) for ensemble of first guess states

date

# Process arguments
# =================
## args
set ArgEnKFMode = "$1"

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
source config/auto/naming.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# EnKF: asObserver or asDiagOMA or Solver
if ( "$ArgEnKFMode" == "OMB" ) then
   set appName = "observerOMB"
else if ( "$ArgEnKFMode" == "OMA" ) then
   set appName = "observerOMA"
else if ( "$ArgEnKFMode" == "Solver" ) then
   set appName = "solver"
else
   echo "ERROR in ${ArgEnKFMode} in EnKF Mode" > ./FAIL
   exit 1
endif

# For Solver step, set openmpi
if ( "$ArgEnKFMode" == "Solver" ) then
   setenv OMP_NUM_THREADS ${solverThreads}
endif

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
if ( "$ArgEnKFMode" == OMB ) then
  rm -r ${runDir}
  mkdir -p ${runDir}
endif

# direct to the run directory
cd ${runDir}

if ( "$ArgEnKFMode" == "OMB" ) then

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

# YAML setting
cp $myYAML ${appName}.yaml

if ( "$ArgEnKFMode" == "Solver" ) then
   sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/'${backgroundSubDir}'@' ${appName}.yaml
   sed -i 's@{{ensembleStatePrefix}}@'${BGFilePrefix}'@' ${appName}.yaml
   sed -i 's@{{driver}}@asSolver@' ${appName}.yaml
   sed -i 's@{{ObsDataIn}}@ObsDataOut@' ${appName}.yaml
   sed -i 's@\ \+{{ObsDataOut}}@@' ${appName}.yaml
   sed -i 's@{{ObsOutSuffix}}@@' ${appName}.yaml
   sed -i 's@{{ObsSpaceDistribution}}@HaloDistribution@' ${appName}.yaml
else
   sed -i 's@{{driver}}@asObserver@' ${appName}.yaml
   sed -i 's@{{ObsSpaceDistribution}}@RoundRobinDistribution@' ${appName}.yaml
   sed -i 's@{{ObsDataIn}}@ObsDataIn@' ${appName}.yaml
   sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' ${appName}.yaml
   if ( "$ArgEnKFMode" == "OMA" ) then
      sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/'${analysisSubDir}'@' ${appName}.yaml
      sed -i 's@{{ensembleStatePrefix}}@'${ANFilePrefix}'@' ${appName}.yaml
      sed -i 's@{{ObsOutSuffix}}@_ana@' ${appName}.yaml
      sed -i 's@*asGETKF@*asLETKF@' ${appName}.yaml
   else
      sed -i 's@{{ensembleStateDir}}@'${CyclingDADir}'/'${backgroundSubDir}'@' ${appName}.yaml
      sed -i 's@{{ensembleStatePrefix}}@'${BGFilePrefix}'@' ${appName}.yaml
     sed -i 's@{{ObsOutSuffix}}@@' ${appName}.yaml
   endif
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

# Remove obs-database output files
# ================================
if ("$retainObsFeedback" != "True" && "$ArgEnKFMode" == "Solver" ) then
  echo " ls ${self_WorkDir}/${OutDBDir}/"
  ls ${self_WorkDir}/${OutDBDir}/
  echo "rm ${self_WorkDir}/${OutDBDir}/${obsPrefix}*.h5"
  rm ${self_WorkDir}/${OutDBDir}/${obsPrefix}*.h5
  echo "rm ${self_WorkDir}/${OutDBDir}/${geoPrefix}*.nc4"
  rm ${self_WorkDir}/${OutDBDir}/${geoPrefix}*.nc4
  echo "rm ${self_WorkDir}/${OutDBDir}/${diagPrefix}*.nc4"
  rm ${self_WorkDir}/${OutDBDir}/${diagPrefix}*.nc4
endif

date

exit 0
