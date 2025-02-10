#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

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
source config/environmentJEDI.csh
source config/auto/build.csh
source config/auto/experiment.csh
source config/auto/externalanalyses.csh
source config/auto/model.csh
source config/tools.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

set WorkDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisValidDate}}@'${thisValidDate}'@' \
  `
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}

#=======================================
if ( -e UNGRIBSUCCESS ) then
  echo "$0 (INFO): UNGRIBSUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the output files is desired, delete UNGRIBSUCCESS"

  date

  exit 0
endif

# ================================================================================================
# Process the data for each member
set nmem = 30          # Adjust the number of members

#set fc_range = 0      # Forecast range in hours
#set formatted_fc_range = `printf "%03d" $fc_range`

# Loop through each ensemble member
foreach i (`seq 1 $nmem`)
    set mem = `printf "%02d" $i`
    set WrkDir = "${WorkDir}/${mem}"

    #mkdir -p $WrkDir

    echo "Ungrib member ${mem}..."
    echo "WrkDir = ${WrkDir}"
    cd $WrkDir


    ## link Vtable file
    ln -sfv ${externalanalyses__Vtable} Vtable

    ## copy/modify dynamic namelist
    rm -f ${NamelistFileWPS}
    cp -v $ModelConfigDir/initic/${NamelistFileWPS} .
    sed -i 's@startTime@'${thisMPASNamelistDate}'@' $NamelistFileWPS
    #sed -i 's@{{UngribPrefix}}@'${externalanalyses__UngribPrefix}'@' $NamelistFileWPS
    sed -i 's@{{UngribPrefix}}@'GEFS'@' $NamelistFileWPS

    # Run the executable
    rm -f ./${ungribEXE}
    ln -sfv ${WPSBuildDir}/${ungribEXE} ./
    ./${ungribEXE}

    # Check status
    grep "Successful completion of program ${ungribEXE}" ungrib.log
    if ( $status != 0 ) then
      echo "ERROR in $0 : Ungrib failed" > ./FAIL
      exit 1
    endif

end

#=======================================
date

touch UNGRIBSUCCESS

exit 0

