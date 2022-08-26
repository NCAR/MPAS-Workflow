#!/bin/csh -f

# ArgMesh: str, mesh, one of model.allMeshes, not currently used
#set ArgMesh = "$1"

#if ( $?config_forecast ) exit 0
#set config_forecast = 1

source config/members.csh
source config/model.csh
source config/workflow.csh

source config/scenario.csh forecast

#if ("$ArgMesh" == None or "$ArgMesh" == "") then
#  set ArgMesh = "$outerMesh"
#endif

$setLocal updateSea

## IAU
$setNestedForecast IAU
if ($forecast__IAU == True) then
  @ IAUoutIntervalHR = $CyclingWindowHR / 2
  @ IAUfcLengthHR = 3 * $IAUoutIntervalHR
  setenv FCLengthHR $IAUfcLengthHR
  setenv FCOutIntervalHR $IAUoutIntervalHR
else
  setenv FCLengthHR $CyclingWindowHR
  setenv FCOutIntervalHR $CyclingWindowHR
endif
##

setenv AppName forecast

$setLocal ExtendedFCLengthHR
$setLocal ExtendedFCOutIntervalHR
$setLocal ExtendedMeanFCTimes
set ExtendedMeanFCTimesList = '"'`echo $ExtendedMeanFCTimes | sed 's@,@","@g'`'"'
$setLocal ExtendedEnsFCTimes
set ExtendedEnsFCTimesList = '"'`echo $ExtendedEnsFCTimes | sed 's@,@","@g'`'"'

## job
$setLocal job.retry

foreach parameter (baseSeconds secondsPerForecastHR nodes PEPerNode)
  set p = "`$getLocalOrNone job.${outerMesh}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/forecast.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end


##################################
# auto-generate cylc include files
##################################

# forecast
@ seconds = $secondsPerForecastHR_ * $FCLengthHR + $baseSeconds_
setenv seconds $seconds

if ( ! -e include/tasks/auto/forecast.rc ) then
cat >! include/tasks/auto/forecast.rc << EOF
  [[ForecastBase]]
    [[[job]]]
      execution time limit = PT${seconds}S
      execution retry delays = ${retry}
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}
  [[Forecast]]
    inherit = ForecastBase, BATCH
  [[ColdForecast]]
    inherit = ForecastBase, BATCH
{% for mem in range(1, $nMembers+1, 1) %}
  [[ColdForecastMember{{mem}}]]
    inherit = ColdForecast
    script = \$origin/ColdForecast.csh "{{mem}}" "${FCLengthHR}" "${FCOutIntervalHR}" "False" "${outerMesh}" "False" "True"
  [[ForecastMember{{mem}}]]
    inherit = Forecast
    script = \$origin/Forecast.csh "{{mem}}" "${FCLengthHR}" "${FCOutIntervalHR}" "${forecast__IAU}" "${outerMesh}" "True" "True"
  [[ForecastFinished]]
{% endfor %}
EOF

endif

# extendedforecast
@ seconds = $secondsPerForecastHR_ * $ExtendedFCLengthHR + $baseSeconds_
setenv seconds $seconds

if ( ! -e include/variables/auto/extendedforecast.rc ) then
cat >! include/variables/auto/extendedforecast.rc << EOF
{% set EnsVerifyMembers = range(1, $nMembers+1, 1) %}
{% set ExtendedMeanFCTimes = "${ExtendedMeanFCTimes}" %}
{% set ExtendedEnsFCTimes = "${ExtendedEnsFCTimes}" %}
{% set ExtendedMeanFCTimesList = [${ExtendedMeanFCTimesList}] %}
{% set ExtendedEnsFCTimesList = [${ExtendedEnsFCTimesList}] %}
{% set extFCLenHR = ${ExtendedFCLengthHR} %}
{% set extFCIntervHR = ${ExtendedFCOutIntervalHR} %}
{% set nExtFCOuts = (extFCLenHR / extFCIntervHR + 1)|int %}
{% set ExtendedFCLengths = range(0, extFCLenHR+extFCIntervHR, extFCIntervHR) %}
EOF

endif

if ( ! -e include/tasks/auto/extendedforecast.rc ) then
cat >! include/tasks/auto/extendedforecast.rc << EOF
  [[ExtendedForecast]]
  [[ExtendedFCBase]]
    inherit = ExtendedForecast, BATCH
    [[[job]]]
      execution time limit = PT${seconds}S
    [[[directives]]]
      -m = ae
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}

  ## from external analysis
  [[ExtendedFCFromExternalAnalysis]]
    inherit = ExtendedFCBase
    script = \$origin/ExtendedFCFromExternalAnalysis.csh "1" "${ExtendedFCLengthHR}" "${ExtendedFCOutIntervalHR}" "False" "${outerMesh}" "False" "False"

  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = ExtendedForecast, BATCH
    script = \$origin/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -m = ae
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=1:ncpus=36:mpiprocs=36
  [[ExtendedMeanFC]]
    inherit = ExtendedFCBase
    script = \$origin/ExtendedMeanFC.csh "1" "${ExtendedFCLengthHR}" "${ExtendedFCOutIntervalHR}" "False" "${outerMesh}" "True" "False"

  ## from ensemble of analyses
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase
{% for mem in EnsVerifyMembers %}
  [[ExtendedFC{{mem}}]]
    inherit = ExtendedEnsFC
    script = \$origin/ExtendedEnsFC.csh "{{mem}}" "${ExtendedFCLengthHR}" "${ExtendedFCOutIntervalHR}" "False" "${outerMesh}" "True" "False"
{% endfor %}

  [[ExtendedForecastFinished]]
    inherit = ExtendedForecast
EOF

endif
