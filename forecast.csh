#!/bin/csh -f
# forecast.csh
date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"
set ArgFcIntervalHR = "$2" 	# fcIntervalHRTEMPLATE
set ArgFcLengthHR = "$3" 	# fcLengthHRTEMPLATE
set ArgFcIAU = "$4"             # forecastIAU

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
source config/workflow.csh
source config/experiment.csh
source config/tools.csh
source config/model.csh
source config/modeldata.csh
source config/builds.csh
source config/environmentJEDI.csh
source config/applications/forecast.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
echo "WorkDir = ${self_WorkDir}"
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

# Default templated variables based on the input arguments.
set config_run_duration  = ${ArgFcLengthHR}:00:00
set output_interval      = ${ArgFcIntervalHR}:00:00
set deleteZerothForecast = deleteZerothForecastTEMPLATE
set self_icStateDir      = $StateDirsTEMPLATE[$ArgMember]

# Input parameters can further change for the first DA cycle inside this script.
set self_FcIntervalHR = ${ArgFcIntervalHR}
set self_FcLengthHR   = ${ArgFcLengthHR}
set self_FcIAU        = ${ArgFcIAU}       # True or False (default)
set StartDate = ${thisMPASNamelistDate}

# static variables
set self_icStatePrefix = ${ANFilePrefix}

# ================================================================================================

## copy static fields and link initial forecast state
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
set icFileExt = ${thisMPASFileDate}.nc
set icFile = ${ICFilePrefix}.${icFileExt}
if( -e ${icFile} ) rm ./${icFile}
if ( ${InitializationType} == "ColdStart" && ${thisValidDate} == ${FirstCycleDate}) then
  set initialState = ${InitICWorkDir}/${thisValidDate}/${InitFilePrefixOuter}.${icFileExt}
  set do_DAcycling = "false"
  ln -sfv ${initialState} ${localStaticFieldsFile}
  set self_FcIAU = False
  setenv IAU False
else
  set initialState = ${self_icStateDir}/${self_icStatePrefix}.${icFileExt}
  set do_DAcycling = "true"
  set firstIAUDate = `$advanceCYMDH ${FirstCycleDate} ${IAUoutIntervalHR}`
  set StaticMemDir = `${memberDir} 2 $ArgMember "${staticMemFmt}"`
  set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
  cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

  # We can start IAU only from the second DA cycle (otherwise, 3hrly background forecast is not available yet.)
  if ( ${self_FcIAU} == True && $thisValidDate > $firstIAUDate) then 
   set IAUDate = `$advanceCYMDH ${thisCycleDate} -${IAUoutIntervalHR}`
   setenv IAUDate ${IAUDate}
   set BGFileExt = `$TimeFmtChange ${IAUDate}`.00.00.nc   	# analysis - 3h [YYYY-MM-DD_HH.00.00]
   set BGFile   = ${prevCyclingFCDir}/${FCFilePrefix}.${BGFileExt}	# mpasout at (analysis - 3h)
   set BGFileA  = ${CyclingDAInDir}/${BGFilePrefix}.${icFileExt}	# bg at the analysis time
   echo ""
   echo "IAU needs two background files:"
   echo "IC: ${BGFile}"
   echo "bg: ${BGFileA}"

   if ( -e ${BGFile} && -e ${BGFileA} ) then
    echo "IAU starts from ${IAUDate}."
    set StartDate  = `$TimeFmtChange ${IAUDate}`:00:00	# YYYYMMDDHH => YYYY-MM-DD_HH:00:00
    # Compute analysis increments (AmB)
    ln -sfv ${initialState} ${ANFilePrefix}.${icFileExt}		# an.YYYY-MM-DD_HH.00.00.nc
    ln -sfv ${BGFileA}      ${BGFilePrefix}.${icFileExt}		# bg.YYYY-MM-DD_HH.00.00.nc
    setenv myCommand "${create_amb_in_nc} ${thisValidDate}" # ${IAU_window_s}"
    echo "$myCommand"
    ${myCommand}
    set famb = AmB.`$TimeFmtChange ${IAUDate}`.00.00.nc
    ls -lL $famb						|| exit
    # Initial condition (mpasin.YYYY-MM-DD_HH.00.00.nc)
    ln -sfv ${BGFile} ${ICFilePrefix}.${BGFileExt}		|| exit
   else		# either analysis or background does not exist; IAU is off.
    echo "IAU was on, but no input files. So it is off and initialized at ${thisValidDate}."
    setenv IAU False
    set self_FcIAU          = False
    set self_FcLengthHR   = ${CyclingWindowHR}
    set config_run_duration = ${self_FcLengthHR}:00:00
    set output_interval     = ${self_FcIntervalHR}:00:00
   endif
  endif # ( ${IAU} == True ) then
