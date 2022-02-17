#!/bin/csh -f
# forecast.csh
date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

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
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/mpas/variables.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/builds.csh
source config/environment.csh
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

# other templated variables
set self_icStateDir = $StateDirsTEMPLATE[$ArgMember]
set self_fcLengthHR = fcLengthHRTEMPLATE
set self_fcIntervalHR = fcIntervalHRTEMPLATE
set config_run_duration = 0_${self_fcLengthHR}:00:00
set output_interval = 0_${self_fcIntervalHR}:00:00
set deleteZerothForecast = deleteZerothForecastTEMPLATE

# IAU
set IAU_on = False 		# True or False (=default)
set StartDate = ${NMLDate}
set self_CycleFreqHR = fcIntervalHRTEMPLATE

# static variables
set self_icStatePrefix = ${ANFilePrefix}
set self_ModelConfigDir = $forecastModelConfigDir

# ================================================================================================

## copy static fields and link initial forecast state
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
if( -e ${localStaticFieldsFile} ) rm ${localStaticFieldsFile}
set icFileExt = ${fileDate}.nc
set icFile = ${ICFilePrefix}.${icFileExt}
if( -e ${icFile} ) rm ./${icFile}
if ( ${InitializationType} == "ColdStart" && ${thisValidDate} == ${FirstCycleDate}) then
  set initialState = ${InitICDir}/${InitFilePrefixOuter}.${icFileExt}
  set do_DAcycling = "false"
  ln -sfv ${initialState} ${localStaticFieldsFile}
  setenv IAU False
else
  set initialState = ${self_icStateDir}/${self_icStatePrefix}.${icFileExt}
  set do_DAcycling = "true"
  set StaticMemDir = `${memberDir} ensemble $ArgMember "${staticMemFmt}"`
  set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
  cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

  if ( ${IAU} == True ) then
   set BGFileExt = `$TimeFmtChange ${IAUDate}`.00.00.nc   	# analysis - 3h [YYYY-MM-DD_HH.00.00]
   set BGFile   = ${prevCyclingFCDir}/${FCFilePrefix}.${BGFileExt}	# mpasout at (analysis - 3h)
   set BGFileA  = ${CyclingDAInDir}/${BGFilePrefix}.${icFileExt}	# bg at the analysis time
   echo ""
   echo "IAU needs two background files:"
   echo "IC: ${BGFile}"
   echo "bg: ${BGFileA}"

   if ( -e ${BGFile} && -e ${BGFileA} ) then
    echo "IAU starts from ${IAUDate}."
    set IAU_on = True
    set self_CycleFreqHR = CyclingFrequencyHR
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
    echo "IAU was on, but no input files. So it is off and initialized at ${fileDate}."
    setenv IAU False
   endif
  endif # ( ${IAU} == True ) then
endif
ln -sfv ${initialState} ./${icFile}
if ( ${IAU} == True ) \rm -f ./${icFile}

## link MPAS mesh graph info
rm ./x1.${MPASnCellsOuter}.graph.info*
ln -sfv $GraphInfoDir/x1.${MPASnCellsOuter}.graph.info* .

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
  ln -sfv $self_ModelConfigDir/$staticfile .
end

## copy/modify dynamic streams file
if( -e ${StreamsFile}) rm ${StreamsFile}
cp -v $self_ModelConfigDir/${StreamsFile} .
sed -i 's@nCells@'${MPASnCellsOuter}'@' ${StreamsFile}
sed -i 's@outputInterval@'${output_interval}'@' ${StreamsFile}
sed -i 's@StaticFieldsPrefix@'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@ICFilePrefix@'${ICFilePrefix}'@' ${StreamsFile}
sed -i 's@FCFilePrefix@'${FCFilePrefix}'@' ${StreamsFile}
sed -i 's@forecastPrecision@'${forecastPrecision}'@' ${StreamsFile}

