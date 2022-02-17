#!/bin/csh

## Top-level workflow configuration

## load experiment configuration
source config/experiment.csh

######################
# workflow date bounds
######################
## initialCyclePoint
# OPTIONS: >= FirstCycleDate (see config/experiment.csh)
# Either:
# + initialCyclePoint must be equal to FirstCycleDate
# OR:
# + CyclingFC must have been completed for the cycle before initialCyclePoint. Set > FirstCycleDate to automatically restart
#   from a previously completed cycle.
set initialCyclePoint = 20180414T18

## finalCyclePoint
# OPTIONS: >= initialCyclePoint
# + ancillary model and/or observation data must be available between initialCyclePoint and finalCyclePoint
set finalCyclePoint = 20180514T18


#########################
# workflow task selection
#########################
## CriticalPathType: controls dependencies between and chilrdren of
#                   DA and FC cycling components
# OPTIONS: Normal, Bypass, Reanalysis, Reforecast
set CriticalPathType = Normal

## VerifyDeterministicDA: whether to run verification scripts for
#    obs feedback files from DA.  Does not work for ensemble DA.
#    Only works when CriticalPathType == Normal.
# OPTIONS: True/False
set VerifyDeterministicDA = True

## CompareDA2Benchmark: compare verification nc files between two experiments
#    after the DA verification completes
# OPTIONS: True/False
set CompareDA2Benchmark = False

## VerifyExtendedMeanFC: whether to run verification scripts across
#    extended forecast states, first intialized at mean analysis
# OPTIONS: True/False
set VerifyExtendedMeanFC = False

## VerifyBGMembers: whether to run verification scripts for CyclingWindowHR
#    forecast length. Runs HofXBG, VerifyObsBG, and VerifyModelBG on critical
#    path forecasts that are initialized from ensemble member analyses.
# OPTIONS: True/False
set VerifyBGMembers = False

## CompareBG2Benchmark: compare verification nc files between two experiments
#    after the BGMembers verification completes
# OPTIONS: True/False
set CompareBG2Benchmark = False

## VerifyEnsMeanBG: whether to run verification scripts for ensemble mean
#    background (nEnsDAMembers > 1) or deterministic background (nEnsDAMembers == 1)
# OPTIONS: True/False
set VerifyEnsMeanBG = True

## DiagnoseEnsSpreadBG: whether to diagnose the ensemble spread in observation
#    space while VerifyEnsMeanBG is True.  Automatically triggers HofXBG
#    for all ensemble members.
# OPTIONS: True/False
set DiagnoseEnsSpreadBG = True

## VerifyEnsMeanAN: whether to run verification scripts for ensemble
#    mean analysis state.
# OPTIONS: True/False
set VerifyANMembers = False

## VerifyExtendedEnsBG: whether to run verification scripts across
#    extended forecast states, first intialized at ensemble of analysis
#    states.
# OPTIONS: True/False
set VerifyExtendedEnsFC = False

date

