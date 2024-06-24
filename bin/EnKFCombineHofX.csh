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
# Setup environment
# =================
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
# Activate conda environment
source /etc/profile.d/z00_modules.csh
module purge
module load conda/latest
conda activate npl

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"

cd $self_WorkDir/${OutDBDir}
rm *.h5
foreach instrument ($observers)
  if (-e $CyclingDADir/${InDBDir}/${instrument}_obs_${thisCycleDate}.h5) then
    if (! -e obsout_da_${instrument}.h5) then
       $combine_ensemble_hofx --rundir=$self_WorkDir/${OutDBDir} --obsfile obsout_da_${instrument}.h5 &
    endif
  endif
end
wait

foreach instrument ($observers)
  if (-e $CyclingDADir/${InDBDir}/${instrument}_obs_${thisCycleDate}.h5) then
    if (! -e obsout_da_${instrument}.h5) then
      echo "ERROR in $0 : enkf combinehofx failed" > ./FAIL
      exit 1
    endif
  endif
end

date

exit 0
