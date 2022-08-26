#!/bin/csh -f

# only load variational if it is not already loaded
# note: set must be used instead of setenv, because some of the setLocal commands apply to
# lists, which use set instead of setenv
if ( $?config_variational ) exit 0
set config_variational = 1

source config/members.csh
source config/model.csh
source config/naming.csh

source config/scenario.csh variational

# variational settings
$setLocal DAType

$setLocal nInnerIterations
# nOuterIterations, automatically determined from length of nInnerIterations
setenv nOuterIterations ${#nInnerIterations}

# stochastic DA settings
set EDASize = "`$getLocalOrNone EDASize`"
if ($EDASize == None) then
  set EDASize = 1
endif

@ nDAInstances = $nMembers / $EDASize
@ nEnsDAMembers = $EDASize * $nDAInstances

if ($nEnsDAMembers != $nMembers) then
  echo "config/applications/variational.csh (ERROR): nMembers must be divisible by EDASize"
  exit 1
endif
setenv nDAInstances $nDAInstances

$setLocal SelfExclusion


# ensemble
if ($DAType == 3denvar || $DAType == 3dhybrid) then
  # localization
  $setLocal ensemble.localization.${ensembleMesh}.bumpLocPrefix
  $setLocal ensemble.localization.${ensembleMesh}.bumpLocDir

  # forecasts
  if ( $nMembers > 1 ) then
    # EDA uses online ensemble updating
    setenv ensPbMemPrefix "${flowMemPrefix}"
    setenv ensPbMemNDigits ${flowMemNDigits}
    setenv ensPbFilePrefix ${FCFilePrefix}
    setenv ensPbDir0 "{{ExperimentDirectory}}/${forecastWorkDir}/{{prevDateTime}}"
    setenv ensPbDir1 None
    setenv ensPbNMembers ${nMembers}
    # TODO: this needs to be non-zero for EDA workflows that use IAU
    setenv ensPbOffsetHR 0
  else
    $setLocal ensemble.forecasts.resource

    foreach parameter (maxMembers directory0 directory1 filePrefix memberPrefix memberNDigits forecastDateOffsetHR)
      set p = "`$getLocalOrNone ensemble.forecasts.${resource}.${ensembleMesh}.${parameter}`"
      if ( "$p" == None ) then
        set p = "`$getLocalOrNone ensemble.forecasts.defaults.${parameter}`"
      endif
      set ${parameter}_ = "$p"
    end

    setenv ensPbMemPrefix "${memberPrefix_}"
    setenv ensPbMemNDigits ${memberNDigits_}
    setenv ensPbFilePrefix ${filePrefix_}
    setenv ensPbDir0 "${directory0_}"
    setenv ensPbDir1 "${directory1_}"
    setenv ensPbNMembers ${maxMembers_}
    setenv ensPbOffsetHR ${forecastDateOffsetHR_}
  endif
else
  set ensPbNMembers = 0
endif

# ensemble inflation settings
$setLocal ABEInflation
$setLocal ABEIChannel

# covariance
if ($DAType == 3dvar || $DAType == 3dhybrid) then
  $setLocal covariance.bumpCovControlVariables
  $setLocal covariance.bumpCovPrefix
  $setLocal covariance.bumpCovVBalPrefix
  $setLocal covariance.${innerMesh}.bumpCovDir
  $setLocal covariance.${innerMesh}.bumpCovStdDevFile
  $setLocal covariance.${innerMesh}.bumpCovVBalDir
endif

set ensembleCovarianceWeight = "`$getLocalOrNone ensembleCovarianceWeight`"
set staticCovarianceWeight = "`$getLocalOrNone staticCovarianceWeight`"

## required settings for PrepJEDI.csh
setenv AppName $DAType
setenv appyaml ${AppName}.yaml

# observations, automatically combine two parent ObsList's
$setLocal benchmarkObservations
$setLocal experimentalObservations
set observations = ($benchmarkObservations $experimentalObservations)

set MeshList = (Outer Inner)
set nCellsList = ($nCellsOuter $nCellsInner)
set localStaticFieldsFileList = ( \
$localStaticFieldsFileOuter \
$localStaticFieldsFileInner \
)
set StreamsFileList = ($outerStreamsFile $innerStreamsFile)
set NamelistFileList = ($outerNamelistFile $innerNamelistFile)
$setLocal nObsIndent
$setLocal radianceThinningDistance
$setLocal biasCorrection
$setLocal tropprsMethod
$setLocal maxIODAPoolSize

## clean
$setLocal retainObsFeedback

## job
$setLocal job.retry

foreach parameter (baseSeconds secondsPerEnVarMember nodes PEPerNode memory)
  set p = "`$getLocalOrNone job.${outerMesh}.${innerMesh}.${DAType}.${parameter}`"
  if ("$p" == None) then
    set p = "`$getLocalOrNone job.defaults.${parameter}`"
  endif
  if ("$p" == None) then
    echo "config/applications/variational.csh (ERROR): invalid value for $paramater"
    exit 1
  endif
  set ${parameter}_ = "$p"
end

if ("$secondsPerEnVarMember_" == None) then
  set secondsPerEnVarMember_ = 0
endif
@ seconds = $secondsPerEnVarMember_ * $ensPbNMembers + $baseSeconds_
setenv seconds $seconds


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/tasks/auto/variational.rc ) then
cat >! include/tasks/auto/variational.rc << EOF
# variational
  [[InitDataAssim]]
    inherit = BATCH
    env-script = cd {{mainScriptDir}}; ./PrepJEDIVariational.csh "1" "0" "DA" "variational"
    script = \$origin/PrepVariational.csh "1"
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = ${retry}

  [[DataAssim]]
    inherit = BATCH

{% if ${EDASize} == 1 %}
  # single instance or ensemble of Variational(s)
  {% for mem in range(1, ${nMembers}+1, 1) %}
  [[DAMember{{mem}}]]
    inherit = DataAssim
    script = \$origin/Variational.csh "{{mem}}"
    [[[job]]]
      execution time limit = PT${seconds}S
      execution retry delays = ${retry}
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}:mem=${memory_}GB
  {% endfor %}
{% endif %}

  [[CleanVariational]]
    inherit = CleanBase, BATCH
    script = \$origin/CleanVariational.csh
EOF

endif

if ( ! -e include/dependencies/auto/abei.rc ) then

  if ( "$ABEInflation" == True ) then
cat >! include/dependencies/auto/abei.rc << EOF
        ForecastFinished[-PT{{FC2DAOffsetHR}}H] =>
        MeanBackground =>
        HofXEnsMeanBG =>
        GenerateABEInflation => PreDataAssim
        GenerateABEInflation => CleanHofXEnsMeanBG
EOF

  else
cat >! include/dependencies/auto/abei.rc << EOF
#
EOF

  endif

endif

##############################
## more non-YAML-fied settings
##############################
## MinimizerAlgorithm
# OPTIONS: DRIPCG, DRPLanczos, DRPBlockLanczos
# see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
# Notes about DRPBlockLanczos:
# + still experimental, and not reliable for this experiment
# + only available when EDASize > 1
setenv BlockEDA DRPBlockLanczos
setenv MinimizerAlgorithm DRIPCG

if ($EDASize == 1 && $MinimizerAlgorithm == $BlockEDA) then
  echo "WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos"
  setenv MinimizerAlgorithm DRPLanczos
endif

setenv YAMLPrefix ${AppName}_
