#!/bin/csh -f
#Convert CISL RDA archived NCEP BUFR files to IODA-v2 format based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

date

# Setup environment
# =================
source config/observations.csh
source config/obsdata.csh
$setObservations ${observations__resource}.defaultBUFRDirectory
$setObservations ${observations__resource}.satwndBUFRDirectory
$setObservations ${observations__resource}.PrepBUFRDirectory
source config/filestructure.csh
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

# ================================================================================================

# write out hourly files for IASI
setenv SPLIThourly "-split"

# flag to de-activate additional QC for conventional
# observations as in GSI
setenv PREPBUFRflag "-noqc"

foreach inst ( ${convertToIODAObservations} )

  if ( ${inst} == satwnd ) then
     setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
     if ( ! -e ${THIS_FILE}) then
        echo "Source file: ${satwndBUFRDirectory}/bufr/${ccyy}/${THIS_FILE}"
        cp -p ${satwndBUFRDirectory}/bufr/${ccyy}/${THIS_FILE} .
     endif
     if ( -e ${GDASObsErrtable} ) then
        ln -sf ${GDASObsErrtable} obs_errtable
     endif
  else if ( ${inst} == prepbufr ) then
     setenv THIS_FILE prepbufr.gdas.${ccyy}${mmdd}.t${hh}z.nr.48h
     if ( ! -e ${THIS_FILE}) then
        echo "Source file: ${PrepBUFRDirectory}/prep48h/${ccyy}/${THIS_FILE}"
        cp -p ${PrepBUFRDirectory}/prep48h/${ccyy}/${THIS_FILE} .
     endif
     # use obs errors embedded in prepbufr file
     if ( -e obs_errtable ) then
        rm -f obs_errtable
     endif
     # use external obs error table
     #if ( -e ${GDASObsErrtable} ) then
     #   ln -sf ${GDASObsErrtable} obs_errtable
     #endif
  else
     # set the specific file to be extracted from the tar file
     setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
     if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
        # cris file name became crisf4 since 2021
        setenv THIS_FILE gdas.${inst}f4.t${hh}z.${ccyy}${mmdd}.bufr
     endif
     set THIS_TAR_FILE = ${defaultBUFRDirectory}/${inst}/${ccyy}/${inst}.${ccyy}${mmdd}.tar.gz
     if ( ${inst} == 'cris' && ${ccyy} >= '2021' ) then
        # cris file name became crisf4 since 2021
        set THIS_TAR_FILE = ${defaultBUFRDirectory}/${inst}/${ccyy}/${inst}f4.${ccyy}${mmdd}.tar.gz
     endif
     if ( ! -e ${THIS_FILE}) then
# tar -x -f /gpfs/fs1/collections/rda/data/ds735.0/gpsro/2018/gpsro.20180415.tar.gz 20180415.gpsro/gdas.gpsro.t00z.20180415.bufr
# tar -x -f ${defaultBUFRDirectory}/${inst}/${ccyy}/${inst}.${ccyy}${mmdd}.tar.gz ${ccyy}${mmdd}.airssev/gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
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
       ln -sf ${CRTMTABLES}/cris-fsr431_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
       ln -sf ${CRTMTABLES}/cris-fsr431_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
     else if ( ${inst} == 'cris' && ${ccyy} < '2021' ) then
       ln -sf ${CRTMTABLES}/cris399_npp.SpcCoeff.bin  ./cris_npp.SpcCoeff.bin
       ln -sf ${CRTMTABLES}/cris399_n20.SpcCoeff.bin  ./cris_n20.SpcCoeff.bin
     else if ( ${inst} == 'mtiasi' ) then
       ln -sf ${CRTMTABLES}/iasi616_metop-a.SpcCoeff.bin  ./iasi_metop-a.SpcCoeff.bin
       ln -sf ${CRTMTABLES}/iasi616_metop-b.SpcCoeff.bin  ./iasi_metop-b.SpcCoeff.bin
       ln -sf ${CRTMTABLES}/iasi616_metop-c.SpcCoeff.bin  ./iasi_metop-c.SpcCoeff.bin
     endif

     # Run the obs2ioda executable to convert files from BUFR to IODA-v2
     # ==================
     rm ./${obs2iodaEXEC}
     ln -sfv ${obs2iodaBuildDir}/${obs2iodaEXEC} ./
     if ( ${inst} == 'mtiasi' ) then
       ./${obs2iodaEXEC} ${SPLIThourly} ${THIS_FILE} >&! log_${inst}
     else if ( ${inst} == 'prepbufr' ) then
       ./${obs2iodaEXEC} ${PREPBUFRflag} ${THIS_FILE} >&! log_${inst}
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

if ( "${convertToIODAObservations}" =~ *"prepbufr"* || "${convertToIODAObservations}" =~ *"satwnd"* ) then
  # Run the ioda-upgrade executable to upgrade to get string station_id and string variable_names
  # ==================
  source ${ConfigDir}/environmentForJedi.csh ${BuildCompiler}
  rm ./${iodaupgradeEXEC}
  ln -sfv ${iodaupgradeBuildDir}/${iodaupgradeEXEC} ./
  set types = ( aircraft ascat profiler satwind sfc sondes satwnd )
  foreach ty ( ${types} )
    if ( -f ${ty}_obs_${thisValidDate}.h5 ) then
      set ty_obs = ${ty}_obs_${thisValidDate}.h5
      set ty_obs_base = `echo "$ty_obs" | cut -d'.' -f1`
      ./${iodaupgradeEXEC} ${ty_obs} ${ty_obs_base}_tmp.h5 >&! log_${ty}_upgrade
      rm -rf $ty_obs
      mv ${ty_obs_base}_tmp.h5 $ty_obs
      # Check status
      # ============
      grep "Success!" log_${ty}_upgrade
      if ( $status != 0 ) then
        echo "ERROR in $0 : ioda-upgrade failed for $ty" > ./FAIL-${ty}_upgrade
        exit 1
      endif
    endif
  end
endif

# Remove BURF/PrepBUFR files
foreach gdasfile ( *"gdas"* )
  rm -rf $gdasfile
end

date

exit 0
