#!/bin/csh -f

# (C) Copyright 2026 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Interpolates a Graphcast forecast to the MPAS mesh. The forecast is from $thisCycleDate to $nextCycleDate

# Set up environment
source config/environmentJEDI.csh  # compilers etc.
source config/tools.csh  # advanceCYMDH
source config/auto/build.csh  # InitBuildDir, InitEXE
source config/auto/experiment.csh  # ModelConfigDir, NamelistFileInit
source config/auto/invariantstream.csh  # InvariantFieldsDirOuter, InvariantFieldsFileOuter
source config/auto/members.csh  # nMembers
source config/auto/model.csh  # GraphInfoDir, localInvariantFieldsFileOuter, meshRatioOuter, model__precision, MPASCore, nCellsOuter, StreamsFileInit
source config/auto/naming.csh  # ForecastWorkDir, ICFilePrefix
source config/auto/workflow.csh  # CyclingWindowHR

# obtain relevant dates date
# set CYLC_TASK_CYCLE_POINT = "20180415T0600Z"  # will be set by cylc eventually
echo "Cylc task cycle point: $CYLC_TASK_CYCLE_POINT"  # debugging
set yyyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-4`
set mm = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 5-6`
set dd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 7-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = "${yyyy}${mm}${dd}${hh}"
set thisCycleDateMpas = "${yyyy}-${mm}-${dd}_${hh}.00.00"
set thisCycleDateWPS = `echo "$thisCycleDate" | sed 's/\(....\)\(..\)\(..\)\(..\)/\1-\2-\3_\4/'`
echo "This cycle date WPS: ${thisCycleDateWPS}"  # debugging
set nextCycleDate = "`$advanceCYMDH ${thisCycleDate} ${CyclingWindowHR}`"
set nextCycleDateWPS = `echo "$nextCycleDate" | sed 's/\(....\)\(..\)\(..\)\(..\)/\1-\2-\3_\4/'`
set nextCycleDateNamelist = "${nextCycleDateWPS}:00:00"
echo "Next cycle date WPS: ${nextCycleDateWPS}"  # debugging

# file names
set fileBaseWPS = "GRAP"

# interpolate each ensemble member
foreach idxMem (`seq 1 $nMembers`)
    echo "Interpolating member $idxMem"  # debugging(?)
    # change to member forecast directory
    if ( "$nMembers" == "1" ) then
        set subDirFc = "${thisCycleDate}"
    else
        set idxMemStr = `printf "%03d" $idxMem`
        # to do: generalize mem
        set subDirFc = "${thisCycleDate}/mem${idxMemStr}"
    endif
    set forecastWorkDirMem = "${ForecastWorkDir}/${subDirFc}"
    echo "Forecast dir: $forecastWorkDirMem"  # debugging
    cd "$forecastWorkDirMem"
    # Rename WPS files. At the moment, when graphcast makes a forecast
    # from $thisCycleDate to $nextCycle date, it writes a file with name
    # GRAP:${thisCycleDate}. init_atmosphere infers the valid time from the
    # file name. To obtain an output from init_atmosphere at the right time,
    # we therefore have to rename the wps file first.
    mv -v "${fileBaseWPS}:${thisCycleDateWPS}" "${fileBaseWPS}:${nextCycleDateWPS}"
    # link MPAS mesh graph info (can't quote this, csh would not expand wildcard)
    ln -sfv ${GraphInfoDir}/x${meshRatioOuter}.${nCellsOuter}.graph.info* .
    # link invariant file if it does not exist yet (typically linked by ForecastGraphcast)
    if ( ! -e "$localInvariantFieldsFileOuter" ) then
        ln -sfv "${InvariantFieldsDirOuter}/${InvariantFieldsFileOuter}" "$localInvariantFieldsFileOuter"
    endif
    # copy and modify namelist
    cp -v "${ModelConfigDir}/graphcast_interp/${NamelistFileInit}" .
    sed -i "s@{{validTime}}@${nextCycleDateNamelist}@" $NamelistFileInit
    sed -i "s@{{GraphcastPrefix}}@${fileBaseWPS}@" $NamelistFileInit
    sed -i "s@{{meshRatio}}@${meshRatioOuter}@" $NamelistFileInit
    sed -i "s@{{nCells}}@${nCellsOuter}@" $NamelistFileInit
    # copy and modify streams list
    cp -v "${ModelConfigDir}/graphcast_interp/${StreamsFileInit}" .
    sed -i "s@{{PRECISION}}@${model__precision}@" $StreamsFileInit
    sed -i "s@{{invariantFile}}@${localInvariantFieldsFileOuter}@" $StreamsFileInit
    sed -i "s@{{meshRatio}}@${meshRatioOuter}@" $StreamsFileInit
    sed -i "s@{{nCells}}@${nCellsOuter}@" $StreamsFileInit
    sed -i "s@{{ICFilePrefix}}@${ICFilePrefix}@" $StreamsFileInit
    # link and execute init atmosphere
    echo "Name of init_atmosphere: ${InitEXE}"  # debugging
    ln -sfv "${InitBuildDir}/${InitEXE}" .
    mpiexec "./${InitEXE}"
    # check status
    grep "Finished running the init_${MPASCore} core" log.init_${MPASCore}.0000.out
    if ( $status != 0 ) then
        # rm $outputFile  # maybe uncomment this?
        echo "ERROR in $0 : MPAS-init failed" > ./FAIL
        exit 1
    endif
    # EnKF: copy soil fields from center
    # Do one forecast step and write file
end


