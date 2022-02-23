#!/bin/csh -f
# Copy and untar CISL RDA archived NCEP BUFR files based on Jamie Bresch (NCAR/MMM) script rda_obs2ioda.csh

date

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

# ================================================================================================

# static variables
setenv OBS_ERRTABLE /glade/u/home/hclin/proj/ioda/obs_errtable

foreach inst ( ${preprocessObsList} )

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
end

date

exit 0
