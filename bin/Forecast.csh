#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgFCLengthHR: int, total forecast duration (hr)
set ArgFCLengthHR = "$2"

# ArgFCIntervalHR: int, forecast output interval (hr)
set ArgFCIntervalHR = "$3"

# ArgIAU: bool, whether to engage IAU (True/False)
set ArgIAU = "$4"

# ArgMesh: str, mesh name, one of model.meshes, not currently used
set ArgMesh = "$5"

# ArgDACycling: whether the initial forecast state is a DA analysis (True/False)
set ArgDACycling = "$6"

# ArgDeleteZerothForecast: whether to delete zeroth-hour forecast (True/False)
set ArgDeleteZerothForecast = "$7"

# ArgUpdateSea: whether to update the sea surface fields with values from an external analysis (True/False)
set ArgUpdateSea = "$8"

# ArgWorkDir: where the forecast will be executed
set ArgWorkDir = "$9"

# ArgICStateDir: where the initial condition state is located
set ArgICStateDir = "$10"

# ArgICStatePrefix: prefix of the initial condition state
set ArgICStatePrefix = "$11"

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
source config/tools.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/members.csh
source config/auto/model.csh
source config/auto/staticstream.csh
source config/auto/workflow.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}

# substitute thisCycleDate/thisValidDate in ArgWorkDir and ArgICStateDir as needed
set self_WorkDir = ${ExperimentDirectory}/`echo "${ArgWorkDir}" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `

set self_icStateDir = ${ExperimentDirectory}/`echo "${ArgICStateDir}" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `

source ./bin/getCycleVars.csh

# nCells
if ("$ArgMesh" == "$outerMesh") then
  set nCells = $nCellsOuter
# not used presently
#else if ("$ArgMesh" == "$innerMesh") then
#  set nCells = $nCellsInner
#else if ("$ArgMesh" == "$ensembleMesh") then
#  set nCells = $nCellsEnsemble
endif

# initialState
set icFileExt = ${thisMPASFileDate}.nc
set initialState = ${self_icStateDir}/${ArgICStatePrefix}.${icFileExt}

# use previously generated init file for static stream
set StaticMemDir = `${memberDir} 2 $ArgMember "${staticMemFmt}"`
set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}

echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# Input parameters can further change for the first DA cycle inside this script.
set self_FCIntervalHR = ${ArgFCIntervalHR}
set self_FCLengthHR   = ${ArgFCLengthHR}
set StartDate = ${thisMPASNamelistDate}


# ================================================================================================

## initial forecast file
set icFile = ${ICFilePrefix}.${icFileExt}
if( -e ${icFile} ) rm ./${icFile}
ln -sfv ${initialState} ./${icFile}

## static fields file
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

# We can start IAU only from the second DA cycle (otherwise, 3hrly background forecast is not available yet.)
set self_IAU = False
set firstIAUDate = `$advanceCYMDH ${FirstCycleDate} ${self_FCIntervalHR}`
if ($thisValidDate >= $firstIAUDate) then
  set self_IAU = ${ArgIAU}
endif
if ( ${self_IAU} == True ) then
  set IAUDate = `$advanceCYMDH ${thisCycleDate} -${self_FCIntervalHR}`
  setenv IAUDate ${IAUDate}
  set BGFileExt = `$TimeFmtChange ${IAUDate}`.00.00.nc    # analysis - 3h [YYYY-MM-DD_HH.00.00]
  set BGFile   = ${prevCyclingFCDir}/${FCFilePrefix}.${BGFileExt}    # mpasout at (analysis - 3h)
  set BGFileA  = ${CyclingDAInDir}/${BGFilePrefix}.${icFileExt}	  # bg at the analysis time
  echo ""
  echo "IAU needs two background files:"
  echo "IC: ${BGFile}"
  echo "bg: ${BGFileA}"

  if ( -e ${BGFile} && -e ${BGFileA} ) then
    mv ./${icFile} ${icFile}_nonIAU

    echo "IAU starts from ${IAUDate}."
    set StartDate  = `$TimeFmtChange ${IAUDate}`:00:00      # YYYYMMDDHH => YYYY-MM-DD_HH:00:00
    # Compute analysis increments (AmB)
    ln -sfv ${initialState} ${ANFilePrefix}.${icFileExt}    # an.YYYY-MM-DD_HH.00.00.nc
    ln -sfv ${BGFileA}      ${BGFilePrefix}.${icFileExt}    # bg.YYYY-MM-DD_HH.00.00.nc
    setenv myCommand "${create_amb_in_nc} ${thisValidDate}" # ${IAU_window_s}"
    echo "$myCommand"
    ${myCommand}
    set famb = AmB.`$TimeFmtChange ${IAUDate}`.00.00.nc
    ls -lL $famb || exit 1
    # Initial condition (mpasin.YYYY-MM-DD_HH.00.00.nc)
    ln -sfv ${BGFile} ${ICFilePrefix}.${BGFileExt} || exit 1
  else		# either analysis or background does not exist; IAU is off.
    echo "IAU is enabled, but one of two input files is missing."
    echo "Thus IAU is turned off at this cycle and the forecast is initialized at ${thisValidDate}."
    set self_IAU = False
    set self_FCLengthHR = ${CyclingWindowHR}
  endif
