#!/bin/csh
#PBS -N fcicDateArg_ExpNameArg
#PBS -A AccountNumArg
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

setenv self_icDate        icDateArg
setenv self_fcLengthHR    fcLengthHRArg
setenv self_fcIntervalHR  fcIntervalHRArg
setenv self_icStateDir    icStateDirArg
setenv self_icStatePrefix icStatePrefixArg

setenv FC_LENGTH_STR 0_${self_fcLengthHR}:00:00
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

## link initial forecast state:
ln -sf ${self_icStateDir}/${self_icStatePrefix}.${icFileDate}.nc ./${ICFilePrefix}.${icFileDate}.nc

## zero-length forecast case
if ( ${self_fcLengthHR} == 0 ) then
  ## copy IC file to forecast name
  mv ./${ICFilePrefix}.${icFileDate}.nc ./${ICFilePrefix}.${icFileDate}.nc_tmp
  cp ${ICFilePrefix}.${icFileDate}.nc_tmp ${FCFilePrefix}.${icFileDate}.nc

  ## Add MPASDiagVars to the next cycle bg file
  ncks -A -v ${MPASDiagVars} ${self_icStateDir}/${DIAGFilePrefix}.${icFileDate}.nc ${FCFilePrefix}.${icFileDate}.nc
  exit 0
endif


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
   config_run_duration    = '${FC_LENGTH_STR}'
EOF
sed -f newnamelist orig_namelist.atmosphere >! namelist.atmosphere
rm newnamelist

set STREAMS=streams.atmosphere
sed -e 's@OUT_DT_STR@'${OUT_DT_STR}'@' \
    ${STREAMS}_TEMPLATE > ${STREAMS}

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

  ## move restart to forecast name
  mv ${RSTFilePrefix}.${fcFileDate}.nc ${FCFilePrefix}.${fcFileDate}.nc

  ## Update MPAS sea surface variables:
  if ( ${updateSea} ) then
    #delete MPASSeaVars from previous GFS ANA
    ncks -a -x -v ${MPASSeaVars} ${FCFilePrefix}.${fcFileDate}.nc ${FCFilePrefix}.${fcFileDate}.nosea.nc

    #append MPASSeaVars from current GFS ANA
    setenv SST_FILE ${GFSSST_DIR}/${fcDate}/x1.${MPAS_NCELLS}.sfc_update.${fcFileDate}.nc
    ncks -A -v ${MPASSeaVars} ${SST_FILE} ${FCFilePrefix}.nosea.${fcFileDate}.nc
    mv  ${FCFilePrefix}.nosea.${fcFileDate}.nc  ${FCFilePrefix}.${fcFileDate}.nc
  endif

  ## Add MPASDiagVars to the next cycle bg file
  ncks -A -v ${MPASDiagVars} ${DIAGFilePrefix}.${fcFileDate}.nc ${FCFilePrefix}.${fcFileDate}.nc

  set fcDate = `$advanceCYMDH ${fcDate} ${self_fcIntervalHR}`
  setenv fcDate ${fcDate}
end

date

exit 0
