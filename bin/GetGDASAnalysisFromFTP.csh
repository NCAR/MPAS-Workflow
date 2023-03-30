#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Get GFS analysis (0-h forecast) for cold start initial conditions

date

# Setup environment
# =================
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = ${thisCycleDate}

source ./bin/getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`

# static work directory
set Campaign = /glade/campaign/mmm/parc/ivette/pandac
set WorkDir = ${Campaign}/GDASana/${thisValidDate}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# ================================================================================================

if ( -e GETSUCCESS ) then
  echo "$0 (INFO): GETSUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the output files is desired, delete GETSUCCESS"

  date

  exit 0
endif

# ================================================================================================

set fhour = 000

echo "Getting GDAS atm and sfc analyses from the NCEP FTP"
# url for GDAS data
set gdas_ftp = https://www.ftp.ncep.noaa.gov/data/nccf/com/gfs/prod/gdas.${ccyymmdd}/${hh}/atmos
set gdasAnaInfix = (atm sfc sfluxgrb)

foreach anaInfix ($gdasAnaInfix)
  set gdas = gdas.t${hh}z.${anaInfix}f${fhour}
  if ( ${anaInfix} == sfluxgrb ) then
     set gdasfile = ${gdas}.grib2
  else
     set gdasfile = ${gdas}.nc
  endif
  # check if the GDAS analyses are available
  if ( ! -e ${gdasfile}) then
    set gdasfile_ftp = ${gdas_ftp}/${gdasfile}
    wget -S --spider $gdasfile_ftp >&! log_check_gdasfile_ftp_f000
    grep "HTTP/1.1 200 OK" log_check_gdasfile_ftp_f000
    # if the file exists then download it
    # otherwise, exit with failure
    if ( $status == 0 ) then
     echo "Downloading $gdasfile_ftp ..."
     wget -r -np -nd $gdasfile_ftp
    else
     echo "$gdasfile_ftp not available yet -- exiting"
     exit 1
    endif
  endif
end

date

touch GETSUCCESS

exit 0
