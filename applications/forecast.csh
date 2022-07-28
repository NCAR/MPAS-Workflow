#!/bin/csh -f

date

# Process arguments
# =================
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgFcLengthHR: forecast length (hours)
set ArgFcLengthHR = "$2" 	# fcLengthHRTEMPLATE

# ArgFcIntervalHR: forecast output interval (hours)
set ArgFcIntervalHR = "$3" 	# fcIntervalHRTEMPLATE

# ArgFcIAU: whether this forecast has IAU (separate branch) (True/False)
set ArgFcIAU = "$4"

# ArgMesh: str, mesh name, one of model.allMeshes, not currently used
set ArgMesh = "$5"

# ArgDACycling: whether the initial forecast state is a DA analysis (True/False)
set ArgDACycling = "$6"

# ArgDeleteZerothForecast: whether to delete zeroth-hour forecast (True/False)
set ArgDeleteZerothForecast = "$7"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

# Setup environment
# =================
source config/auto/workflow.csh
source config/experiment.csh
source config/auto/externalanalyses.csh
source config/firstbackground.csh
source config/tools.csh
source config/auto/members.csh
source config/auto/model.csh
source config/builds.csh
source config/environmentJEDI.csh
source config/applications/forecast.csh # "$ArgMesh"
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

## ALL forecasts after the first cycle date use this sub-branch (must be outerMesh)
# templated work directory
set self_WorkDir = "$WorkDirsTEMPLATE[$ArgMember]"

# other templated variables
set self_icStateDir = "$StateDirsTEMPLATE[$ArgMember]"

# static variables
set self_icStatePrefix = "StatePrefixTEMPLATE"

if ("$ArgMesh" == "$outerMesh") then
  set nCells = $nCellsOuter
# not used presently
#else if ("$ArgMesh" == "$innerMesh") then
#  set self_WorkDir = ${FirstBackgroundDirInner}
#  set self_icStateDir = $ExternalAnalysisDirInner
#  set self_icStatePrefix = $externalanalyses__filePrefixInner
#  set nCells = $nCellsInner
#else if ("$ArgMesh" == "$ensembleMesh") then
#  set self_WorkDir = ${FirstBackgroundDirEnsemble}
#  set self_icStateDir = $ExternalAnalysisDirEnsemble
#  set self_icStatePrefix = $externalanalyses__filePrefixEnsemble
#  set nCells = $nCellsEnsemble
endif

set icFileExt = ${thisMPASFileDate}.nc
set initialState = ${self_icStateDir}/${self_icStatePrefix}.${icFileExt}

