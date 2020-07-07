#!/bin/csh
#PBS -N fcCDATE_EXPNAME
#PBS -A ACCOUNTNUM
#PBS -q QUEUENAME
#PBS -l select=4:ncpus=32:mpiprocs=32:mem=109GB
#PBS -l walltime=00:JOBMINUTES:00
#PBS -m ae
#PBS -k eod
#   #PBS -V 
#PBS -o CDATE_EXPNAME.out
#PBS -e CDATE_EXPNAME.err

date

#
# Setup environment:
# =============================================
source ./setup.csh

setenv DATE             CDATE
setenv IC_STATE_DIR     ICDIR
setenv FC_LENGTH_HR     FCLENGTHHR
setenv OUT_DT_HR        OUTDTHR
setenv IC_STATE_PREFIX  ICSTATEPREFIX

setenv FC_LENGTH_STR 0_${FC_LENGTH_HR}:00:00
setenv OUT_DT_STR 0_${OUT_DT_HR}:00:00

#
# Time info for namelist, yaml etc:
# =============================================
set yy = `echo ${DATE} | cut -c 1-4`
set mm = `echo ${DATE} | cut -c 5-6`
set dd = `echo ${DATE} | cut -c 7-8`
set hh = `echo ${DATE} | cut -c 9-10`
set FILE_DATE  = ${yy}-${mm}-${dd}_${hh}.00.00
set NAMELIST_DATE  = ${yy}-${mm}-${dd}_${hh}:00:00

#
# Copy/link files: 
# =============================================
cp $FC_NML_DIR/* .
ln -sf $GRAPHINFO_DIR/x1.${MPAS_NCELLS}.graph.info* .
ln -sf ${TOP_BUILD_DIR}/libs/build/${MPASBUILD}/src/core_atmosphere/physics/physics_wrf/files/* .
cp namelist.atmosphere orig_namelist.atmosphere

## link background:
ln -sf ${IC_STATE_DIR}/${IC_STATE_PREFIX}.${FILE_DATE}.nc ./${RST_FILE_PREFIX}.${FILE_DATE}.nc

#
# Revise time info in namelist
# =============================================
cat >! newnamelist << EOF
  /config_start_time /c\
   config_start_time      = '${NAMELIST_DATE}'
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

set OUT_DATE = `${BIN_DIR}/advance_cymdh ${DATE} ${OUT_DT_HR}`
set E_DATE = `${BIN_DIR}/advance_cymdh ${DATE} ${FC_LENGTH_HR}`
while ( ${OUT_DATE} <= ${E_DATE} )
  #
  # Update/add fields to output for DA
  # =============================================
  set yy = `echo ${OUT_DATE} | cut -c 1-4`
  set mm = `echo ${OUT_DATE} | cut -c 5-6`
  set dd = `echo ${OUT_DATE} | cut -c 7-8`
  set hh = `echo ${OUT_DATE} | cut -c 9-10`
  set OUT_FILE_DATE  = ${yy}-${mm}-${dd}_${hh}.00.00

  ## Update MPAS sea surface variables:
  if ( ${UPDATESEA} ) then
     #delete MPASSeaVars from previous GFS ANA
     ncks -a -x -v ${MPASSeaVars} ${RST_FILE_PREFIX}.${OUT_FILE_DATE}.nc ${RST_FILE_PREFIX}.${OUT_FILE_DATE}_nosea.nc

     #append MPASSeaVars from current GFS ANA
     setenv SST_FILE ${GFSSST_DIR}/${OUT_DATE}/x1.${MPAS_NCELLS}.sfc_update.${OUT_FILE_DATE}.nc
     ncks -A -v ${MPASSeaVars} ${SST_FILE} ${RST_FILE_PREFIX}.${OUT_FILE_DATE}_nosea.nc
     mv  ${RST_FILE_PREFIX}.${OUT_FILE_DATE}_nosea.nc  ${RST_FILE_PREFIX}.${OUT_FILE_DATE}.nc
  endif

  ## Add MPASDiagVars to the next cycle bg file
  ncks -A -v ${MPASDiagVars} diag.${OUT_FILE_DATE}.nc ${RST_FILE_PREFIX}.${OUT_FILE_DATE}.nc

  ## move to background name
  mv ${RST_FILE_PREFIX}.${OUT_FILE_DATE}.nc ${FC_FILE_PREFIX}.${OUT_FILE_DATE}.nc

  set OUT_DATE = `$HOME/bin/advance_cymdh ${OUT_DATE} ${OUT_DT_HR}`
  setenv OUT_DATE ${OUT_DATE}
end

date

exit 0
