#!/bin/csh

date

set ArgMember = "$1"

#
# Setup environment:
# =============================================
source ./control.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set cycle_Date = ${yymmdd}${hh}
set validDate = ${cycle_Date}
source ./getCycleVars.csh

set test = `echo $ArgMember | grep '^[0-9]*$'`
set isInt = (! $status)
if ( $isInt && "$ArgMember" != "0") then
  set self_WorkDir = $WorkDirsArg[$ArgMember]
else
  set self_WorkDir = $WorkDirsArg
endif

set self_icStateDir = $CyclingDAOutDirs[$ArgMember]
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

#
# Copy/link static files:
# =============================================
cp $FC_NML_DIR/* .
ln -sf $GRAPHINFO_DIR/x1.${MPAS_NCELLS}.graph.info* .
ln -sf ${TOP_BUILD_DIR}/libs/build/${MPASBUILD}/src/core_atmosphere/physics/physics_wrf/files/* .
cp namelist.atmosphere orig_namelist.atmosphere

#
# Revise time info in namelist
# =============================================
cat >! newnamelist << EOF
  /config_start_time /c\
   config_start_time      = '${NMLDate}'
  /config_run_duration/c\
   config_run_duration    = '${config_run_duration}'
EOF
sed -f newnamelist orig_namelist.atmosphere >! namelist.atmosphere
rm newnamelist

set STREAMS=streams.atmosphere
sed -e 's@OUT_DT_STR@'${output_interval}'@' \
    ${STREAMS}_TEMPLATE > ${STREAMS}

if ( ${self_fcLengthHR} == 0 ) then
  ## zero-length forecast case (NOT CURRENTLY USED)
  mv ./${icFile} ./${icFile}_tmp
  cp ${icFile}_tmp ${FCFilePrefix}.${icFileExt}
  ln -sf ${self_icStateDir}/${DIAGFilePrefix}.${icFileExt} ./
else
  #
  # Run the executable:
  # =============================================
  ln -sf ${MPASBUILDDIR}/${FCEXE} ./
  mpiexec ./${FCEXE}

  #
  # Check status:
  # =============================================
  grep "Finished running the atmosphere core" log.atmosphere.0000.out
  if ( $status != 0 ) then
    touch ./FAIL
    echo "ERROR in $0 : MPAS-Model forecast failed" >> ./FAIL
    exit 1
  endif
endif

set fcDate = `$advanceCYMDH ${validDate} ${self_fcIntervalHR}`
set finalFCDate = `$advanceCYMDH ${validDate} ${self_fcLengthHR}`
while ( ${fcDate} <= ${finalFCDate} )
  #
  # Update/add fields to output for DA
  # =============================================
  set yy = `echo ${fcDate} | cut -c 1-4`
  set mm = `echo ${fcDate} | cut -c 5-6`
  set dd = `echo ${fcDate} | cut -c 7-8`
  set hh = `echo ${fcDate} | cut -c 9-10`
  set fcFileDate  = ${yy}-${mm}-${dd}_${hh}.00.00
  set fcFileExt = ${fcFileDate}.nc
  set fcFile = ${FCFilePrefix}.${fcFileExt}
  set fcFileNoSea = ${fcFile}.NOSEA

  ## move restart to forecast name
  mv ${RSTFilePrefix}.${fcFileExt} ${fcFile}

  ## Update MPAS sea surface variables:
  if ( ${updateSea} ) then
    #delete MPASSeaVars from previous GFS ANA
    ncks -a -x -v ${MPASSeaVars} ${fcFile} ${fcFileNoSea}

    #append MPASSeaVars from current GFS ANA
    set SST_FILE = ${GFSSST_DIR}/${fcDate}/x1.${MPAS_NCELLS}.sfc_update.${fcFileExt}
    ncks -A -v ${MPASSeaVars} ${SST_FILE} ${fcFileNoSea}
    mv  ${fcFileNoSea} ${fcFile}
  endif

  ## Add MPASDiagVars to the next cycle bg file (if needed)
  set copyDiags = 0
  foreach var ({$MPASDiagVars})
    ncdump -h ${fcFile} | grep $var
    if ( $status != 0 ) then
      @ copyDiags++
    endif 
  end
  set diagFile = ${DIAGFilePrefix}.${fcFileExt}
  if ( $copyDiags > 0 ) then
    ncks -A -v ${MPASDiagVars} ${diagFile} ${fcFile}
  endif
  rm ${diagFile}

#  echo `pwd`"/${fcFile}" > outList${fcDate}

  set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
  setenv fcDate ${fcDate}
end

date

exit 0
