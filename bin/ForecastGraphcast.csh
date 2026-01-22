#!/bin/csh -f

# (C) Copyright 2026 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Runs a forecast or ensemble of forecasts using Graphcast

date

# set up environment
source /etc/profile.d/z00_modules.csh
source config/auto/experiment.csh  # mainScriptDir
source config/auto/invariantstream.csh  # InvariantFieldsDirOuter, InvariantFieldsFileOuter
source config/auto/members.csh  # nMembers
source config/auto/model.csh  # localInvariantFieldsFileOuter
source config/auto/naming.csh  # analysisSubDir, ANFilePrefix, DAWorkDir, ForecastWorkDir, ICFilePrefix

# obtain cycle date
# set CYLC_TASK_CYCLE_POINT = "20180415T0600Z"  # will be set by cylc eventually
# echo "Cylc task cycle point: $CYLC_TASK_CYCLE_POINT"  # debugging
set yyyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set mm = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 5-6`
set dd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 7-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set cycleDate = "${yyyy}${mm}${dd}${hh}"
set cycleDateMpas = "${yyyy}-${mm}-${dd}_${hh}.00.00"

# basic file names
set analysisFile = "${ANFilePrefix}.${cycleDateMpas}.nc"
# echo "Analysis file: ${analysisFile}"
set invariantFileWithPath = "${InvariantFieldsDirOuter}/${InvariantFieldsFileOuter}"
# echo "Invariant file: ${invariantFileWithPath}"
set initialConditionFile = "${ICFilePrefix}.${cycleDateMpas}.nc"
# echo "InitialConditionFile = ${initialConditionFile}"

# set up directory structure and link input files for each forecast
foreach idxMem (`seq 1 $nMembers`)
    if ( "$nMembers" == "1" ) then
        set subDirFc = "${cycleDate}"
        set subDirAn = "${cycleDate}/${analysisSubDir}"
    else
        set idxMemStr = `printf "%03d" $idxMem`
        # to do: generalize mem
        set subDirFc = "${cycleDate}/mem${idxMemStr}"
        set subDirAn = "${cycleDate}/${analysisSubDir}/mem${idxMemStr}"
    endif
    set forecastWorkDirMem = "${ForecastWorkDir}/${subDirFc}"
    # echo "Forecast dir: $forecastWorkDirMem"
    mkdir -p $forecastWorkDirMem
    cd "$forecastWorkDirMem"
    # link invariant file
    ln -sfv "$invariantFileWithPath" "$localInvariantFieldsFileOuter"
    # link initial condition
    set analysisWorkDirMem = "${DAWorkDir}/${subDirAn}"
    # echo "Analysis dir: $analysisWorkDirMem"
    set analysisFileWithPath = "${analysisWorkDirMem}/${analysisFile}"
    # echo "Analysis file with path: $analysisFileWithPath"
    ln -sfv "$analysisFileWithPath" "$initialConditionFile"
end

# run Graphcast from cycle forecast directory
cd "${ForecastWorkDir}/${cycleDate}"
set executable = "runGraphcast.py"
set executableWithPath = "${mainScriptDir}/tools/${executable}"
# echo "Executable: $executableWithPath"
ln -sfv "$executableWithPath" "$executable"
# load graphcast environment
source "${mainScriptDir}/config/environmentGraphcast.csh"
module list
# generate forecast for all members
uv run --project "$uvProject" "$executable" \
    -cycle "$cycleDate" \
    -fcdir "$ForecastWorkDir" \
    -nmem "$nMembers" \
    -inv "$localInvariantFieldsFileOuter"

if ( $status != 0 ) then
    echo "Graphcast forecast failed (exit code $status)"
    exit 1
endif

date

exit 0
