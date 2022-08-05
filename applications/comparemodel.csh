#!/bin/csh -f

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

# Setup environment
# =================
source config/auto/benchmark.csh
source config/auto/verifymodel.csh
source config/tools.csh
module load nccmp
set yymmdd = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 1-8`
set hh = `echo ${CYLC_TASK_CYCLE_POINT} | cut -c 10-11`
set thisCycleDate = ${yymmdd}${hh}
set thisValidDate = `$advanceCYMDH ${thisCycleDate} ${ArgDT}`
source ./getCycleVars.csh

# templated work directory
set self_WorkDir = $WorkDirsTEMPLATE[$ArgMember]
if ($ArgDT > 0 || "$ArgStateType" =~ *"FC") then
  set self_WorkDir = $self_WorkDir/${ArgDT}hr
endif
echo "WorkDir = ${self_WorkDir}"

set benchmark_WorkDir = $WorkDirsBenchmarkTEMPLATE[$ArgMember]

# ================================================================================================

# collect model-space diagnostic statistics into DB files
# =======================================================
set CompareDir = ${self_WorkDir}/${ModelCompareDir}
mkdir -p ${CompareDir}
cd ${CompareDir}

rm ${ExperimentDirectory}/verifymodel_differences_found.txt

#(1) Compare self_bgFile to benchmark_bgFile
set self_bgFile = ${self_WorkDir}/${ModelDiagnosticsDir}/../restart.$thisMPASFileDate.nc
set benchmark_bgFile = ${benchmark_WorkDir}/${ModelDiagnosticsDir}/../restart.$thisMPASFileDate.nc
echo "nccmp -dfFmqS ${self_bgFile} ${benchmark_bgFile}" | tee compare.txt
nccmp -dfFmqS ${self_bgFile} ${benchmark_bgFile} | tee -a compare.txt

# nccmp returns 0 if the files are identical. Log non-zero returns in a file for human review.
if ($status != 0) then
  echo "$self_bgFile" >> ${ExperimentDirectory}/verifymodel_differences_found.txt
  echo "--> ${CompareDir}/diffState.nc" >> ${ExperimentDirectory}/verifymodel_differences_found.txt
  ncdiff -O ${self_bgFile} ${benchmark_bgFile} diffState.nc
endif

#(2) Compare model-space verification statistics
set self_StatisticsFile = "${self_WorkDir}/${ModelDiagnosticsDir}/stats_mpas.h5"
set benchmark_StatisticsFile = "${benchmark_WorkDir}/${ModelDiagnosticsDir}/stats_mpas.h5"

echo "nccmp -dfFmSN ${self_StatisticsFile} ${benchmark_StatisticsFile}" | tee -a compare.txt
nccmp -dfFmSN ${self_StatisticsFile} ${benchmark_StatisticsFile} | tee -a compare.txt
#echo "${self_StatisticsFile} - nccmp returned $status"
if ($status != 0) then
  echo "$self_StatisticsFile" >> ${ExperimentDirectory}/verifymodel_differences_found.txt
  echo "--> ${CompareDir}/diffStatistics.nc" >> ${ExperimentDirectory}/verifymodel_differences_found.txt
  ncdiff -O ${self_StatisticsFile} ${benchmark_StatisticsFile} diffStatistics.h5
endif

touch BENCHMARK_COMPARE_COMPLETE

cd -

date

exit