endif
ln -sfv ${initialState} ./${icFile}
if ( ${self_FcIAU} == True ) \rm -f ./${icFile}

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
  ln -sfv $ModelConfigDir/$AppName/$staticfile .
end

## copy/modify dynamic streams file
if( -e ${StreamsFile}) rm ${StreamsFile}
cp -v $ModelConfigDir/$AppName/${StreamsFile} .
sed -i 's@nCells@'${nCells}'@' ${StreamsFile}
sed -i 's@outputInterval@'${output_interval}'@' ${StreamsFile}
sed -i 's@StaticFieldsPrefix@'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@ICFilePrefix@'${ICFilePrefix}'@' ${StreamsFile}
sed -i 's@FCFilePrefix@'${FCFilePrefix}'@' ${StreamsFile}
sed -i 's@{{PRECISION}}@'${model__precision}'@' ${StreamsFile}

## Update sea-surface variables from GFS/GEFS analyses
set localSeaUpdateFile = x1.${nCells}.sfc_update.nc
sed -i 's@{{surfaceUpdateFile}}@'${localSeaUpdateFile}'@' ${StreamsFile}

if ( "${updateSea}" == "True" ) then
  # first try member-specific state file (central GFS state when ArgMember==0)
  set seaMemDir = `${memberDir} 2 $ArgMember "${seaMemFmt}" -m ${seaMaxMembers}`
  set SeaFile = ${SeaAnaDir}/${thisValidDate}${seaMemDir}/${SeaFilePrefix}.${icFileExt}
  ln -sf ${SeaFile} ./${localSeaUpdateFile}
  set brokenLinks=( `find ${localSeaUpdateFile} -mindepth 0 -maxdepth 0 -type l -exec test ! -e {} \; -print` )
  set broken=0
  foreach l ($brokenLinks)
    @ broken++
  end

  #if link broken
  if ( $broken > 0 ) then
    echo "$0 (WARNING): file link broken to ${SeaFile}" >> ./WARNING

    # otherwise try central GFS state file
    set SeaFile = ${deterministicSeaAnaDir}/${thisValidDate}/${SeaFilePrefix}.${icFileExt}
    ln -sf ${SeaFile} ./${localSeaUpdateFile}
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
cp -v $ModelConfigDir/$AppName/$NamelistFile .
sed -i 's@startTime@'${StartDate}'@' $NamelistFile
sed -i 's@fcLength@'${config_run_duration}'@' $NamelistFile
sed -i 's@nCells@'${nCells}'@' $NamelistFile
sed -i 's@modelDT@'${TimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${DiffusionLengthScale}'@' $NamelistFile
sed -i 's@configDODACycling@'${do_DAcycling}'@' $NamelistFile
if ( ${self_FcIAU} == True ) then
    sed -i 's@off@on@' $NamelistFile
    echo "IAU is turned on."
endif

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
  set fcDate = `$advanceCYMDH ${thisValidDate} ${self_FcIntervalHR}`
  set finalFCDate = `$advanceCYMDH ${thisValidDate} ${self_FcLengthHR}`
  while ( ${fcDate} <= ${finalFCDate} )
    set fcFileDate  = `$TimeFmtChange ${fcDate}`
    set fcFile = ${FCFilePrefix}.${fcFileDate}.00.00.nc

    if( -e ${fcFile} ) rm ${fcFile}

    set fcDate = `$advanceCYMDH ${fcDate} ${self_FcIntervalHR}`
    setenv fcDate ${fcDate}
  end

  # Run the executable
  # ==================
  if( -e ${ForecastEXE} ) rm ./${ForecastEXE}
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
  if ( ${InitializationType} == "WarmStart" ) then
    rm ${localStaticFieldsFile}
    mv ${localStaticFieldsFile}${OrigFileSuffix} ${localStaticFieldsFile}
  endif
endif

if ( "$deleteZerothForecast" == "True" ) then
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