endif

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
  if( -e $staticfile ) rm ./$staticfile
  ln -sfv $ModelConfigDir/forecast/$staticfile .
end

## copy/modify dynamic streams file
if( -e ${StreamsFile}) rm ${StreamsFile}
cp -v $ModelConfigDir/forecast/${StreamsFile} .
sed -i 's@{{nCells}}@'${nCells}'@' ${StreamsFile}
sed -i 's@{{outputInterval}}@'${self_FCIntervalHR}':00:00@' ${StreamsFile}
sed -i 's@{{StaticFieldsPrefix}}@'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@{{ICFilePrefix}}@'${ICFilePrefix}'@' ${StreamsFile}
sed -i 's@{{FCFilePrefix}}@'${FCFilePrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

## Update sea-surface variables from GFS/GEFS analyses
set localSeaUpdateFile = x1.${nCells}.sfc_update.nc
sed -i 's@{{surfaceUpdateFile}}@'${localSeaUpdateFile}'@' ${StreamsFile}

if ("${ArgUpdateSea}" == True) then
  ## sea/ocean surface files
  # TODO: move sea directory configuration to yamls
  setenv seaMaxMembers 20
  set EADir = ${ExperimentDirectory}/`echo "${ExternalAnalysesDirOuter}" \
    | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
    `
  setenv deterministicSeaAnaDir ${EADir}
  setenv deterministicSeaMemFmt " "
  setenv deterministicSeaFilePrefix x1.${nCells}.init

  # need to change to mainScriptDir to source firstbackground
  # TODO: remove this dependence
  cd ${mainScriptDir}
  source config/auto/firstbackground.csh
  cd -

  if ( $nMembers > 1 && "$firstbackground__resource" == "PANDAC.LaggedGEFS" ) then
    # using member-specific sst/xice data from GEFS, only works for this special case
    # 60km and 120km
    setenv SeaAnaDir /glade/p/mmm/parc/guerrett/pandac/fixed_input/GEFS/surface/000hr/${model__precision}/${thisValidDate}
    setenv seaMemFmt "/{:02d}"
    setenv SeaFilePrefix x1.${nCells}.sfc_update
  else if ( $nMembers > 1 && "$firstbackground__resource" == "SIO.GEFS" ) then
    # using member-specific sst/xice data from GEFS, only works for this special case
    # 60km and 30km
    setenv SeaAnaDir /glade/scratch/ivette/GEFS_data/surface/$outerMesh/${thisValidDate}
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
if( -e ${NamelistFile}) rm ${NamelistFile}
cp -v $ModelConfigDir/forecast/$NamelistFile .
sed -i 's@startTime@'${StartDate}'@' $NamelistFile
sed -i 's@fcLength@'${self_FCLengthHR}':00:00@' $NamelistFile
sed -i 's@nCells@'${nCells}'@' $NamelistFile
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile
set configDODACycling = `echo "$ArgDACycling" | sed 's/\(.*\)/\L\1/'` # converts to lower-case
sed -i 's@configDODACycling@'${configDODACycling}'@' $NamelistFile
if ( ${self_IAU} == True ) then
  sed -i 's@{{IAU}}@on@' $NamelistFile
  echo "$0 (INFO): IAU is turned on."
else
  sed -i 's@{{IAU}}@off@' $NamelistFile
  echo "$0 (INFO): IAU is turned off."
endif

if ( ${ArgFCLengthHR} == 0 ) then
  ## zero-length forecast case (NOT CURRENTLY USED)
  rm ./${icFile}_tmp
  mv ./${icFile} ./${icFile}_tmp
  rm ${FCFilePrefix}.${icFileExt}
  cp ${icFile}_tmp ${FCFilePrefix}.${icFileExt}
  rm ./${DIAGFilePrefix}.${icFileExt}
  ln -sfv ${self_icStateDir}/${DIAGFilePrefix}.${icFileExt} ./
else
  ## remove previously generated forecasts
  set fcDate = `$advanceCYMDH ${thisValidDate} ${self_FCIntervalHR}`
  set finalFCDate = `$advanceCYMDH ${thisValidDate} ${self_FCLengthHR}`
  while ( ${fcDate} <= ${finalFCDate} )
    set fcFileDate  = `$TimeFmtChange ${fcDate}`
    set fcFile = ${FCFilePrefix}.${fcFileDate}.00.00.nc

    if( -e ${fcFile} ) rm ${fcFile}

    set fcDate = `$advanceCYMDH ${fcDate} ${self_FCIntervalHR}`
    setenv fcDate ${fcDate}
  end

  # Run the executable
  # ==================
  # load Forecast environment here to avoid conflict between multiple python versions
  cd ${mainScriptDir}
  source config/environmentForecast.csh
  cd -

  set log = log.${MPASCore}.0000.out
  foreach f ($log $ForecastEXE)
    if ( -e $f ) rm -v $f
  end
  ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
  ${mpiCommand} ./${ForecastEXE}


  # Check status
  # ============
  grep "Finished running the ${MPASCore} core" $log
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
  set fcFileDate  = `$TimeFmtChange ${fcDate}`
  set fcFile = ${FCFilePrefix}.${fcFileDate}.00.00.nc
  rm ${fcFile}
  set diagFile = ${DIAGFilePrefix}.${fcFileDate}.00.00.nc
  rm ${diagFile}
endif

date

exit 0
