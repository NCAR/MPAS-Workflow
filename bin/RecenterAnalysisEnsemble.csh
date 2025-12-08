#!/bin/csh -f

# (C) Copyright 2025 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Recenters an analysis ensemble on a given center state.
# Currently only works for an EnKF analysis ensemble

source config/environmentJEDI.csh  # sets up the environment etc.
source config/auto/build.csh  # RecenterBuildDir, RecenterExe
source config/auto/enkf.csh  # ensPbMemNDigits, ensPbNMembers, ensPbMemPrefix, workDirVarDA
source config/auto/experiment.csh  # ConfigDir
source config/auto/model.csh  # outerNamelistFile, outerStreamsFile
source config/auto/naming.csh  # analysisSubDir, ANFilePrefix, DAWorkDir

# Obtain date information
# set CYLC_TASK_CYCLE_POINT = "20180415T0600Z"  # will be set by cylc eventually
echo "Cylc task cycle point: $CYLC_TASK_CYCLE_POINT"  # debugging
set yyyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set mm = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 5-6`
set dd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 7-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set cycleDate = "${yyyy}${mm}${dd}${hh}"
set cycleDateISO8601 = "${yyyy}-${mm}-${dd}T${hh}:00:00Z"
set cycleDateMpas = "${yyyy}-${mm}-${dd}_${hh}.00.00"
echo "Current cycle date: $cycleDate"  # debugging

# Change to work directory and copy configuration yaml file
set cyclingDADirEnKF = "${DAWorkDir}/${cycleDate}"
set yamlFileRecenter = "recenter.yaml"
cd "${cyclingDADirEnKF}/run"
echo "Working in directory: `pwd`"  # debugging
cp -v "${ConfigDir}/jedi/applications/${yamlFileRecenter}" "$yamlFileRecenter"
if ( $status != 0 ) then
  echo "ERROR: recenter yaml not available --> $yamlFileRecenter" > ./FAIL
  exit 1
endif

# Populate placeholders in yaml file
# 1) date information
sed -i "s@{{cycleDateISO8601}}@$cycleDateISO8601@" $yamlFileRecenter

# 2) center geometry information
# todo: update so that varDA can have different resolution
set cyclingDADirVar = "${workDirVarDA}/CyclingDA/${cycleDate}"
set namelistFileCenter = "${cyclingDADirVar}/${outerNamelistFile}"
set streamsFileCenter = "${cyclingDADirVar}/${outerStreamsFile}"
sed -i "s@{{namelistFileCenter}}@$namelistFileCenter@" $yamlFileRecenter
sed -i "s@{{streamsFileCenter}}@$streamsFileCenter@" $yamlFileRecenter

# 3) center analysis information.
# The current assumption is that analysisSubDir and ANFilePrefix in the
# EnKF and var DA run are identical. This is not necessarily true but reasonable
# set mpasFileSuffix = '$Y-$M-$D_$h.$m.$s.nc'
set mpasFileSuffix = "${cycleDateMpas}.nc"
set analysisFileCenter = "${cyclingDADirVar}/${analysisSubDir}/${ANFilePrefix}.${mpasFileSuffix}"
sed -i "s@{{analysisFileCenter}}@$analysisFileCenter@" $yamlFileRecenter

# 4) EnKF ensemble geometry information
# set cyclingDADirEnKF = "${DAWorkDir}/${cycleDate}"
set namelistFileEnsemble = "${cyclingDADirEnKF}/${outerNamelistFile}"
set streamsFileEnsemble = "${cyclingDADirEnKF}/${outerStreamsFile}"
sed -i "s@{{namelistFileEnsemble}}@$namelistFileEnsemble@" $yamlFileRecenter
sed -i "s@{{streamsFileEnsemble}}@$streamsFileEnsemble@" $yamlFileRecenter

# 5) EnKF analysis ensemble information
# Add an _orig suffix to label the original analysis ensemble member
set analysisFileEnsembleBase = "${ANFilePrefix}_orig.${mpasFileSuffix}"
# set analysisFileEnsemble = "${cyclingDADirEnKF}/${analysisSubDir}/${ensPbMemPrefix}%iMember%/${ANFilePrefix}_orig.${mpasFileSuffix}"
set analysisFileEnsemble = "${cyclingDADirEnKF}/${analysisSubDir}/${ensPbMemPrefix}%iMember%/${analysisFileEnsembleBase}"
sed -i "s@{{analysisFileEnsemble}}@$analysisFileEnsemble@" $yamlFileRecenter
sed -i "s@{{paddingEnsembleMembers}}@$ensPbMemNDigits@" $yamlFileRecenter
sed -i "s@{{numberEnsembleMembers}}@$ensPbNMembers@" $yamlFileRecenter

# 6) Recentered output
# The recentered analysis files obtain the standard analysis file name, so that a subsequent
# forecast can be started from them 
set analysisFileRecenterBase = "${ANFilePrefix}.${mpasFileSuffix}"
# set analysisFileRecenter = "${cyclingDADirEnKF}/${analysisSubDir}/${ensPbMemPrefix}%iMember%/${ANFilePrefix}.${mpasFileSuffix}"
set analysisFileRecenter = "${cyclingDADirEnKF}/${analysisSubDir}/${ensPbMemPrefix}%{member}%/${analysisFileRecenterBase}"
sed -i "s@{{analysisFileRecenter}}@$analysisFileRecenter@" $yamlFileRecenter

# Copy original analysis files (recall that the recentered files have the original name)
@ i = 1
while ( $i <= $ensPbNMembers )
    set memberDirBase = `printf "${ensPbMemPrefix}%0${ensPbMemNDigits}d" $i`
    set memberDir = "${cyclingDADirEnKF}/${analysisSubDir}/${memberDirBase}"
    cp -v "${memberDir}/${analysisFileRecenterBase}" "${memberDir}/${analysisFileEnsembleBase}"
    @ i++
end

# Link and run the recentering executable. This overwrites the analysis files
set jediOutputFile = "recenter.log"
ln -sfv "${RecenterBuildDir}/${RecenterEXE}" ./
mpiexec "./${RecenterEXE}" "$yamlFileRecenter" "./${jediOutputFile}" >& recenter.log.all

# Make sure the application terminated successfully
grep 'Run: Finishing oops.* with status = 0' "$jediOutputFile"
if ( $status != 0 ) then
  echo "ERROR: recenter application failed" > ./FAIL
  exit 1
# to do: is a further cleanup along these lines necessary?
# else
#   rm ${appName}.log.0*
endif