## Set the FirstCycleDate in the right format for cylc
set yymmdd = `echo ${FirstCycleDate} | cut -c 1-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
set firstCyclePoint = ${yymmdd}T${hh}

## Set the cycle hours (cyclingCycles) according to the dates
if ($initialCyclePoint == $firstCyclePoint) then
  # Create the experiment directory and cylc task script
  ./SetupWorkflow.csh
  # The cycles will run every CyclingWindowHR hours, starting CyclingWindowHR hours after the
  # initialCyclePoint
  set cyclingCycles = +PT${CyclingWindowHR}H/PT${CyclingWindowHR}H
else
  # The cycles will run every CyclingWindowHR hours, starting at the initialCyclePoint
  set cyclingCycles = PT${CyclingWindowHR}H
endif

## load the file structure
source config/filestructure.csh

## Change to the cylc suite directory
cd ${mainScriptDir}

## load job submission environment
source config/job.csh
source config/mpas/${MPASGridDescriptor}/job.csh

echo "Initializing ${PackageBaseName}"
module purge
module load cylc
module load graphviz

## SuiteName: name of the cylc suite, can be used to differentiate between two
# suites running simultaneously in the same ${ExperimentName} directory
#
# default: ${ExperimentName}
# example: ${ExperimentName}_verify for a simultaneous suite running only Verification
set SuiteName = ${ExperimentName}

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
rm -fr ${cylcWorkDir}/${SuiteName}
echo "creating suite.rc"
cat >! suite.rc << EOF
#!Jinja2
# cycle dates
{% set firstCyclePoint   = "${firstCyclePoint}" %}
{% set initialCyclePoint = "${initialCyclePoint}" %}
{% set finalCyclePoint   = "${finalCyclePoint}" %}
# cycling components
{% set CriticalPathType = "${CriticalPathType}" %}
{% set PreprocessObs = ${PreprocessObs} %}
{% set VerifyDeterministicDA = ${VerifyDeterministicDA} %}
{% set CompareDA2Benchmark = ${CompareDA2Benchmark} %}
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %}
{% set VerifyBGMembers = ${VerifyBGMembers} %}
{% set CompareBG2Benchmark = ${CompareBG2Benchmark} %}
{% set VerifyEnsMeanBG = ${VerifyEnsMeanBG} %}
{% set DiagnoseEnsSpreadBG = ${DiagnoseEnsSpreadBG} %}
{% set VerifyANMembers = ${VerifyANMembers} %}
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %}
{% set EDASize = ${EDASize} %}
{% set nDAInstances = ${nDAInstances} %}
{% set nEnsDAMembers = ${nEnsDAMembers} %}
{% set RTPPInflationFactor = ${RTPPInflationFactor} %}
{% set ABEInflation = ${ABEInflation} %}
{% set InitializationType = "${InitializationType}" %}
[meta]
  title = "${PackageBaseName}--${SuiteName}"
# critical path cycle dependencies
  {% set PrimaryCPGraph = "" %}
  {% set SecondaryCPGraph = "" %}
{% if CriticalPathType == "Bypass" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished" %}
{% elif CriticalPathType == "Reanalysis" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        InitCyclingDA => CyclingDA" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDA:succeed-all => CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished" %}
  {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        CyclingDAFinished => CleanCyclingDA" %}
{% elif CriticalPathType == "Reforecast" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished" %}
{% elif CriticalPathType == "Normal" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished[-PT${CyclingWindowHR}H]" %}
  {% if PreprocessObs %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => ObstoIODA" %}
  {% endif %}
  {% if (ABEInflation and nEnsDAMembers > 1) %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => MeanBackground" %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => HofXEnsMeanBG" %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => GenerateABEInflation" %}
    {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        GenerateABEInflation => CleanHofXEnsMeanBG" %}
  {% endif %}
  {% set PrimaryCPGraph = PrimaryCPGraph + " => InitCyclingDA => CyclingDA" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDA:succeed-all => CyclingDAFinished" %}
  {% if (RTPPInflationFactor > 0.0 and nEnsDAMembers > 1) %}
    {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDA:succeed-all => RTPPInflation => CyclingDAFinished" %}
  {% endif %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished => CyclingFC" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        CyclingDAFinished => CleanCyclingDA" %}
{# else #}
#TODO: indicate invalid CriticalPathType
{% endif %}
# verification and extended forecast controls
{% set ExtendedFCLengths = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
{% set EnsDAMembers = range(1, nEnsDAMembers+1, 1) %}
{% set DAInstances = range(1, nDAInstances+1, 1) %}
{% set EnsVerifyMembers = range(1, nEnsDAMembers+1, 1) %}
[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  # Maximum number of simultaneous active dates;
  # useful for constraining non-blocking flows
  # and to avoid over-utilization of login nodes
  # hint: execute 'ps aux | grep $USER' to check your login node overhead
  # default: 3
{% if CriticalPathType == "Bypass" %}
  max active cycle points = 20
{% else %}
  max active cycle points = 4
{% endif %}
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}
  [[dependencies]]
{% if initialCyclePoint == firstCyclePoint %}
  {% if InitializationType == "ColdStart" %}
      [[[R1]]]
        graph = UngribColdStartIC => GenerateColdStartIC => ColdStartFC => CyclingFCFinished
  {% elif InitializationType == "WarmStart" %}
      [[[R1]]]
        graph = GetWarmStartIC => CyclingFCFinished
  {% endif %}
{% endif %}
## Critical path for cycling
    [[[${cyclingCycles}]]]
      graph = '''{{PrimaryCPGraph}}{{SecondaryCPGraph}}
      '''
## Many kinds of verification
{% if CriticalPathType == "Normal" and VerifyDeterministicDA and nEnsDAMembers < 2 %}
#TODO: enable VerifyObsDA to handle more than one ensemble member
#      and use feedback files from EDA for VerifyEnsMeanBG
## Verification of deterministic DA with observations (BG+AN together)
    [[[${cyclingCycles}]]]
      graph = '''
        CyclingDAFinished => VerifyObsDA
        VerifyObsDA => CleanCyclingDA
  {% if CompareDA2Benchmark %}
        VerifyObsDA => CompareObsDA
  {% endif %}
      '''
{% endif %}
{% if VerifyExtendedMeanFC %}
## Extended forecast and verification from mean of analysis states
    [[[${ExtendedMeanFCTimes}]]]
      graph = '''
        CyclingDAFinished => MeanAnalysis => ExtendedMeanFC
        ExtendedMeanFC => HofXMeanFC
        ExtendedMeanFC => VerifyModelMeanFC
  {% for dt in ExtendedFCLengths %}
        HofXMeanFC{{dt}}hr => VerifyObsMeanFC{{dt}}hr
        VerifyObsMeanFC{{dt}}hr => CleanHofXMeanFC{{dt}}hr
  {% endfor %}
      '''
{% endif %}
{% if VerifyBGMembers %}
## Ensemble BG verification
    [[[${cyclingCycles}]]]
      graph = '''
        CyclingFCFinished[-PT${CyclingWindowHR}H] => HofXBG
        CyclingFCFinished[-PT${CyclingWindowHR}H] => VerifyModelBG
  {% for mem in EnsVerifyMembers %}
        HofXBG{{mem}} => VerifyObsBG{{mem}}
        VerifyObsBG{{mem}} => CleanHofXBG{{mem}}
    {% if CompareBG2Benchmark %}
        VerifyModelBG{{mem}} => CompareModelBG{{mem}}
        VerifyObsBG{{mem}} => CompareObsBG{{mem}}
    {% endif %}
  {% endfor %}
      '''
{% elif VerifyEnsMeanBG and nEnsDAMembers == 1 %}
    [[[${cyclingCycles}]]]
      graph = '''
  {% if PreprocessObs %}
        ObstoIODA => HofXBG
  {% else %}
        CyclingFCFinished[-PT${CyclingWindowHR}H] => HofXBG
  {% endif %}
        CyclingFCFinished[-PT${CyclingWindowHR}H] => VerifyModelBG
  {% for mem in [1] %}
        HofXBG{{mem}} => VerifyObsBG{{mem}}
        VerifyObsBG{{mem}} => CleanHofXBG{{mem}}
    {% if CompareBG2Benchmark %}
        VerifyModelBG{{mem}} => CompareModelBG{{mem}}
        VerifyObsBG{{mem}} => CompareObsBG{{mem}}
    {% endif %}
  {% endfor %}
      '''
{% endif %}
{% if VerifyEnsMeanBG and nEnsDAMembers > 1 %}
## Ensemble Mean BG verification
    [[[${cyclingCycles}]]]
      graph = '''
        CyclingFCFinished[-PT${CyclingWindowHR}H] => MeanBackground
        MeanBackground => HofXEnsMeanBG
        MeanBackground => VerifyModelEnsMeanBG
        HofXEnsMeanBG => VerifyObsEnsMeanBG
        VerifyObsEnsMeanBG => CleanHofXEnsMeanBG
  {% if DiagnoseEnsSpreadBG %}
        CyclingFCFinished[-PT${CyclingWindowHR}H] => HofXBG
        HofXBG:succeed-all => VerifyObsEnsMeanBG
        VerifyObsEnsMeanBG => CleanHofXBG
  {% endif %}
      '''
{% endif %}
{% if VerifyANMembers %}
## Ensemble AN verification
    [[[${cyclingCycles}]]]
      graph = '''
  {% for mem in EnsVerifyMembers %}
        CyclingDAFinished => VerifyModelAN{{mem}}
        CyclingDAFinished => HofXAN{{mem}}
        HofXAN{{mem}} => VerifyObsAN{{mem}}
        VerifyObsAN{{mem}} => CleanHofXAN{{mem}}
  {% endfor %}
      '''
{% endif %}
{% if VerifyExtendedEnsFC %}
## Extended forecast and verification from ensemble of analysis states
    [[[${ExtendedEnsFCTimes}]]]
      graph = '''
        CyclingDAFinished => ExtendedEnsFC
  {% for mem in EnsVerifyMembers %}
        ExtendedFC{{mem}} => VerifyModelEnsFC{{mem}}
        ExtendedFC{{mem}} => HofXEnsFC{{mem}}
    {% for dt in ExtendedFCLengths %}
        HofXEnsFC{{mem}}-{{dt}}hr => VerifyObsEnsFC{{mem}}-{{dt}}hr
        VerifyObsEnsFC{{mem}}-{{dt}}hr => CleanHofXEnsFC{{mem}}-{{dt}}hr
    {% endfor %}
  {% endfor %}
      '''
{% endif %}
[runtime]
#Base components
  [[root]] # suite defaults
    pre-script = "cd  \$origin/"
    [[[environment]]]
      origin = ${mainScriptDir}
## PBS
    [[[job]]]
      batch system = pbs
      execution time limit = PT60M
    [[[directives]]]
      -j = oe
      -k = eod
      -S = /bin/tcsh
      # default to using one processor
      -q = ${SingleProcQueueName}
      -A = ${SingleProcAccountNumber}
      -l = select=1:ncpus=1
## SLURM
#    [[[job]]]
#      batch system = slurm
#      execution time limit = PT60M
#    [[[directives]]]
#      --account = ${CPAccountNumber}
#      --mem = 45G
#      --ntasks = 1
#      --cpus-per-task = 36
#      --partition = dav
  [[CyclingFCBase]]
    [[[job]]]
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
      -m = ae
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=${CyclingFCNodes}:ncpus=${CyclingFCPEPerNode}:mpiprocs=${CyclingFCPEPerNode}
  [[ExtendedFCBase]]
    [[[job]]]
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -m = ae
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=${ExtendedFCNodes}:ncpus=${ExtendedFCPEPerNode}:mpiprocs=${ExtendedFCPEPerNode}
  [[HofXBase]]
    [[[job]]]
      execution time limit = PT${HofXJobMinutes}M
    [[[directives]]]
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=${HofXNodes}:ncpus=${HofXPEPerNode}:mpiprocs=${HofXPEPerNode}:mem=${HofXMemory}GB
  [[VerifyModelBase]]
    [[[job]]]
      execution time limit = PT${VerifyModelJobMinutes}M
    [[[directives]]]
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[VerifyObsBase]]
    [[[job]]]
      execution time limit = PT${VerifyObsJobMinutes}M
      execution retry delays = ${HofXRetry}
    [[[directives]]]
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[CompareBase]]
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[CleanBase]]
    [[[job]]]
      execution time limit = PT5M
#Cycling components
  # initialization-related components
  [[GetWarmStartIC]]
    script = \$origin/GetWarmStartIC.csh
    [[[job]]]
      # give longer for higher resolution and more EDA members
      # TODO: set time limit based on outer mesh AND (number of members OR
      #       independent task for each member) under config/mpas/*/job.csh
      execution time limit = PT10M
      execution retry delays = ${InitializationRetry}
  # observations-related components
  [[ObstoIODA]]
    script = \$origin/ObstoIODA.csh
    [[[job]]]
      execution time limit = PT10M
      execution retry delays = ${InitializationRetry}
    # currently ObstoIODA has to be on Cheyenne, because ioda-upgrade.x is built there
    # TODO: build ioda-upgrade.x on casper, remove CP directives below
    # Note: memory for ObstoIODA may need to be increased when hyperspectral and/or
    #       geostationary instruments are added
    [[[directives]]]
      -m = ae
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=1:ncpus=1:mem=10GB
  # variational-related components
  [[InitCyclingDA]]
    env-script = cd ${mainScriptDir}; ./PrepJEDIVariational.csh "1" "0" "DA"
    script = \$origin/PrepVariational.csh "1"
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = ${VariationalRetry}
  [[CyclingDA]]
{% if EDASize > 1 %}
  {% for inst in DAInstances %}
  [[EDAInstance{{inst}}]]
    inherit = CyclingDA
    script = \$origin/EnsembleOfVariational.csh "{{inst}}"
    [[[job]]]
      execution time limit = PT${EnsOfVariationalJobMinutes}M
      execution retry delays = ${EnsOfVariationalRetry}
    [[[directives]]]
      -m = ae
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=${EnsOfVariationalNodes}:ncpus=${EnsOfVariationalPEPerNode}:mpiprocs=${EnsOfVariationalPEPerNode}:mem=${EnsOfVariationalMemory}GB
  {% endfor %}
{% else %}
  {% for mem in EnsDAMembers %}
  [[DAMember{{mem}}]]
    inherit = CyclingDA
    script = \$origin/Variational.csh "{{mem}}"
    [[[job]]]
      execution time limit = PT${VariationalJobMinutes}M
      execution retry delays = ${VariationalRetry}
    [[[directives]]]
      -m = ae
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=${VariationalNodes}:ncpus=${VariationalPEPerNode}:mpiprocs=${VariationalPEPerNode}:mem=${VariationalMemory}GB
  {% endfor %}
{% endif %}
  [[RTPPInflation]]
    script = \$origin/RTPPInflation.csh
    [[[job]]]
      execution time limit = PT${CyclingInflationJobMinutes}M
      execution retry delays = ${RTPPInflationRetry}
    [[[directives]]]
      -m = ae
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=${CyclingInflationNodes}:ncpus=${CyclingInflationPEPerNode}:mpiprocs=${CyclingInflationPEPerNode}:mem=${CyclingInflationMemory}GB
  [[GenerateABEInflation]]
    script = \$origin/GenerateABEInflation.csh
    [[[job]]]
      execution time limit = PT20M
    [[[directives]]]
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[CyclingDAFinished]]
    [[[job]]]
      batch system = background
  [[VerifyObsDA]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsDA.csh "1" "0" "DA" "0"
  [[CompareObsDA]]
    inherit = CompareBase
    script = \$origin/CompareObsDA.csh "1" "0" "DA" "0"
  [[CleanCyclingDA]]
    inherit = CleanBase
    script = \$origin/CleanVariational.csh
  # forecast-related components
  [[UngribColdStartIC]]
    script = \$origin/UngribColdStartIC.csh
    [[[job]]]
      execution time limit = PT5M
      execution retry delays = ${InitializationRetry}
    # currently UngribColdStartIC has to be on Cheyenne, because ungrib.exe is built there
    # TODO: build ungrib.exe on casper, remove CP directives below
    [[[directives]]]
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
  [[GenerateColdStartIC]]
    script = \$origin/GenerateColdStartIC.csh
    [[[job]]]
      execution time limit = PT${InitICJobMinutes}M
      execution retry delays = ${InitializationRetry}
    [[[directives]]]
      -q = ${CPQueueName}
      -A = ${CPAccountNumber}
      -l = select=${InitICNodes}:ncpus=${InitICPEPerNode}:mpiprocs=${InitICPEPerNode}
  [[ColdStartFC]]
    inherit = CyclingFCBase
    script = \$origin/CyclingFC.csh "1"
    [[[job]]]
      execution retry delays = ${CyclingFCRetry}
  [[CyclingFC]]
    inherit = CyclingFCBase
{% for mem in EnsDAMembers %}
  [[CyclingFCMember{{mem}}]]
    inherit = CyclingFC
    script = \$origin/CyclingFC.csh "{{mem}}"
    [[[job]]]
      execution retry delays = ${CyclingFCRetry}
{% endfor %}
  [[CyclingFCFinished]]
    [[[job]]]
      batch system = background
## Extended mean analysis, forecast, and verification
  [[MeanAnalysis]]
    script = \$origin/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -m = ae
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[ExtendedMeanFC]]
    inherit = ExtendedFCBase
    script = \$origin/ExtendedMeanFC.csh "1"
  [[HofXMeanFC]]
    inherit = HofXBase
  [[VerifyModelMeanFC]]
    inherit = VerifyModelBase
{% for dt in ExtendedFCLengths %}
  [[HofXMeanFC{{dt}}hr]]
    inherit = HofXMeanFC
    env-script = cd ${mainScriptDir}; ./PrepJEDIHofXMeanFC.csh "1" "{{dt}}" "FC"
    script = \$origin/HofXMeanFC.csh "1" "{{dt}}" "FC"
    [[[job]]]
      execution retry delays = ${HofXRetry}
  [[CleanHofXMeanFC{{dt}}hr]]
    inherit = CleanBase
    script = \$origin/CleanHofXMeanFC.csh "1" "{{dt}}" "FC"
  [[VerifyObsMeanFC{{dt}}hr]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsMeanFC.csh "1" "{{dt}}" "FC" "0"
  [[VerifyModelMeanFC{{dt}}hr]]
    inherit = VerifyModelMeanFC
    script = \$origin/VerifyModelMeanFC.csh "1" "{{dt}}" "FC"
{% endfor %}
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase
{% for state in ['BG', 'AN']%}
  [[HofX{{state}}]]
    inherit = HofXBase
  [[VerifyModel{{state}}]]
    inherit = VerifyModelBase
  [[CompareModel{{state}}]]
    inherit = CompareBase
  [[VerifyObs{{state}}]]
    inherit = VerifyObsBase
  [[CompareObs{{state}}]]
    inherit = CompareBase
  [[CleanHofX{{state}}]]
    inherit = CleanBase
{% endfor %}
{% for mem in EnsVerifyMembers %}
## Ensemble BG/AN verification
  {% for state in ['BG', 'AN']%}
  [[HofX{{state}}{{mem}}]]
    inherit = HofX{{state}}
    env-script = cd ${mainScriptDir}; ./PrepJEDIHofX{{state}}.csh "{{mem}}" "0" "{{state}}"
    script = \$origin/HofX{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[[job]]]
      execution retry delays = ${HofXRetry}
  [[VerifyModel{{state}}{{mem}}]]
    inherit = VerifyModel{{state}}
    script = \$origin/VerifyModel{{state}}.csh "{{mem}}" "0" "{{state}}"
  [[CompareModel{{state}}{{mem}}]]
    inherit = CompareModel{{state}}
    script = \$origin/CompareModel{{state}}.csh "{{mem}}" "0" "{{state}}"
  [[VerifyObs{{state}}{{mem}}]]
    inherit = VerifyObs{{state}}
    script = \$origin/VerifyObs{{state}}.csh "{{mem}}" "0" "{{state}}" "0"
  [[CompareObs{{state}}{{mem}}]]
    inherit = CompareObs{{state}}
    script = \$origin/CompareObs{{state}}.csh "{{mem}}" "0" "{{state}}" "0"
  [[CleanHofX{{state}}{{mem}}]]
    inherit = CleanHofX{{state}}
    script = \$origin/CleanHofX{{state}}.csh "{{mem}}" "0" "{{state}}"
  {% endfor %}
## Extended ensemble forecasts and verification
  [[ExtendedFC{{mem}}]]
    inherit = ExtendedEnsFC
    script = \$origin/ExtendedEnsFC.csh "{{mem}}"
  [[HofXEnsFC{{mem}}]]
    inherit = HofXBase
  [[VerifyModelEnsFC{{mem}}]]
    inherit = VerifyModelBase
  {% for dt in ExtendedFCLengths %}
  [[HofXEnsFC{{mem}}-{{dt}}hr]]
    inherit = HofXEnsFC{{mem}}
    env-script = cd ${mainScriptDir}; ./PrepJEDIHofXEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    script = \$origin/HofXEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[[job]]]
      execution retry delays = ${HofXRetry}
  [[VerifyModelEnsFC{{mem}}-{{dt}}hr]]
    inherit = VerifyModelEnsFC{{mem}}
    script = \$origin/VerifyModelEnsFC.csh "{{mem}}" "{{dt}}" "FC"
  [[VerifyObsEnsFC{{mem}}-{{dt}}hr]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsEnsFC.csh "{{mem}}" "{{dt}}" "FC" "0"
  [[CleanHofXEnsFC{{mem}}-{{dt}}hr]]
    inherit = CleanBase
    script = \$origin/CleanHofXEnsFC.csh "{{mem}}" "{{dt}}" "FC"
  {% endfor %}
{% endfor %}
## Mean/ensemble background verification
  [[MeanBackground]]
    script = \$origin/MeanBackground.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -m = ae
      -q = ${NCPQueueName}
      -A = ${NCPAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[HofXEnsMeanBG]]
    inherit = HofXBase
    env-script = cd ${mainScriptDir}; ./PrepJEDIHofXEnsMeanBG.csh "1" "0" "BG"
    script = \$origin/HofXEnsMeanBG.csh "1" "0" "BG"
    [[[directives]]]
      -q = ${EnsMeanBGQueueName}
      -A = ${EnsMeanBGAccountNumber}
    [[[job]]]
      execution retry delays = ${HofXRetry}
  [[VerifyModelEnsMeanBG]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelEnsMeanBG.csh "1" "0" "BG"
  [[VerifyObsEnsMeanBG]]
    inherit = VerifyObsBase
{% if DiagnoseEnsSpreadBG %}
    script = \$origin/VerifyObsEnsMeanBG.csh "1" "0" "BG" "{{nEnsDAMembers}}"
    [[[job]]]
      execution time limit = PT${VerifyObsEnsMeanJobMinutes}M
{% else %}
    script = \$origin/VerifyObsEnsMeanBG.csh "1" "0" "BG" "0"
{% endif %}
  [[CleanHofXEnsMeanBG]]
    inherit = CleanBase
    script = \$origin/CleanHofXEnsMeanBG.csh "1" "0" "BG"
[visualization]
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}
  number of cycle points = 200
  default node attributes = "style=filled", "fillcolor=grey"
EOF

cylc register ${SuiteName} ${mainScriptDir}
cylc validate ${SuiteName}
cylc run ${SuiteName}

exit
