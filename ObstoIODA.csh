#!/bin/csh -f
#Convert CISL RDA archived NCEP BUFR files to IODA-v2 format based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

date

# Process arguments
# =================
## args
# OBTYPES: observation types to pre-process
set OBTYPES = "$1"

# Setup environment
# =================
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/modeldata.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set ccyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set WorkDir = ${ObsDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# static variables
setenv OBS_ERRTABLE /glade/u/home/hclin/proj/ioda/obs_errtable
setenv SPC_COEFF_DIR /glade/u/home/hclin/proj/ioda/SpcCoeff

# write out hourly files for IASI
setenv OPTIONS "-split"

foreach inst ( ${OBTYPES} )

  if ( ${inst} == satwnd ) then
     setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
     if ( ! -e ${THIS_FILE}) then
        echo "Source file: ${RDAdataDir}/ds351.0/bufr/${ccyy}/${THIS_FILE}"
        cp -p ${RDAdataDir}/ds351.0/bufr/${ccyy}/${THIS_FILE} .
     endif
     if ( -e ${OBS_ERRTABLE} ) then
        ln -sf ${OBS_ERRTABLE} obs_errtable
     endif
  else if ( ${inst} == prepbufr ) then
     setenv THIS_FILE prepbufr.gdas.${ccyy}${mmdd}.t${hh}z.nr.48h
     if ( ! -e ${THIS_FILE}) then
        echo "Source file: ${RDAdataDir}/ds337.0/prep48h/${ccyy}/${THIS_FILE}"
        cp -p ${RDAdataDir}/ds337.0/prep48h/${ccyy}/${THIS_FILE} .
     endif
     # use obs errors embedded in prepbufr file
     if ( -e obs_errtable ) then
        rm -f obs_errtable
     endif
     # use external obs error table
     #if ( -e ${OBS_ERRTABLE} ) then
     #   ln -sf ${OBS_ERRTABLE} obs_errtable
     #endif
  else
     # set the specific file to be extracted from the tar file
     setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
     if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
        # cris file name became crisf4 since 2021
        setenv THIS_FILE gdas.${inst}f4.t${hh}z.${ccyy}${mmdd}.bufr
     endif
     set THIS_TAR_FILE = ${RDAdataDir}/ds735.0/${inst}/${ccyy}/${inst}.${ccyy}${mmdd}.tar.gz
     if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
        # cris file name became crisf4 since 2021
        set THIS_TAR_FILE = ${RDAdataDir}/ds735.0/${inst}/${ccyy}/${inst}f4.${ccyy}${mmdd}.tar.gz
     endif
     if ( ! -e ${THIS_FILE}) then
# tar -x -f /gpfs/fs1/collections/rda/data/ds735.0/gpsro/2018/gpsro.20180415.tar.gz 20180415.gpsro/gdas.gpsro.t00z.20180415.bufr
# tar -x -f ${RDAdataDir}/ds735.0/${inst}/${ccyy}/${inst}.${ccyy}${mmdd}.tar.gz ${ccyy}${mmdd}.airssev/gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
# mv ${ccyy}${mmdd}.airssev/gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr .
        # some tar files contain sub-directory
        set THIS_TAR_DIR = ${ccyy}${mmdd}.${inst}
        tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}
        if ( $status == 0 ) then
           echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}"
           set got_file = true
           set SUB_DIR = true
        else #if ( $status != 0 ) then
           # try no sub-directory
           tar -x -f ${THIS_TAR_FILE} ${THIS_FILE}
           if ( $status == 0 ) then
              echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_FILE}"
              set SUB_DIR = false
              set got_file = true
           else
              set got_file = false
           endif
        endif
        if ( ${got_file} == false && ${inst} == airsev ) then
           #if airs, try again with another dir name
           #typo in the archived directory name
           set THIS_TAR_DIR = ${ccyy}${mmdd}.airssev
           tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}
           if ( $status == 0 ) then
              set SUB_DIR = true
              echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}"
              set got_file = true
           endif
        endif
        if ( ${got_file} == true ) then
           if (  ${SUB_DIR} == true ) then
              mv ${THIS_TAR_DIR}/${THIS_FILE} .
              rmdir ${THIS_TAR_DIR}
           endif
        endif
     endif # others
  endif # satwnd, prepbufr or others

  if ( -e ${THIS_FILE} ) then
     echo "Running ${obs2iodaEXEC} for ${inst} ..."
     # link SpcCoeff files for converting IR radiances to brightness temperature
     if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
       ln -sf ${SPC_COEFF_DIR}/cris-fsr431_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
       ln -sf ${SPC_COEFF_DIR}/cris-fsr431_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
     else if ( ${inst} == 'cris' && ${ccyy} < '2021' ) then
       ln -sf ${SPC_COEFF_DIR}/cris399_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
       ln -sf ${SPC_COEFF_DIR}/cris399_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
     else if ( ${inst} == 'mtiasi' ) then
       ln -sf ${SPC_COEFF_DIR}/iasi616_metop-a.SpcCoeff.bin  ./iasi_metop-a.SpcCoeff.bin
       ln -sf ${SPC_COEFF_DIR}/iasi616_metop-b.SpcCoeff.bin  ./iasi_metop-b.SpcCoeff.bin
       ln -sf ${SPC_COEFF_DIR}/iasi616_metop-c.SpcCoeff.bin  ./iasi_metop-c.SpcCoeff.bin
     endif

     # Run the obs2ioda executable to convert files from BUFR to IODA-v2
     # ==================
     rm ./${obs2iodaEXEC}
     ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXEC} ./
     if ( ${inst} == 'mtiasi' ) then
       ./${obs2iodaEXEC} ${OPTIONS} ${THIS_FILE} >&! log_${inst}
     else
       ./${obs2iodaEXEC} ${THIS_FILE} >&! log_${inst}
     endif
     # Check status
     # ============
     grep "all done!" log_${inst}
     if ( $status != 0 ) then
       echo "ERROR in $0 : Pre-processing observations to IODA-v2 failed" > ./FAIL-converter
       exit 1
     endif
  endif

end # inst loop

if ( "${OBTYPES}" =~ *"prepbufr"* ) then
  # Run the ioda-upgrade executable to upgrade to get string station_id and string variable_names
  # ==================
  source ${ConfigDir}/environmentForJedi.csh ${BuildCompiler}
  rm ./${iodaupgradeEXEC}
  ln -sfv ${iodaupgradeBuildDir}/${iodaupgradeEXEC} ./

  set prepbufr_types = ( aircraft ascat profiler satwind satwnd sfc sondes )
  foreach pty ( ${prepbufr_types} )
   if ( -f ${pty}_obs_${thisValidDate}.h5 ) then
     set preptype = ${pty}_obs_${thisValidDate}.h5
     set preptype_base = `echo "$preptype" | cut -d'.' -f1`
     ./${iodaupgradeEXEC} ${preptype} ${preptype_base}_ok.h5 >&! log_${pty}
     rm -rf $preptype
     mv ${preptype_base}_ok.h5 $preptype
   endif
  end
  # Check status
  # ============
  grep "all done!" log_${inst}
  if ( $status != 0 ) then
   echo "ERROR in $0 : ioda-upgrade failed" > ./FAIL-upgrader
   exit 1
  endif
endif

# Remove BURF/PrepBUFR files
foreach gdasfile ( *"gdas"* )
  rm -rf $gdasfile
end

date

exit 0
