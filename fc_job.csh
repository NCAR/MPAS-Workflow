#!/bin/csh
#PBS -N fcinDateArg_ExpNameArg
#PBS -A AccountNumberArg
#PBS -q QueueNameArg
#PBS -l select=4:ncpus=32:mpiprocs=32:mem=109GB
#PBS -l walltime=00:JobMinutes:00
#PBS -m ae
#PBS -k eod
#   #PBS -V 
#PBS -o log.job.out
#PBS -e log.job.err

date

#
# Setup environment:
# =============================================
source ./setup.csh

setenv self_icDate        inDateArg
setenv self_icStateDir    inStateDirArg
setenv self_icStatePrefix inStatePrefixArg
setenv self_fcLengthHR    fcLengthHRArg
setenv self_fcIntervalHR  fcIntervalHRArg

setenv config_run_duration 0_${self_fcLengthHR}:00:00
setenv OUT_DT_STR 0_${self_fcIntervalHR}:00:00

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${self_icDate} | cut -c 1-4`
set mm = `echo ${self_icDate} | cut -c 5-6`
set dd = `echo ${self_icDate} | cut -c 7-8`
set hh = `echo ${self_icDate} | cut -c 9-10`
set icFileDate = ${yy}-${mm}-${dd}_${hh}.00.00
set icNMLDate = ${yy}-${mm}-${dd}_${hh}:00:00

set icFileExt = "${icFileDate}.nc"
set icFile = ${ICFilePrefix}.${fcFileExt}

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
   config_start_time      = '${icNMLDate}'
  /config_run_duration/c\
   config_run_duration    = '${config_run_duration}'
EOF
sed -f newnamelist orig_namelist.atmosphere >! namelist.atmosphere
rm newnamelist

set STREAMS=streams.atmosphere
sed -e 's@OUT_DT_STR@'${OUT_DT_STR}'@' \
    ${STREAMS}_TEMPLATE > ${STREAMS}

if ( ${self_fcLengthHR} == 0 ) then
  ## zero-length forecast case
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

set fcDate = `$advanceCYMDH ${self_icDate} ${self_fcIntervalHR}`
set finalFCDate = `$advanceCYMDH ${self_icDate} ${self_fcLengthHR}`
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
