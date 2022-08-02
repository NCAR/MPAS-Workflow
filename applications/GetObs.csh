#!/bin/csh -f
# Get observations for a cold start experiment
# from the NCEP FTP BUFR/PrepBUFR files or CISL RDA archived NCEP BUFR files

date

# Setup environment
# =================
source config/auto/workflow.csh
source config/auto/observations.csh
source config/experiment.csh
source config/auto/build.csh
set yyyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set ccyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yyyymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set WorkDir = ${ObsDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

set defaultBUFRDirectory = /gpfs/fs1/collections/rda/data/ds735.0
set satwndBUFRDirectory = /gpfs/fs1/collections/rda/data/ds351.0
set PrepBUFRDirectory = /gpfs/fs1/collections/rda/data/ds337.0

foreach inst ( ${convertToIODAObservations} )
  if ( "${observations__resource}" == "GladeRDAOnline" ) then
    echo "Getting ${inst} from RDA"
    # for satwnd observations
    if ( ${inst} == satwnd ) then
       setenv THIS_FILE gdas.${inst}.t${hh}z.${ccyy}${mmdd}.bufr
       if ( ! -e ${THIS_FILE}) then
          echo "Source file: ${satwndBUFRDirectory}/bufr/${ccyy}/${THIS_FILE}"
          cp -p ${satwndBUFRDirectory}/bufr/${ccyy}/${THIS_FILE} .
       endif
       # link the GDAS observation error table
       if ( -e ${GDASObsErrtable} ) then
          ln -sf ${GDASObsErrtable} obs_errtable
       else
          echo "ERROR: ${GDASObsErrtable} does NOT exist" > ./FAIL
          exit 1
       endif
    # for prepbufr observations
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
    # for all other observations
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
       # if the observation file does not exist, untar it
       # whether in the sub-directory or current directory
       if ( ! -e ${THIS_FILE}) then
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
          # if the file was not untarred and if airs observations
          if ( ${got_file} == false && ${inst} == airsev ) then
             # try again with another dir name
             # typo in the archived directory name
             set THIS_TAR_DIR = ${ccyy}${mmdd}.airssev
             tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}
             if ( $status == 0 ) then
                set SUB_DIR = true
                echo "Source file: tar -x -f ${THIS_TAR_FILE} ${THIS_TAR_DIR}/${THIS_FILE}"
                set got_file = true
             endif
          endif
          # if the file was untarred and the sub-directory exists,
          # remove the sub-directory
          if ( ${got_file} == true ) then
             if (  ${SUB_DIR} == true ) then
                mv ${THIS_TAR_DIR}/${THIS_FILE} .
                rmdir ${THIS_TAR_DIR}
             endif
          endif
       endif # others
    endif # satwnd, prepbufr or others
  else if ( "${observations__resource}" == "NCEPFTPOnline" ) then
    echo "Getting ${inst} from the NCEP FTP"
    # url for GDAS data
    set gdas_ftp = https://ftpprd.ncep.noaa.gov/data/nccf/com/obsproc/prod/gdas.${yyyymmdd}
    # set name for the observation type
    if ( ${inst} == prepbufr ) then
      set THIS_FILE = gdas.t${hh}z.${inst}.nr
    else if ( ${inst} == gpsro ) then
      set THIS_FILE = gdas.t${hh}z.${inst}.tm00.bufr_d.nr
    else
      set THIS_FILE = gdas.t${hh}z.${inst}.tm00.bufr_d
    endif

    # check if the observation file is available
    if ( ! -e ${THIS_FILE}) then
      set ftp_file = ${gdas_ftp}/${THIS_FILE}
      wget -S --spider $ftp_file >&! log_check_${inst}
      grep "HTTP/1.1 200 OK" log_check_${inst}
      # if the file exists then download it
      # otherwise, exit with failure
      if ( $status == 0 ) then
       echo "Downloading $ftp_file ..."
       wget -r -np -nd $ftp_file
      else
       echo "$ftp_file not available yet -- exiting"
       exit 1
      endif
    endif
  else if ( "${observations__resource}" == "PANDACArchive" ) then
    echo "$0 (INFO): ${observations__resource} must be stored locally and fully described in the YAML"
    echo "$0 (INFO): File retrieval is not supported; exiting with success"
    exit 0
  else
    echo "$0 (ERROR): ${observations__resource} is not supported; exiting with failure"
    exit 1
  endif
end

date

exit 0
