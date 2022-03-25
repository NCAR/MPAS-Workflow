#!/bin/csh -f
# Get GDAS satellite bias correction coefficients for a cold start experiment
# from the NCEP FTP BUFR/PrepBUFR files or CISL RDA archived NCEP BUFR files

date

# Setup environment
# =================
source config/observations.csh
source config/filestructure.csh
source config/builds.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set yyyy = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c1-4`
set mmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c5-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = ${thisCycleDate}
source ./getCycleVars.csh

# templated work directory
set WorkDir = ${satelliteBiasDir}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

if ( ${satelliteBiasSource} == "BiasCoefffromRDAOnline" ) then
  echo "Getting bias coefficients from RDA"
  set coeffList = ( abias abiaspc )
  foreach coeff ( ${coeffList} )
    # set name for bias coefficient file on RDA    
    set FILE = gdas.${coeff}.t${hh}z.${yymmdd}.txt
    set coeffRDADirectory = /gpfs/fs1/collections/rda/data/ds735.0/${coeff}/${yyyy}
    set tar_file = ${coeffRDADirectory}/${coeff}.${yymmdd}.tar.gz
    set tmp_tar_dir = ${yymmdd}.${coeff}
    # untar bias coefficients files  
    if ( ! -e ${FILE}) then
      echo "Untar file: ${FILE}"
      tar -x -f ${tar_file}
      if ( $status == 0 ) then
         echo "Source file: tar -x -f ${tar_file} ${tmp_tar_dir}/${FILE}"
         set got_file = true
         set SUB_DIR = true
      else #if ( $status != 0 ) then
         # try no sub-directory
         tar -x -f ${tar_file} ${FILE}
         if ( $status == 0 ) then
            echo "Source file: tar -x -f  ${tar_file} ${tmp_tar_dir}/${FILE}}"
            set SUB_DIR = false
            set got_file = true
         else
            set got_file = false
         endif
       endif   
    endif
    # Move file to WorkDir and remove temporary folder
    # if the file was untarred and the sub-directory exists
    if ( ${got_file} == true ) then
       if (  ${SUB_DIR} == true ) then
          mv ${tmp_tar_dir}/${FILE} .
          rmdir ${tmp_tar_dir}
       endif
    endif
    # Create links to pre-defined names
    if ( ${coeff} == abias ) then
      ln -sfv ${FILE} ./satbias_crtm_in
    else if ( ${coeff} == abiaspc ) then
      ln -sfv ${FILE} ./satbias_crtm_pc
    endif
  end
else if ( ${satelliteBiasSource} == "BiasCoefffromNCEPFTPOnline" ) then
  echo "Getting bias coefficients from the NCEP FTP"
  set coeffList = ( abias abias_pc )
  foreach coeff ( ${coeffList} )  
    # url for GDAS data
    set gdas_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gdas.${yymmdd}/${hh}/atmos
    # set name for bias coefficient file on NCEP FTP
    set FILE = gdas.t${hh}z.${coeff}
    # check if the coefficients file is available
    if ( ! -e ${coeff}) then
      set coeff_ftp_file = ${gdas_ftp}/${FILE}
      wget -S --spider $coeff_ftp_file >&! log_check_${coeff}
      grep "HTTP/1.1 200 OK" log_check_${coeff}
      # if the file exists then download it
      # otherwise, exit with failure
      if ( $status == 0 ) then
       echo "Downloading $coeff_ftp_file ..."
       wget -r -np -nd $coeff_ftp_file
      else
       echo "$coeff_ftp_file not available yet -- exiting"
       exit 1
      endif
    endif
    # Create links to pre-defined names
    if ( ${coeff} == abias ) then
      ln -sfv ${FILE} ./satbias_crtm_in
    else if ( ${coeff} == abias_pc ) then
      ln -sfv ${FILE} ./satbias_crtm_pc
    endif
  end
endif

date

exit 0
