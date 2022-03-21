#!/bin/csh -f

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
source config/workflow.csh
source config/model.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/mpas/variables.csh
source config/mpas/${MPASGridDescriptor}/mesh.csh
source config/builds.csh
source config/environmentMPT.csh
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

# static variables
set self_icStatePrefix = ${ANFilePrefix}
set self_ModelConfigDir = $forecastModelConfigDir

# ================================================================================================

## copy static fields and link initial forecast state
rm ${localStaticFieldsPrefix}*.nc
rm ${localStaticFieldsPrefix}*.nc-lock
set localStaticFieldsFile = ${localStaticFieldsFileOuter}
rm ${localStaticFieldsFile}
set icFileExt = ${thisMPASFileDate}.nc
set icFile = ${ICFilePrefix}.${icFileExt}
rm ./${icFile}
if ( ${InitializationType} == "ColdStart" && ${thisValidDate} == ${FirstCycleDate}) then
  set initialState = ${InitICWorkDir}/${thisValidDate}/${InitFilePrefixOuter}.${icFileExt}
  set do_DAcycling = "false"
  ln -sfv ${initialState} ${localStaticFieldsFile}
else
  set initialState = ${self_icStateDir}/${self_icStatePrefix}.${icFileExt}
  set do_DAcycling = "true"
  set StaticMemDir = `${memberDir} ensemble $ArgMember "${staticMemFmt}"`
  set memberStaticFieldsFile = ${StaticFieldsDirOuter}${StaticMemDir}/${StaticFieldsFileOuter}
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
  cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}
endif
ln -sfv ${initialState} ./${icFile}

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
  rm ./$staticfile
  ln -sfv $self_ModelConfigDir/$staticfile .
end

## copy/modify dynamic streams file
rm ${StreamsFile}
cp -v $self_ModelConfigDir/${StreamsFile} .
sed -i 's@nCells@'${MPASnCellsOuter}'@' ${StreamsFile}
sed -i 's@outputInterval@'${output_interval}'@' ${StreamsFile}
sed -i 's@StaticFieldsPrefix@'${localStaticFieldsPrefix}'@' ${StreamsFile}
sed -i 's@ICFilePrefix@'${ICFilePrefix}'@' ${StreamsFile}
sed -i 's@FCFilePrefix@'${FCFilePrefix}'@' ${StreamsFile}
sed -i 's@forecastPrecision@'${forecastPrecision}'@' ${StreamsFile}

## copy/modify dynamic namelist
rm ${NamelistFile}
cp -v ${self_ModelConfigDir}/${NamelistFile} .
sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFile
sed -i 's@fcLength@'${config_run_duration}'@' $NamelistFile
sed -i 's@nCells@'${MPASnCellsOuter}'@' $NamelistFile
sed -i 's@modelDT@'${MPASTimeStep}'@' $NamelistFile
sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' $NamelistFile
sed -i 's@configDODACycling@'${do_DAcycling}'@' $NamelistFile

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
    set yy = `echo ${fcDate} | cut -c 1-4`
    set mm = `echo ${fcDate} | cut -c 5-6`
    set dd = `echo ${fcDate} | cut -c 7-8`
    set hh = `echo ${fcDate} | cut -c 9-10`
    set fcFileDate  = ${yy}-${mm}-${dd}_${hh}.00.00
    set fcFileExt = ${fcFileDate}.nc
    set fcFile = ${FCFilePrefix}.${fcFileExt}

    rm ${fcFile}

    set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
    setenv fcDate ${fcDate}
  end

  # Run the executable
  # ==================
  rm ./${ForecastEXE}
  ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
  # mpiexec is for Open MPI, mpiexec_mpt is for MPT
  #mpiexec ./${ForecastEXE}
  mpiexec_mpt ./${ForecastEXE}


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
  endid
endif

if ( "$deleteZerothForecast" == "True" ) then
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

# Update/add fields to output for DA
# ==================================
#TODO: do this in a separate post-processing script
#      either in parallel or using only single processor
#      instead of full set of job processors
set fcDate = `$advanceCYMDH ${thisValidDate} ${self_fcIntervalHR}`
set finalFCDate = `$advanceCYMDH ${thisValidDate} ${self_fcLengthHR}`
while ( ${fcDate} <= ${finalFCDate} )
  set yy = `echo ${fcDate} | cut -c 1-4`
  set mm = `echo ${fcDate} | cut -c 5-6`
  set dd = `echo ${fcDate} | cut -c 7-8`
  set hh = `echo ${fcDate} | cut -c 9-10`
  set fcFileDate  = ${yy}-${mm}-${dd}_${hh}.00.00
  set fcFileExt = ${fcFileDate}.nc
  set fcFile = ${FCFilePrefix}.${fcFileExt}

  ## Update MPASSeaVariables from GFS/GEFS analyses
  if ( ${updateSea} ) then
    # first try member-specific state file (central GFS state when ArgMember==0)
    set seaMemDir = `${memberDir} ens $ArgMember "${seaMemFmt}" -m ${seaMaxMembers}`
    set SeaFile = ${SeaAnaDir}/${fcDate}${seaMemDir}/${SeaFilePrefix}.${fcFileExt}
    echo "ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}"
    ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}
    if ( $status != 0 ) then
      echo "WARNING in $0 : ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}" > ./WARNING
      echo "WARNING in $0 : ncks could not add (${MPASSeaVariables}) to $fcFile" >> ./WARNING

      # otherwise try central GFS state file
      set SeaFile = ${deterministicSeaAnaDir}/${fcDate}/${SeaFilePrefix}.${fcFileExt}
      echo "ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}"
      ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}
      if ( $status != 0 ) then
        echo "ERROR in $0 : ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}" > ./FAIL
        echo "ERROR in $0 : ncks could not add (${MPASSeaVariables}) to $fcFile" >> ./FAIL
        exit 1
      endif
    endif
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
    ncks -A -v ${MPASJEDIDiagVariables} ${diagFile} ${fcFile}
  endif
  # rm ${diagFile}

  set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
  setenv fcDate ${fcDate}
end

date

exit 0
