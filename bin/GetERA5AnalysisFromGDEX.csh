#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# Get GFS analysis (0-h forecast) for cold start initial conditions

# Process arguments
# =================
## args
# ArgDT: int, valid time offset beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$1"

# ArgWorkDir: my location
set ArgWorkDir = "$2"

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

date

# Setup environment
# =================
source config/auto/build.csh
source config/auto/experiment.csh
source config/tools.csh
set ccyymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${ccyymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
set prevValidDate = `$advanceCYMDH ${thisCycleDate} -6`

source ./bin/getCycleVars.csh

set cyyyy = `echo ${thisValidDate} | cut -c1-4`
set cmm   = `echo ${thisValidDate} | cut -c5-6`
set cdd   = `echo ${thisValidDate} | cut -c7-8`
set chh   = `echo ${thisValidDate} | cut -c9-10`
set datestr = "${cyyyy}-${cmm}-${cdd}_${chh}"

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
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

echo "Getting ERA5 analysis from GDEX"


# Link ECMWF coefficients
ln -sf ${ModelConfigDir}/initic/ecmwf_coeffs ./ecmwf_coeffs

# Convert ERA5 NetCDF to WPS intermediate
setenv myCommand `$era5_to_int ${datestr}`
echo "$myCommand"
${myCommand}

# Build ERA5 intermediate filename (YYYY-MM-DD_HH)
set era5file = ERA5:${datestr}

# Check that ERA5 intermediate file exists
if ( ! -e ${era5file} ) then
   echo "${era5file} not found -- exiting"
   exit 1
endif

echo "ERA5 intermediate file created successfully: ${era5file}"

date

touch GETSUCCESS

exit 0
