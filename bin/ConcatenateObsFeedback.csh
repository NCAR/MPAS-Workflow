#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
## args

# ArgAppType: str, hofx, variational
set ArgAppType = "$1"

# ArgWorkDir: str, where to run
set ArgWorkDir = "$2"

# ArgDAMem: str, /mean, /mem{:03d}, or ""
set ArgDAMem = "$3"

# Setup environment
# =================
source config/environmentNPL.csh
source config/tools.csh
source config/auto/experiment.csh
source config/auto/observations.csh
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}

set cycleDir = ${ExperimentDirectory}/`echo "$ArgWorkDir" \
  | sed 's@{{thisCycleDate}}@'${thisCycleDate}'@' \
  `
set WorkDir = ${cycleDir}/${OutDBDir}${ArgDAMem}
echo "WorkDir = ${WorkDir}"
mkdir -p ${WorkDir}
cd ${WorkDir}
# ================================================================================================

if ("$ArgAppType" == hofx) then
  set AppCategory = hofx
else
  set AppCategory = da
endif

# Sanity check
set fileCount = `ls -1 *0*.nc4 | wc -l`
if ( $fileCount == 0 ) then
  echo "$0 (INFO): NO files to concatenate, exiting with success"
  echo "$0 (INFO): if concatenating files is desired, verify that geoval and ydiags file exist"
  date
  exit 0
endif

if ( -e CONCATENATESUCCESS ) then
  echo "$0 (INFO): CONCATENATESUCCESS file already exists, exiting with success"
  echo "$0 (INFO): if regenerating the concatenated files is desired, delete CONCATENATESUCCESS"
  date
  exit 0
endif

# Execute python script
set pyScript = "concatenate"
setenv myCommand `$concatenate ${AppCategory} ${WorkDir}`
echo "$myCommand"
${myCommand}

# Check if the concatenated files were created successfully
grep "Finished __main__ successfully" log.${pyScript}
if ( $status != 0 ) then
  echo "ERROR in $0 : ${pyScript} failed" > ./FAIL
  exit 1
endif

# Remove each processor feedback files
rm -rf ${geoPrefix}*0*.nc4
rm -rf ${diagPrefix}*0*.nc4

touch CONCATENATESUCCESS

date

exit 0
