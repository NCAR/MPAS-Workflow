#!/bin/csh -f

# (C) Copyright 2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Recenters an analysis ensemble on a given center state

source config/auto/build.csh  # RecenterBuildDir, RecenterExe
source config/auto/enkf.csh  # ensPbMemNDigits, ensPbNMembers, ensPbMemPrefix, workDirVarDA
source config/auto/model.csh  # outerNamelistFile, outerStreamsFile
source config/auto/naming.csh  # analysisSubDir, ANFilePrefix, DAWorkDir

# Copy configuration file
# todo: change to run directory of cycling run
set yamlFileRecenter = "ens_recenter_test.yaml"
if ( -f "$yamlFileRecenter" ) then
  rm "$yamlFileRecenter"
endif
cp "ens_recenter_template.yaml" "$yamlFileRecenter"

# Date information
set CYLC_TASK_CYCLE_POINT = "20180415T0600Z"  # will be set by cylc eventually
set yyyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set mm = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 5-6`
set dd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 7-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set cycleDate = "${yyyy}${mm}${dd}${hh}"
set cycleDateISO8601 = "${yyyy}-${mm}-${dd}T${hh}:00:00Z"
sed -i "s@{{cycleDateISO8601}}@$cycleDateISO8601@" $yamlFileRecenter

# Center geometry information
# todo: update so that varDA can have different resolution
set cyclingDADirVar = "${workDirVarDA}/CyclingDA/${cycleDate}"
set namelistFileCenter = "${cyclingDADirVar}/${outerNamelistFile}"
set streamsFileCenter = "${cyclingDADirVar}/${outerStreamsFile}"
sed -i "s@{{namelistFileCenter}}@$namelistFileCenter@" $yamlFileRecenter
sed -i "s@{{streamsFileCenter}}@$streamsFileCenter@" $yamlFileRecenter

# Center analysis information. This assumes that analysisSubDir and ANFilePrefix in
# the EnKF and var DA run are identical. This is not necessarily true but reasonable
set mpasFileSuffix = '$Y-$M-$D_$h.$m.$s.nc'
set analysisFileCenter = "${cyclingDADirVar}/${analysisSubDir}/${ANFilePrefix}.${mpasFileSuffix}"
sed -i "s@{{analysisFileCenter}}@$analysisFileCenter@" $yamlFileRecenter

# EnKF ensemble geometry information
set cyclingDADirEnKF = "${DAWorkDir}/${cycleDate}"
set namelistFileEnsemble = "${cyclingDADirEnKF}/${outerNamelistFile}"
set streamsFileEnsemble = "${cyclingDADirEnKF}/${outerStreamsFile}"
sed -i "s@{{namelistFileEnsemble}}@$namelistFileEnsemble@" $yamlFileRecenter
sed -i "s@{{streamsFileEnsemble}}@$streamsFileEnsemble@" $yamlFileRecenter

# EnKF analysis ensemble information
# todo: rename original analysis files and update this section
set analysisFileEnsemble = "${cyclingDADirEnKF}/${analysisSubDir}/${ensPbMemPrefix}%iMember%/${ANFilePrefix}.${mpasFileSuffix}"
sed -i "s@{{analysisFileEnsemble}}@$analysisFileEnsemble@" $yamlFileRecenter
sed -i "s@{{paddingEnsembleMembers}}@$ensPbMemNDigits@" $yamlFileRecenter
sed -i "s@{{numberEnsembleMembers}}@$ensPbNMembers@" $yamlFileRecenter

# Recentered output
set analysisFileRecenter = "${cyclingDADirEnKF}/${analysisSubDir}/${ensPbMemPrefix}%iMember%/${ANFilePrefix}.${mpasFileSuffix}"
sed -i "s@{{analysisFileRecenter}}@$analysisFileRecenter@" $yamlFileRecenter

# Link and run executable
ln -sfv "${RecenterBuildDir}/${RecenterEXE}" ./
#mpiexec ./${RecenterEXE}