## copy/modify dynamic namelist
if( -e ${NamelistFile}) rm ${NamelistFile}
cp -v ${self_ModelConfigDir}/${NamelistFile} .
sed -i 's@startTime@'${StartDate}'@' $NamelistFile
sed -i 's@fcLength@'${config_run_duration}'@' $NamelistFile
sed -i 's@nCells@'${MPASnCellsOuter}'@' $NamelistFile
sed -i 's@modelDT@'${MPASTimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' $NamelistFile
sed -i 's@configDODACycling@'${do_DAcycling}'@' $NamelistFile
if ( ${IAU_on} == True ) then
    sed -i 's@off@on@' $NamelistFile
    echo "IAU is turned on."
endif
#   set IAU_window_s = 3600.
#   @ IAU_window_s *= ${self_fcIntervalHR}
#   sed -i 's@IAUwindowSecs@'${IAU_window_s}'@' $NamelistFile

if ( ${self_fcLengthHR} == 0 ) then
  ## zero-length forecast case (NOT CURRENTLY USED)
  rm ./${icFile}_tmp
  mv ./${icFile} ./${icFile}_tmp
  rm ${FCFilePrefix}.${icFileExt}
  cp ${icFile}_tmp ${FCFilePrefix}.${icFileExt}
  rm ./${DIAGFilePrefix}.${icFileExt}
  ln -sfv ${self_icStateDir}/${DIAGFilePrefix}.${icFileExt} ./
else
  ## remove previously generated forecasts
  set fcDate = `$advanceCYMDH ${thisValidDate} ${self_fcIntervalHR}`
  set finalFCDate = `$advanceCYMDH ${thisValidDate} ${self_fcLengthHR}`
  while ( ${fcDate} <= ${finalFCDate} )
    set fcFileDate  = `$TimeFmtChange ${fcDate}`
    set fcFile = ${FCFilePrefix}.${fcFileDate}.00.00.nc

    if( -e ${fcFile} ) rm ${fcFile}

    set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
    setenv fcDate ${fcDate}
  end

  # Run the executable
  # ==================
  if( -e ${ForecastEXE} ) rm ./${ForecastEXE}
  ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
  mpiexec ./${ForecastEXE}


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

# Update/add fields to output for DA
# ==================================
#TODO: do this in a separate post-processing script
#      either in parallel or using only single processor
#      instead of full set of job processors
if ( ${IAU} == True ) then
set fcDate = `$advanceCYMDH ${IAUDate} ${self_fcIntervalHR}`
set finalFCDate = `$advanceCYMDH ${IAUDate} ${self_fcLengthHR}`
else
set fcDate = `$advanceCYMDH ${thisValidDate} ${self_fcIntervalHR}`
set finalFCDate = `$advanceCYMDH ${thisValidDate} ${self_fcLengthHR}`
endif
while ( ${fcDate} <= ${finalFCDate} )
  set fcFileDate  = `$TimeFmtChange ${fcDate}`.00.00
  set fcFileExt = ${fcFileDate}.nc
  set fcFile = ${FCFilePrefix}.${fcFileExt}

  ## Update MPASSeaVariables from GFS/GEFS analyses
  if ( ${updateSea} ) then
    # first try member-specific state file (central GFS state when ArgMember==0)
    set seaMemDir = `${memberDir} ens $ArgMember "${seaMemFmt}" -m ${seaMaxMembers}`
    set SeaFile = ${SeaAnaDir}/${fcDate}${seaMemDir}/${SeaFilePrefix}.${fcFileExt}
    if ( -e ${SeaFile} ) then
    ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}
    if ( $status != 0 ) then
      echo "WARNING in $0 : ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}" > ./WARNING
      echo "WARNING in $0 : ncks could not add (${MPASSeaVariables}) to $fcFile" >> ./WARNING

      # otherwise try central GFS state file
      set SeaFile = ${deterministicSeaAnaDir}/${fcDate}/${SeaFilePrefix}.${fcFileExt}
      ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}
      if ( $status != 0 ) then
        echo "ERROR in $0 : ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}" > ./FAIL
        echo "ERROR in $0 : ncks could not add (${MPASSeaVariables}) to $fcFile" >> ./FAIL
        exit 1
      endif
    endif
    else
      echo "WARNING in $0 : ${SeaFile} is not found. Skip adding ${MPASSeaVariables} to $fcFile" > ./WARNING
    endif # ( -e $${SeaFile} ) then
  endif

  ## Add MPASJEDIDiagVariables to the next cycle bg file (if needed)
  set copyDiags = 0
  foreach var ({$MPASJEDIDiagVariables})
    ncdump -h ${fcFile} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif
  end
  set diagFile = ${DIAGFilePrefix}.${fcFileExt}
  if ( $copyDiags > 0 ) then
    echo "ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${fcFile}"
    ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${fcFile}
  endif
  # rm ${diagFile}

  set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
  setenv fcDate ${fcDate}
end

date

exit 0
