#!/bin/csh

date

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

#
# Setup environment:
# =============================================
source config/experiment.csh
source config/data.csh
source config/mpas/variables.csh
source config/mpas/${MPASGridDescriptor}-mesh.csh
source config/build.csh
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

# static variables
set self_icStatePrefix = ${ANFilePrefix}

# ====================================================================

## link initial forecast state:
set icFileExt = ${fileDate}.nc
set icFile = ${ICFilePrefix}.${icFileExt}
rm ./${icFile}
ln -sfv ${self_icStateDir}/${self_icStatePrefix}.${icFileExt} ./${icFile}

## link MPAS mesh graph info
rm ./x1.${MPASnCells}.graph.info*
ln -sfv $GraphInfoDir/x1.${MPASnCells}.graph.info* .

## link lookup tables
foreach fileGlob ($ForecastLookupFileGlobs)
  rm ./*${fileGlob}
  ln -sfv ${ForecastLookupDir}/*${fileGlob} .
end

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
)
  rm ./$staticfile
  ln -sfv $forecastModelConfigDir/$staticfile .
end
set STREAMS = streams.${MPASCore}
rm ${STREAMS}
cp -v $forecastModelConfigDir/${STREAMS} .
sed -i 's@nCells@'${MPASnCells}'@' ${STREAMS}
sed -i 's@outputInterval@'${output_interval}'@' ${STREAMS}

## copy/modify dynamic namelist
set NL = namelist.atmosphere
rm ${NL}
cp -v ${forecastModelConfigDir}/${NL} .
sed -i 's@startTime@'${NMLDate}'@' $NL
sed -i 's@fcLength@'${config_run_duration}'@' $NL
sed -i 's@nCells@'${MPASnCells}'@' $NL
sed -i 's@modelDT@'${MPASTimeStep}'@' $NL
sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' $NL

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

  ## copy static fields:
  set staticMemDir = `${memberDir} ens $ArgMember "${staticMemFmt}"`
  set memberStaticFieldsFile = ${staticFieldsDir}${staticMemDir}/${staticFieldsFile}
  rm ${localStaticFieldsFile}
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}${OrigFileSuffix}
  cp -v ${memberStaticFieldsFile} ${localStaticFieldsFile}

  #
  # Run the executable:
  # =============================================
  rm ./${ForecastEXE}
  ln -sfv ${ForecastBuildDir}/${ForecastEXE} ./
  mpiexec ./${ForecastEXE}

  #
  # Check status:
  # =============================================
  grep "Finished running the ${MPASCore} core" log.${MPASCore}.0000.out
  if ( $status != 0 ) then
    touch ./FAIL
    echo "ERROR in $0 : MPAS-Model forecast failed" >> ./FAIL
    exit 1
  endif

  ## change static fields to a link:
  rm ${localStaticFieldsFile}
  rm ${localStaticFieldsFile}${OrigFileSuffix}
  ln -sfv ${memberStaticFieldsFile} ${localStaticFieldsFile}
endif

#
# Update/add fields to output for DA
# =============================================
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

  ## Update MPASSeaVariables from GFS/GEFS analyses:
  if ( ${updateSea} ) then
    set seaMemDir = `${memberDir} ens $ArgMember "${seaMemFmt}"`
    set SeaFile = ${SeaAnaDir}/${fcDate}${seaMemDir}/${SeaFilePrefix}.${fcFileExt}
    ncks -A -v ${MPASSeaVariables} ${SeaFile} ${fcFile}

    if ( $status != 0 ) then
      touch ./FAIL
      echo "ERROR in $0 : ncks could not add (${MPASSeaVariables}) to $fcFile" >> ./FAIL
      exit 1
    endif
  endif

  ## Add MPASDiagVariables to the next cycle bg file (if needed)
  set copyDiags = 0
  foreach var ({$MPASDiagVariables})
    ncdump -h ${fcFile} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif 
  end
  set diagFile = ${DIAGFilePrefix}.${fcFileExt}
  if ( $copyDiags > 0 ) then
    ncks -A -v ${MPASDiagVariables} ${diagFile} ${fcFile}
  endif
  # rm ${diagFile}

  set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
  setenv fcDate ${fcDate}
end

date

exit 0
