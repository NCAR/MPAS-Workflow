#!/bin/csh -f

# (C) Copyright 2023 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

date

# Process arguments
# =================
## args
# ArgMember: int, ensemble member [>= 1]
set ArgMember = "$1"

# ArgDT: int, valid forecast length beyond CYLC_TASK_CYCLE_POINT in hours
set ArgDT = "$2"

# ArgStateType: str, FC if this is a forecasted state, activates ArgDT in directory naming
set ArgStateType = "$3"

# ArgAppType: str, type of application being verified (hofx or variational)
set ArgAppType = "$4"

## arg checks
set test = `echo $ArgMember | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be an integer" > ./FAIL
  exit 1
endif
if ( $ArgMember < 1 ) then
  echo "ERROR in $0 : ArgMember ($ArgMember) must be > 0" > ./FAIL
  exit 1
endif

set test = `echo $ArgDT | grep '^[0-9]*$'`
set isNotInt = ($status)
if ( $isNotInt ) then
  echo "ERROR in $0 : ArgDT must be an integer, not $ArgDT"
  exit 1
endif

if ("$ArgAppType" != hofx && "$ArgAppType" != variational) then
  echo "$0 (ERROR): ArgAppType must be hofx or variational, not $ArgAppType"
  exit 1
endif

# Setup environment
# =================
source config/auto/benchmark.csh
source config/auto/experiment.csh
source config/auto/verifyobs.csh
source config/tools.csh
module load nccmp
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./bin/getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
echo "WorkDir = ${self_WorkDir}"

set benchmark_WorkDir = $WorkDirsBenchmarkTEMPLATE[$ArgMember]

# ================================================================================================

# Compare obs-space verification statistics

set CompareDir = ${self_WorkDir}/${ObsCompareDir}
mkdir -p ${CompareDir}
cd ${CompareDir}

set ObsTypeList = ( \
  aircraft \
  amsua_aqua \
  amsua_metop-a \
  amsua_n15 \
  amsua_n18 \
  amsua_n19 \
  gnssrorefncep \
  satwind \
  sfc \
  sondes \
)

rm compare.txt
rm ${ExperimentDirectory}/verifyobs_differences_found.txt
foreach obstype ($ObsTypeList)
  set self_StatisticsFile = "${self_WorkDir}/${ObsDiagnosticsDir}/stats_${ArgAppType}_${obstype}.h5"
  set benchmark_StatisticsFile = "${benchmark_WorkDir}/${ObsDiagnosticsDir}/stats_${ArgAppType}_${obstype}.h5"

  echo "nccmp -dfFmSN ${self_StatisticsFile} ${benchmark_StatisticsFile}" | tee -a compare.txt
  nccmp -dfFmSN ${self_StatisticsFile} ${benchmark_StatisticsFile} | tee -a compare.txt

  # nccmp returns 0 if the files are identical. Log non-zero returns in a file for human review.
  if ($status != 0) then
    echo "$self_StatisticsFile" >> ${ExperimentDirectory}/verifyobs_differences_found.txt
    echo "--> ${CompareDir}/diffStatistics.h5" >> ${ExperimentDirectory}/verifyobs_differences_found.txt
    ncdiff -O ${self_StatisticsFile} ${benchmark_StatisticsFile} diffStatistics_${obstype}.h5
  endif
end

touch BENCHMARK_COMPARE_COMPLETE

cd -

date

exit
