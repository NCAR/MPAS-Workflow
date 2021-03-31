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

# ArgNMembers: int, set > 1 to activate ensemble spread diagnostics
set ArgNMembers = "$4"

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
source config/experiment.csh
source config/filestructure.csh
source config/tools.csh
source config/verification.csh
source config/environment.csh
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

# other templated variables
set self_jediAppName = jediAppNameTEMPLATE

# ================================================================================================

# collect obs-space diagnostic statistics into DB files
# =====================================================
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
  gnssroref \
  satwind \
  sfc \
  sondes \
)

rm compare.txt
foreach obstype ($ObsTypeList)
  set self_StatisticsFile = "${self_WorkDir}/${ObsDiagnosticsDir}/stats_${self_jediAppName}_${obstype}.nc"
  set benchmark_StatisticsFile = "${benchmark_WorkDir}/${ObsDiagnosticsDir}/stats_${self_jediAppName}_${obstype}.nc"

  echo "nccmp -dfFmSN -v Count,Mean,RMS,STD ${self_StatisticsFile} ${benchmark_StatisticsFile}" | tee -a compare.txt
  nccmp -d -N -S -v Count,Mean,RMS,STD ${self_StatisticsFile} ${benchmark_StatisticsFile} | tee -a compare.txt

  # nccmp returns 0 if the files are identical. Log non-zero returns in a file for human review.
  if ($status != 0) then
    echo "$self_StatisticsFile" >> ${ExpDir}/verifyobs_differences_found.txt
    echo "--> ${CompareDir}/diffStatistics.nc" >> ${ExpDir}/verifyobs_differences_found.txt
    ncdiff -O -v Count,Mean,RMS,STD ${self_StatisticsFile} ${benchmark_StatisticsFile} diffStatistics_${obstype}.nc
  endif
end

touch BENCHMARK_COMPARE_COMPLETE

cd -

date

exit
