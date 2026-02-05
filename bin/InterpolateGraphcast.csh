#!/bin/csh -f

# (C) Copyright 2026 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Interpolates a Graphcast forecast to the MPAS mesh. The forecast is from $thisCycleDate to $nextCycleDate

date

# Set up environment
# source config/environmentJEDI.csh  # compilers etc.
source config/tools.csh  # advanceCYMDH
source config/auto/build.csh  # ForecastBuildDir, ForecastEXE, InitBuildDir, InitEXE, MPASLookupFileGlobs
source config/auto/experiment.csh  # ModelConfigDir, NamelistFileInit
source config/auto/invariantstream.csh  # InvariantFieldsDirOuter, InvariantFieldsFileOuter
source config/auto/members.csh  # nMembers
source config/auto/model.csh  # ConvectionOuter, DiffusionLengthScaleOuter, GraphInfoDir, GwdoOuter,
                                # localInvariantFieldsFileOuter, localInvariantFieldsPrefix, LSMOuter,
                              # meshRatioOuter, MicrophysicsOuter,
                              # model__precision, MPASCore, MPThompsonTablesDir, NamelistFile,
                              # nCellsOuter, PBLOuter, PhysicsSuiteOuter, RadiationCloudOuter,
                              # RadiationLWIntervalOuter, RadiationLWOuter, RadiationSWIntervalOuter, RadiationSWOuter,
                              # SfcLayerOuter, StreamsFile, StreamsFileInit
source config/auto/naming.csh  # ForecastWorkDir, FCFilePrefix, ICFilePrefix
source config/auto/workflow.csh  # CyclingWindowHR

# To Dos:
# -------
# (search for todo in comments)
# - add deltaT as workflow setting
# - add fileBase WPS as workflow setting
# - handle case where forecastWorkDirMem does not exist
# - copy soil fields from center to EnKF members
# - properly handle sea-surface update if needed
# - check proper setting for config_do_DAcycling
# - check if config_jedi_da = true is appropriate

# todo: add deltaT as workflow setting
set deltaT = "00:01:00"  # has to be in format HH:MM:SS; time step, file output interval and forecast length

# obtain relevant dates date
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
set fileBaseWPS = "GRAP"  # todo: add fileBaseWPS as workflow setting

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
    # todo: handle case where forecastWorkDirMem does not exist
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
    source "${mainScriptDir}/config/environmentJEDI.csh"  # environment for init_atmosphere
    echo "Name of init_atmosphere: ${InitEXE}"  # debugging
    ln -sfv "${InitBuildDir}/${InitEXE}" .
    mpiexec "./${InitEXE}"
    # check status
    grep "Finished running the init_${MPASCore} core" "log.init_${MPASCore}.0000.out"
    if ( $status != 0 ) then
        # rm $outputFile  # maybe uncomment this?
        echo "ERROR in $0 : MPAS-init failed" > ./FAIL
        exit 1
    endif
    
    # todo: copy soil fields from center to EnKF members
    
    # Do one forecast step and write file
    # Link lookup tables
    foreach fileGlob ($MPASLookupFileGlobs)
        ln -sfv ${MPASLookupDir}/*${fileGlob} .
    end

    if ( "$MicrophysicsOuter" == "mp_thompson" ) then
        ln -svf $MPThompsonTablesDir/* .
    endif

    # Streams files for atmosphere core
    # Link static stream_list configurations
    foreach staticfile ( \
        "stream_list.${MPASCore}.surface" \
        "stream_list.${MPASCore}.diagnostics" \
    )
        ln -sfv "${ModelConfigDir}/forecast/${staticfile}" .
    end
    # Copy and modify dynamic streams file
    cp -v "${ModelConfigDir}/forecast/${StreamsFile}" .
    sed -i "s@{{PRECISION}}@${model__precision}@" $StreamsFile
    sed -i "s@{{InvariantFieldsPrefix}}@${localInvariantFieldsPrefix}@" $StreamsFile
    sed -i "s@{{nCells}}@${nCellsOuter}@" $StreamsFile
    sed -i "s@{{ICFilePrefix}}@${ICFilePrefix}@" $StreamsFile
    sed -i "s@{{FCFilePrefix}}@${FCFilePrefix}@" $StreamsFile
    sed -i "s@{{outputInterval}}@${deltaT}@" $StreamsFile
    sed -i "s@{{surfaceUpdateFile}}@x${meshRatioOuter}.${nCellsOuter}.sfc_update.nc@" $StreamsFile
    # todo: properly handle sea-surface update if needed
    sed -i "s@{{surfacePrecision}}@${model__precision}@" $StreamsFile
    sed -i "s@{{surfaceInputInterval}}@none@" $StreamsFile

    # Copy and modify namelist file
    cp -v "${ModelConfigDir}/forecast/${NamelistFile}" .
    # settings
    set deltaTInSec = `echo "$deltaT" | awk -F: '{ print $1*3600 + $2*60 + $3 }'`
    set doDACycling = "false"  # todo: check proper setting for config_do_DAcycling
    # dynamics
    sed -i "s@modelDT@${deltaTInSec}@" $NamelistFile  # this has to be in sec
    sed -i "s@startTime@${nextCycleDateNamelist}@" $NamelistFile
    sed -i "s@fcLength@${deltaT}@" $NamelistFile
    sed -i "s@diffusionLengthScale@${DiffusionLengthScaleOuter}@" $NamelistFile
    # decomposition
    sed -i "s@{{meshRatio}}@${meshRatioOuter}@" $NamelistFile
    sed -i "s@nCells@${nCellsOuter}@" $NamelistFile
    # restart
    sed -i "s@configDODACycling@${doDACycling}@" $NamelistFile
    # iau
    sed -i "s@{{IAU}}@off@" $NamelistFile
    # physics
    sed -i "s@radtlwInterval@${RadiationLWIntervalOuter}@" $NamelistFile
    sed -i "s@radtswInterval@${RadiationSWIntervalOuter}@" $NamelistFile
    sed -i "s@physicsSuite@${PhysicsSuiteOuter}@" $NamelistFile
    sed -i "s@micropScheme@${MicrophysicsOuter}@" $NamelistFile
    sed -i "s@convectionScheme@${ConvectionOuter}@" $NamelistFile
    sed -i "s@pblScheme@${PBLOuter}@" $NamelistFile
    sed -i "s@gwdoScheme@${GwdoOuter}@" $NamelistFile
    sed -i "s@radtCldScheme@${RadiationCloudOuter}@" $NamelistFile
    sed -i "s@radtLWScheme@${RadiationLWOuter}@" $NamelistFile
    sed -i "s@radtSWScheme@${RadiationSWOuter}@" $NamelistFile
    sed -i "s@sfcLayerScheme@${SfcLayerOuter}@" $NamelistFile
    sed -i "s@lsmScheme@${LSMOuter}@" $NamelistFile

    # link and execute MPAS
    source "${mainScriptDir}/config/environmentForecast.csh"
    ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
    mpiexec "./${ForecastEXE}"
    # check status
    grep "Finished running the ${MPASCore} core" "log.${MPASCore}.0000.out"
    if ( $status != 0 ) then
        echo "ERROR in $0 : MPAS-Model forecast failed" > ./FAIL
        exit 1
    endif

end

date

exit 0
