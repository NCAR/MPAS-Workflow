#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Carry out LocalEnsembleDA (EnKF) observer stage for ensemble of first guess states

date

# =================
# Setup environment
# =================
source config/environmentJEDI.csh
source config/mpas/variables.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/enkf.csh
source config/auto/workflow.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./bin/getCycleVars.csh

# static work directory
set self_WorkDir = $CyclingDADir
echo "WorkDir = ${self_WorkDir}"

# build, executable, yaml
set myBuildDir = ${EnKFBuildDir}
set myEXE = ${EnKFEXE}
set myYAML = ${self_WorkDir}/${appyaml}

# NonergMember: logical, whether to save only single ensemble meber in observer
echo "Number of Input: $#argv"
if ( $#argv == 0 ) then
   set ArgSaveSingleMember = false
   set ArgStartMember = 0
   set ArgNumSingle = ${nMembers}
else
   set ArgSaveSingleMember = "$1"
   set ArgStartMember = "$2"
   set ArgNumSingle = "$3"
endif

# ================================================================================================
## create then change to run directory
set imem = 1
set run_mem = $ArgStartMember

while ( $imem <= $ArgNumSingle && $run_mem <= `expr ${nMembers} + 1` ) 

  cd ${self_WorkDir}

  if ( $ArgSaveSingleMember == "True" ) then
    set memDir = `${memberDir} 2 ${run_mem} "${flowMemFmt}"`
    if ( $run_mem > ${nMembers} ) then
      set memDir = `${memberDir} 2 0 "${flowMemFmt}"` ### For mean 
    endif
    set runDir = run${memDir}
    rm -r ${runDir}
    mkdir -p ${runDir}
    mkdir -p dbOut${memDir}
  else
    set runDir = run
    rm -r ${runDir}
    mkdir -p ${runDir}
  endif

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
  sed -i 's@{{ObsSpaceDistribution}}@RoundRobinDistribution@' observer.yaml
  sed -i 's@{{ObsDataIn}}@ObsDataIn@' observer.yaml
  sed -i 's@{{ObsDataOut}}@obsdataout: *ObsDataOut@' observer.yaml
  sed -i 's@{{ObsOutSuffix}}@@' observer.yaml
  sed -i "s@{{SaveSingleMember}}@${ArgSaveSingleMember}@" observer.yaml
  if ( $run_mem > ${nMembers} ) then
    sed -i "s@{{SingleMemberNumber}}@0@" observer.yaml
  else
    sed -i "s@{{SingleMemberNumber}}@${run_mem}@" observer.yaml
  endif
  if ( $ArgSaveSingleMember == "True" )then
    sed -i "s@dbOut@dbOut${memDir}@" observer.yaml
  endif

  if ( $thinningHofx == "True" && $ArgSaveSingleMember == "True" && $run_mem != 0 ) then
     mv observer.yaml observer.yaml.bak
     sed '/Gaussian_Thinning/{N;d;}' observer.yaml.bak > observer.yaml
  endif

  if ( $thinningHofx == "True" && $ArgSaveSingleMember == "True" && $run_mem == 0 ) then
     sed -i 's@*asGETKF@*asLETKF@' observer.yaml  
  endif

  mpiexec ./${myEXE} observer.yaml ./observer.log >& observer.log.all

  # Check status
  # ============
  grep 'Run: Finishing oops.* with status = 0' observer.log
  if ( $status != 0 ) then
    echo "ERROR in $0 : enkf observer failed" > ./FAIL
    exit 1
  else
    rm observer.log.0*
  endif

  if ( $run_mem == 0 && $ArgSaveSingleMember == "True" && $thinningHofx == "True" ) then
    source /etc/profile.d/z00_modules.csh
    module purge
    module load conda/latest
    conda activate npl

    # Thinning observations
    cd $self_WorkDir/${OutDBDir}/mem000
    foreach instrument ($observers)
      if ( -e obsout_da_${instrument}.h5 ) then
         mv obsout_da_${instrument}.h5 obsout_da_${instrument}.h5_old
         $thinning_hofx --thinning 1 --rundir $self_WorkDir/${OutDBDir}/mem000 --hofxfile obsout_da_${instrument}.h5_old --outfile ${instrument}_obs_${thisValidDate}.h5 &
      endif
    end
    wait
    # rename mem000 as mean for saving
    if ( -e $self_WorkDir/${OutDBDir}/mean ) then
       rm -rf $self_WorkDir/${OutDBDir}/mean
    endif
    cd $self_WorkDir/${OutDBDir} && mv mem000 mean
    if ( -e $self_WorkDir/run/mean ) then
       rm -rf $self_WorkDir/run/mean
    endif
    cd $self_WorkDir/run && mv mem000 mean

    # Re-link new-generated IODA files for Observer
    cd $self_WorkDir/${InDBDir}
    foreach instrument ($observers)
      if ( -e ${instrument}_obs_${thisValidDate}.h5 ) then
         mv ${instrument}_obs_${thisValidDate}.h5 ${instrument}_obs_${thisValidDate}.h5_old
         mv $self_WorkDir/${OutDBDir}/mean/${instrument}_obs_${thisValidDate}.h5 ${instrument}_obs_${thisValidDate}.h5
      endif
    end
    break
  endif

  set run_mem = `expr $imem + $ArgStartMember`
  @ imem++

  if ( $ArgSaveSingleMember == "false" ) then
    break
  endif

end

date

exit 0