# use previously generated init file for static stream
set StaticMemDir = `${memberDir} 2 $ArgMember "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}

echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# other templated variables
set self_icStateDir = $StateDirsTEMPLATE[$ArgMember]
set config_run_duration = 0_${ArgFcLengthHR}:00:00
set output_interval = 0_${ArgFcIntervalHR}:00:00


# ================================================================================================

## initial forecast file
set icFile = ${ICFilePrefix}.${icFileExt}
rm ./${icFile}
ln -sfv ${initialState} ./${icFile}

## static fields file
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

## link MPAS mesh graph info
rm ./x1.${nCells}.graph.info*
ln -sfv $GraphInfoDir/x1.${nCells}.graph.info* .

## link lookup tables
foreach fileGlob ($MPASLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${MPASLookupDir}/*${fileGlob} .
end

## link stream_list configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
)
  rm ./$staticfile
  ln -sfv $ModelConfigDir/$AppName/$staticfile .
end

## copy/modify dynamic streams file
rm ${StreamsFile}
cp -v $ModelConfigDir/$AppName/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCells}'@' ${StreamsFile}
sed -i 's@{{outputInterval}}@'${output_interval}'@' ${StreamsFile}
sed -i 's@{{StaticFieldsPrefix}}@'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{ICFilePrefix}}@'${ICFilePrefix}'@' ${StreamsFile}
sed -i 's@{{FCFilePrefix}}@'${FCFilePrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

## Update sea-surface variables from GFS/GEFS analyses
set localSeaUpdateFile = x1.${nCells}.sfc_update.nc
sed -i 's@{{surfaceUpdateFile}}@'${localSeaUpdateFile}'@' ${StreamsFile}

if ( "${updateSea}" == "True" ) then
  ## sea/ocean surface files
  # TODO: move sea directory configuration to yamls
  setenv seaMaxMembers 20
  setenv deterministicSeaAnaDir ${ExternalAnalysisDirOuter}
  setenv deterministicSeaMemFmt " "
  setenv deterministicSeaFilePrefix x1.${nCells}.init

  if ( $nMembers > 1 && "$firstbackground__resource" == "PANDAC.LaggedGEFS" ) then
    # using member-specific sst/xice data from GEFS, only works for this special case
    # 60km and 120km
    setenv SeaAnaDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/surface/000hr/${model__precision}/${thisValidDate}
    setenv seaMemFmt "/{:02d}"
    setenv SeaFilePrefix x1.${nCells}.sfc_update
  else
    # otherwise use deterministic analysis for all members
    # 60km and 120km
    setenv SeaAnaDir ${deterministicSeaAnaDir}
    setenv seaMemFmt "${deterministicSeaMemFmt}"
    setenv SeaFilePrefix ${deterministicSeaFilePrefix}
  endif

  # first try member-specific state file (central GFS state when ArgMember==0)
  set seaMemDir = `${memberDir} 2 $ArgMember "${seaMemFmt}" -m ${seaMaxMembers}`
  set SeaFile = ${SeaAnaDir}${seaMemDir}/${SeaFilePrefix}.${icFileExt}
  ln -sfv ${SeaFile} ./${localSeaUpdateFile}
  set brokenLinks=( `find ${localSeaUpdateFile} -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
  set broken=0
  foreach l ($brokenLinks)
    @ broken++
  end

  #if link broken
  if ( $broken > 0 ) then
    echo "$0 (WARNING): file link broken to ${SeaFile}" >> ./WARNING

    # otherwise try deterministic state file
    set SeaFile = ${deterministicSeaAnaDir}/${deterministicSeaFilePrefix}.${icFileExt}
    ln -sfv ${SeaFile} ./${localSeaUpdateFile}
    set brokenLinks=( `find ${localSeaUpdateFile} -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
    set broken=0
    foreach l ($brokenLinks)
      @ broken++
    end

    #if link broken
    if ( $broken > 0 ) then
      echo "$0 (ERROR): file link broken to ${SeaFile}" >> ./FAIL
      exit 1
    endif
  endif

  # determine sea-update precision
  ncdump -h ${localSeaUpdateFile} | grep sst | grep double
  if ($status == 0) then
    set surfacePrecision=double
  else
    ncdump -h ${localSeaUpdateFile} | grep sst | grep float
    if ($status == 0) then
      set surfacePrecision=single
    else
      echo "$0 (ERROR): cannot determine surface input precision (${localSeaUpdateFile})" > ./FAIL
      exit 1
    endif
  endif
  sed -i 's@{{surfacePrecision}}@'${surfacePrecision}'@' ${StreamsFile}
  sed -i 's@{{surfaceInputInterval}}@initial_only@' ${StreamsFile}
else
  sed -i 's@{{surfacePrecision}}@'${model__precision}'@' ${StreamsFile}
  sed -i 's@{{surfaceInputInterval}}@none@' ${StreamsFile}
endif

## copy/modify dynamic namelist
rm ${NamelistFile}
cp -v $ModelConfigDir/$AppName/$NamelistFile .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFile
sed -i 's@fcLength@'${config_run_duration}'@' $NamelistFile
sed -i 's@nCells@'${nCells}'@' $NamelistFile
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile
set configDODACycling = `echo "$ArgDACycling" | sed 's/\(.*\)/\L\1/'` # converts to lower-case
sed -i 's@configDODACycling@'${configDODACycling}'@' $NamelistFile

if ( ${ArgFcLengthHR} == 0 ) then
  ## zero-length forecast case (NOT CURRENTLY USED)
  rm ./${icFile}_tmp
  mv ./${icFile} ./${icFile}_tmp
  rm ${FCFilePrefix}.${icFileExt}
  cp ${icFile}_tmp ${FCFilePrefix}.${icFileExt}
  rm ./${DIAGFilePrefix}.${icFileExt}
  ln -sfv ${self_icStateDir}/${DIAGFilePrefix}.${icFileExt} ./
else
  ## remove previously generated forecasts
  set fcDate = `$advanceCYMDH ${thisValidDate} ${ArgFcIntervalHR}`
  set finalFCDate = `$advanceCYMDH ${thisValidDate} ${ArgFcLengthHR}`
  while ( ${fcDate} <= ${finalFCDate} )
    set yy = `echo ${fcDate} | cut -c 1-4`
    set mm = `echo ${fcDate} | cut -c 5-6`
    set dd = `echo ${fcDate} | cut -c 7-8`
    set hh = `echo ${fcDate} | cut -c 9-10`
    set fcFileDate  = ${yy}-${mm}-${dd}_${hh}.00.00
    set fcFileExt = ${fcFileDate}.nc
    set fcFile = ${FCFilePrefix}.${fcFileExt}

    rm ${fcFile}

    set fcDate = `$advanceCYMDH ${fcDate} ${ArgFcIntervalHR}`
    setenv fcDate ${fcDate}
  end

  # Run the executable
  # ==================
  rm ./${ForecastEXE}
  ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
  # mpiexec is for Open MPI, mpiexec_mpt is for MPT
  mpiexec ./${ForecastEXE}
  #mpiexec_mpt ./${ForecastEXE}


  # Check status
  # ============
  grep "Finished running the ${MPASCore} core" log.${MPASCore}.0000.out
  if ( $status != 0 ) then
    echo "ERROR in $0 : MPAS-Model forecast failed" > ./FAIL
    exit 1
  endif

  ## change static fields to a link, keeping for transparency
  rm ${localStaticFieldsFile}
  mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}
endif

if ( "$ArgDeleteZerothForecast" == "True" ) then
  # Optionally remove initial forecast file
  # =======================================
  set fcDate = ${thisValidDate}
  set yy = `echo ${fcDate} | cut -c 1-4`
  set mm = `echo ${fcDate} | cut -c 5-6`
  set dd = `echo ${fcDate} | cut -c 7-8`
  set hh = `echo ${fcDate} | cut -c 9-10`
  set fcFileDate  = ${yy}-${mm}-${dd}_${hh}.00.00
  set fcFileExt = ${fcFileDate}.nc
  set fcFile = ${FCFilePrefix}.${fcFileExt}
  rm ${fcFile}
  set diagFile = ${DIAGFilePrefix}.${fcFileExt}
  rm ${diagFile}
endif

date

exit 0
