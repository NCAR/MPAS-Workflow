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

source ./bin/getCycleVars.csh

set ccyymmdd = `echo ${thisValidDate} | cut -c 1-8`
set hh = `echo ${thisValidDate} | cut -c 9-10`

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@'`

echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

# Process the date for each member
set nmem = 30          # Adjust the number of members

set fc_range = 0      # Forecast range in hours
set formatted_fc_range = `printf "%03d" $fc_range`

# Loop through each ensemble member
foreach i (`seq 1 $nmem`)
    set mem = `printf "%02d" $i`
    set WrkDir = "${WorkDir}/${mem}"
    #set WrkDir = "/glade/campaign/mmm/parc/zhuming/pandac_common/GEFS/GEFS_grib/$ccyymmdd$hh/$mem"

    mkdir -p $WrkDir

    echo "Processing member ${mem}..."
    echo "WrkDir = ${WrkDir}"

    # Set the URL for GEFS data
    set gefsa_url = "s3://noaa-gefs-pds/gefs.$ccyymmdd/$hh/atmos/pgrb2ap5"
    set gefsb_url = "s3://noaa-gefs-pds/gefs.$ccyymmdd/$hh/atmos/pgrb2bp5"
    echo "gefs_url = ${gefsa_url}, ${gefsb_url}"

    # Define filenames
    set pgrb2a = "gep$mem.t${hh}z.pgrb2a.0p50.f${formatted_fc_range}"
    set pgrb2b = "gep$mem.t${hh}z.pgrb2b.0p50.f${formatted_fc_range}"
    #set pgrb2a = "gep$mem.t${hh}z.pgrb2a.0p50.f`printf "%03d" $fc_range`"
    #set pgrb2b = "gep$mem.t${hh}z.pgrb2b.0p50.f`printf "%03d" $fc_range`"
    echo "pgrb = ${pgrb2a}, ${pgrb2b}"

    # Check if the files exist before attempting to download
    set file_a_exists = `/glade/u/home/liuz/.local/bin/aws s3 ls $gefsa_url/$pgrb2a --no-sign-request`
    set file_b_exists = `/glade/u/home/liuz/.local/bin/aws s3 ls $gefsb_url/$pgrb2b --no-sign-request`

    if ("$file_a_exists" != "") then
        echo "Downloading $pgrb2a..."
        /glade/u/home/liuz/.local/bin/aws s3 cp --no-sign-request $gefsa_url/$pgrb2a $WrkDir
    else
        echo "$pgrb2a does not exist, skipping."
    endif

    if ("$file_b_exists" != "") then
        echo "Downloading $pgrb2b..."
        /glade/u/home/liuz/.local/bin/aws s3 cp --no-sign-request $gefsb_url/$pgrb2b $WrkDir
    else
        echo "$pgrb2b does not exist, skipping."
    endif

    # Download files if they exist
    #if (/glade/u/home/liuz/.local/bin/aws s3 ls $gefsa_url/$pgrb2a --no-sign-request) then
    #    echo "Downloading $pgrb2a..."
    #     /glade/u/home/liuz/.local/bin/aws s3 cp --no-sign-request $gefsa_url/$pgrb2a $WrkDir
    # else
    #echo "$pgrb2a does not exist, skipping."
    # endif

    #if (/glade/u/home/liuz/.local/bin/aws s3 ls $gefsb_url/$pgrb2b --no-sign-request) then
    #    echo "Downloading $pgrb2b..."
    #i   /glade/u/home/liuz/.local/bin/aws s3 cp --no-sign-request $gefsb_url/$pgrb2b $WrkDir
    # else
    #     echo "$pgrb2b does not exist, skipping."
    # endif

    # Combine files if both exist
    #if ("$file_a_exists" != "" && "$file_b_exists" != "") then
    if (-e ${WrkDir}/$pgrb2a && -e ${WrkDir}/$pgrb2b) then
        cat ${WrkDir}/$pgrb2a ${WrkDir}/$pgrb2b > ${WrkDir}/gep$mem.t${hh}z.pgrb2ab.0p50.f${formatted_fc_range}
	# Remove the individual pgrb2a and pgrb2b files after combining
	rm -f ${WrkDir}/$pgrb2a ${WrkDir}/$pgrb2b
    endif

    # Link GRIB files
    cd ${WrkDir}
    set linkWPS = link_grib.csh
    ln -sfv ${WPSBuildDir}/${linkWPS} .
    rm -rf GRIBFILE.*

    #set gribFile = gep$mem.t${hh}z.pgrb2ab.0p50.f${formatted_fc_range}
    #./${linkWPS} $gribFile
    ./link_grib.csh gep$mem.t${hh}z.pgrb2ab.0p50.f${formatted_fc_range}

end

# ================================================================================================

if ( -e GETSUCCESS ) then
  echo "$0 (INFO): GETSUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the output files is desired, delete GETSUCCESS"

  date

  exit 0
endif

# ================================================================================================
