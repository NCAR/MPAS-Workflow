#!/bin/csh

date

set ArgMember = "$1"

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

set test = `echo $ArgMember | grep '^[0-9]*$'`
set isInt = (! $status)
if ( $isInt && "$ArgMember" != "0") then
  set self_WorkDir = $WorkDirsArg[$ArgMember]
  set self_icStateDir = $StateDirsArg[$ArgMember]
else
  set self_WorkDir = $WorkDirsArg
  set self_icStateDir = $StateDirsArg
endif

set self_icStatePrefix = ${ANFilePrefix}
set self_fcLengthHR = fcLengthHRArg
set self_fcIntervalHR = fcIntervalHRArg

set config_run_duration = 0_${self_fcLengthHR}:00:00
set output_interval = 0_${self_fcIntervalHR}:00:00

echo "WorkDir = ${self_WorkDir}"

rm -r ${self_WorkDir}
mkdir -p ${self_WorkDir}
cd ${self_WorkDir}

set icFileExt = ${fileDate}.nc
set icFile = ${ICFilePrefix}.${icFileExt}

## link initial forecast state:
ln -sf ${self_icStateDir}/${self_icStatePrefix}.${icFileExt} ./${icFile}

## link static fields:
ln -sf ${staticFieldsFile} ${localStaticFieldsFile}

# ====================
# Model-specific files
# ====================
## link MPAS mesh graph info
ln -sf $GRAPHINFO_DIR/x1.${MPASnCells}.graph.info* .

## link lookup tables
foreach fileGlob ($FCLookupFileGlobs)
  ln -sf ${FCLookupDir}/*${fileGlob} .
end

## link/copy stream_list/streams configs
foreach staticfile ( \
stream_list.${MPASCore}.surface \
stream_list.${MPASCore}.diagnostics \
stream_list.${MPASCore}.output \
)
  ln -sf $fcModelConfigDir/$staticfile .
end
set STREAMS = streams.${MPASCore}
rm ${STREAMS}
cp -v $fcModelConfigDir/${STREAMS} .
sed -i 's@nCells@'${MPASnCells}'@' ${STREAMS}
sed -i 's@outputIntervalArg@'${output_interval}'@' ${STREAMS}

## copy/modify dynamic namelist
set NL = namelist.atmosphere
rm ${NL}
cp -v ${fcModelConfigDir}/${NL} .
sed -i 's@startTime@'${NMLDate}'@' $NL
sed -i 's@fcLength@'${config_run_duration}'@' $NL
sed -i 's@nCells@'${MPASnCells}'@' $NL
sed -i 's@modelDT@'${MPASTimeStep}'@' $NL
sed -i 's@diffusionLengthScale@'${MPASDiffusionLengthScale}'@' $NL

if ( ${self_fcLengthHR} == 0 ) then
  ## zero-length forecast case (NOT CURRENTLY USED)
  mv ./${icFile} ./${icFile}_tmp
  cp ${icFile}_tmp ${FCFilePrefix}.${icFileExt}
  ln -sf ${self_icStateDir}/${DIAGFilePrefix}.${icFileExt} ./
else
  #
  # Run the executable:
  # =============================================
  ln -sf ${FCBuildDir}/${FCEXE} ./
  mpiexec ./${FCEXE}

  #
  # Check status:
  # =============================================
  grep "Finished running the ${MPASCore} core" log.${MPASCore}.0000.out
  if ( $status != 0 ) then
    touch ./FAIL
    echo "ERROR in $0 : MPAS-Model forecast failed" >> ./FAIL
    exit 1
  endif
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

  ## Update MPASSeaVariables from GFS ANA:
  if ( ${updateSea} ) then
    set SST_FILE = ${GFSSST_DIR}/${fcDate}/x1.${MPASnCells}.sfc_update.${fcFileExt}
    ncks -A -v ${MPASSeaVariables} ${SST_FILE} ${fcFile}
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
