#!/bin/csh -f

# ArgMesh: str, mesh, one of model.meshes, not currently used
#set ArgMesh = "$1"

#if ( $?config_forecast ) exit 0
#set config_forecast = 1

source config/auto/members.csh
source config/auto/model.csh
source config/auto/workflow.csh

source config/auto/scenario.csh forecast

#if ("$ArgMesh" == None or "$ArgMesh" == "") then
#  set ArgMesh = "$outerMesh"
#endif

$setLocal updateSea

setenv AppName forecast

setenv FCOutIntervalHR ${CyclingWindowHR}
setenv FCLengthHR ${CyclingWindowHR}

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
    inherit = BATCH
    [[[job]]]
      execution time limit = PT${seconds}S
      execution retry delays = ${retry}
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}
  [[Forecast]]
    inherit = ForecastBase
  [[ColdForecast]]
    inherit = ForecastBase
{% for mem in range(1, $nMembers+1, 1) %}
  [[ColdForecastMember{{mem}}]]
    inherit = ColdForecast
    script = \$origin/applications/ColdForecast.csh "{{mem}}" "${FCLengthHR}" "${FCOutIntervalHR}" "False" "${outerMesh}" "False" "True"
  [[ForecastMember{{mem}}]]
    inherit = Forecast
    script = \$origin/applications/Forecast.csh "{{mem}}" "${FCLengthHR}" "${FCOutIntervalHR}" "True" "${outerMesh}" "True" "True"
  [[ForecastFinished]]
    inherit = BACKGROUND
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
  [[ExtendedFCBase]]
    inherit = BATCH
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
    script = \$origin/applications/ExtendedFCFromExternalAnalysis.csh "1" "${ExtendedFCLengthHR}" "${ExtendedFCOutIntervalHR}" "False" "${outerMesh}" "False" "False"

  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = BATCH
    script = \$origin/applications/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -m = ae
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=1:ncpus=36:mpiprocs=36
  [[ExtendedMeanFC]]
    inherit = ExtendedFCBase
    script = \$origin/applications/ExtendedMeanFC.csh "1" "${ExtendedFCLengthHR}" "${ExtendedFCOutIntervalHR}" "False" "${outerMesh}" "True" "False"

  ## from ensemble of analyses
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase
{% for mem in EnsVerifyMembers %}
  [[ExtendedFC{{mem}}]]
    inherit = ExtendedEnsFC
    script = \$origin/applications/ExtendedEnsFC.csh "{{mem}}" "${ExtendedFCLengthHR}" "${ExtendedFCOutIntervalHR}" "False" "${outerMesh}" "True" "False"
{% endfor %}

  [[ExtendedForecastFinished]]
    inherit = BACKGROUND
EOF

endif
