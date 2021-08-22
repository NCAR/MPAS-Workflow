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
# + CyclingFC must have been completed for the cycle before initialCyclePoint. Set > FirstCycleDate to automatically restart#   from a previously completed cycle.
set initialCyclePoint = 20180415T00

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

## VerifyMemberBG: whether to run verification scripts for CyclingWindowHR
#    forecast length. Utilizes critical path forecast states from
#    individual ensemble member analyses or deterministic analysis
# OPTIONS: True/False
set VerifyMemberBG = True

## CompareBG2Benchmark: compare verification nc files between two experiments
#    after the MemberBG verification completes
# OPTIONS: True/False
set CompareBG2Benchmark = False

## VerifyEnsMeanBG: whether to run verification scripts for ensemble
#    mean background state.
# OPTIONS: True/False
set VerifyEnsMeanBG = True

## DiagnoseEnsSpreadBG: whether to diagnose the ensemble spread in observation
#    space while VerifyEnsMeanBG is True.  Automatically triggers OMF calculation
#    for all ensemble members. VerifyEnsMeanBG is nearly free when
#    DiagnoseEnsSpreadBG is True.
#    mean background state.
# OPTIONS: True/False
set DiagnoseEnsSpreadBG = True

## VerifyEnsMeanAN: whether to run verification scripts for ensemble
#    mean analysis state.
# OPTIONS: True/False
set VerifyMemberAN = False

## VerifyExtendedEnsBG: whether to run verification scripts across
#    extended forecast states, first intialized at ensemble of analysis
#    states.
# OPTIONS: True/False
set VerifyExtendedEnsFC = False

date

## load the file structure
source config/filestructure.csh

## load job submission environment
source config/job.csh
source config/mpas/${MPASGridDescriptor}/job.csh

## Initialize cycling directory if this is the first cycle point
set yymmdd = `echo ${FirstCycleDate} | cut -c 1-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
set firstCyclePoint = ${yymmdd}T${hh}
if ($initialCyclePoint == $firstCyclePoint) then
  ./SetupWorkflow.csh
endif

## Change to the cylc suite directory
cd ${mainScriptDir}

echo "Initializing ${PackageBaseName}"
module purge
module load cylc
module load graphviz

set cylcWorkDir = /glade/scratch/${USER}/cylc-run
rm -fr ${cylcWorkDir}/${ExperimentName}
echo "creating suite.rc"
cat >! suite.rc << EOF
#!Jinja2
# cycle dates
{% set initialCyclePoint = "${initialCyclePoint}" %}
{% set finalCyclePoint = "${finalCyclePoint}" %}
#TODO: put warm-start file copying in InitEnsFC/firstfc script for R1 cycle point
{# set firstCyclePoint = "${firstCyclePoint}" #}
# cycling components
{% set CriticalPathType = "${CriticalPathType}" %}
{% set VerifyDeterministicDA = ${VerifyDeterministicDA} %}
{% set CompareDA2Benchmark = ${CompareDA2Benchmark} %}
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %}
{% set VerifyMemberBG = ${VerifyMemberBG} %}
{% set CompareBG2Benchmark = ${CompareBG2Benchmark} %}
{% set VerifyEnsMeanBG = ${VerifyEnsMeanBG} %}
{% set DiagnoseEnsSpreadBG = ${DiagnoseEnsSpreadBG} %}
{% set VerifyMemberAN = ${VerifyMemberAN} %}
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %}
{% set nEnsDAMembers = ${nEnsDAMembers} %}
{% set RTPPInflationFactor = ${RTPPInflationFactor} %}
{% set ABEInflation = ${ABEInflation} %}
[meta]
  title = "${PackageBaseName}--${ExperimentName}"
# critical path cycle dependencies
  {% set PrimaryCPGraph = "" %}
  {% set SecondaryCPGraph = "" %}
{% if CriticalPathType == "Bypass" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished" %}
{% elif CriticalPathType == "Reanalysis" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDA => CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished" %}
  {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        CyclingDAFinished => CleanCyclingDA" %}
{% elif CriticalPathType == "Reforecast" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished" %}
{% elif CriticalPathType == "Normal" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished[-PT${CyclingWindowHR}H]" %}
  {% if (ABEInflation and nEnsDAMembers > 1) %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => MeanBackground" %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => HofXEnsMeanBG" %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => GenerateABEInflation" %}
    {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        GenerateABEInflation => CleanHofXEnsMeanBG" %}
  {% endif %}
  {% set PrimaryCPGraph = PrimaryCPGraph + " => CyclingDA" %}
  {% if (RTPPInflationFactor > 0.0 and nEnsDAMembers > 1) %}
    {% set PrimaryCPGraph = PrimaryCPGraph+" => RTPPInflation" %}
  {% endif %}
  {% set PrimaryCPGraph = PrimaryCPGraph + " => CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished => CyclingFC" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        CyclingDAFinished => CleanCyclingDA" %}
{# else #}
#TODO: indicate invalid CriticalPathType
{% endif %}
# verification and extended forecast controls
{% set ExtendedFCLengths = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
{% set EnsDAMembers = range(1, nEnsDAMembers+1, 1) %}
{% set VerifyMembers = range(1, nEnsDAMembers+1, 1) %}
[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  # Maximum number of simultaneous active dates;
  # useful for constraining non-blocking flows
  # and to avoid over-utilization of login nodes
  # hint: execute 'ps aux | grep $USER' to check your login node overhead
  # default: 3
  max active cycle points = 4
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}
  [[dependencies]]
#TODO: put warm-start file copying in InitEnsFC/firstfc script
#{# if initialCyclePoint == firstCyclePoint #}
#    [[[R1]]]
#      graph = InitEnsFC => CyclingDA
#{# endif #}
## Critical path for cycling
    [[[PT${CyclingWindowHR}H]]]
      graph = '''{{PrimaryCPGraph}}{{SecondaryCPGraph}}
      '''
## Many kinds of verification
{% if CriticalPathType == "Normal" and VerifyDeterministicDA and nEnsDAMembers < 2 %}
#TODO: enable VerifyObsDA to handle more than one ensemble member
#      and use feedback files from EDA for VerifyEnsMeanBG
## Verification of deterministic DA with observations (BG+AN together)
    [[[PT${CyclingWindowHR}H]]]
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
{% if VerifyMemberBG %}
## Ensemble BG verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
        CyclingFCFinished[-PT${CyclingWindowHR}H] => HofXBG
        CyclingFCFinished[-PT${CyclingWindowHR}H] => VerifyModelBG
  {% for mem in VerifyMembers %}
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
    [[[PT${CyclingWindowHR}H]]]
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
{% if VerifyMemberAN %}
## Ensemble AN verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
  {% for mem in VerifyMembers %}
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
  {% for mem in VerifyMembers %}
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
      -S = /bin/csh
      -q = ${CYQueueName}
      -A = ${CYAccountNumber}
      -k = eod
      -l = select=1:ncpus=36:mpiprocs=36
## SLURM
#    [[[job]]]
#      batch system = slurm
#      execution time limit = PT60M
#    [[[directives]]]
#      --account = ${CYAccountNumber}
#      --mem = 45G
#      --ntasks = 1
#      --cpus-per-task = 36
#      --partition = dav
  [[HofXBase]]
    [[[job]]]
      execution time limit = PT${HofXJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${HofXNodes}:ncpus=${HofXPEPerNode}:mpiprocs=${HofXPEPerNode}:mem=${HofXMemory}GB
  [[VerifyModelBase]]
    [[[job]]]
      execution time limit = PT${VerifyModelJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${VerifyModelNodes}:ncpus=${VerifyModelPEPerNode}:mpiprocs=${VerifyModelPEPerNode}
  [[VerifyObsBase]]
    [[[job]]]
      execution time limit = PT${VerifyObsJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${VerifyObsNodes}:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
  [[CompareBase]]
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=1:ncpus=36:mpiprocs=36
  [[CleanBase]]
    [[[job]]]
      batch system = background
#Cycling components
  [[CyclingDA]]
    env-script = cd ${mainScriptDir}; ./jediPrepCyclingDA.csh "1" "0" "DA"
    script = \$origin/CyclingDA.csh
    [[[job]]]
      execution time limit = PT${CyclingDAJobMinutes}M
      execution retry delays = ${CyclingDARetry}
    [[[directives]]]
      -m = ae
      -l = select=${CyclingDANodes}:ncpus=${CyclingDAPEPerNode}:mpiprocs=${CyclingDAPEPerNode}:mem=${CyclingDAMemory}GB
  [[RTPPInflation]]
    script = \$origin/RTPPInflation.csh
    [[[job]]]
      execution time limit = PT${CyclingInflationJobMinutes}M
      execution retry delays = ${RTPPInflationRetry}
    [[[directives]]]
      -m = ae
      -l = select=${CyclingInflationNodesPerMember}:ncpus=${CyclingInflationPEPerNode}:mpiprocs=${CyclingInflationPEPerNode}:mem=${CyclingInflationMemory}GB
  [[GenerateABEInflation]]
    script = \$origin/GenerateABEInflation.csh
    [[[job]]]
      execution time limit = PT10M
    [[[directives]]]
      -q = ${CYQueueName}
      -A = ${CYAccountNumber}
      -l = select=${VerifyObsNodes}:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
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
    script = \$origin/CleanCyclingDA.csh
  [[CyclingFC]]
    [[[job]]]
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
      -m = ae
      -l = select=${CyclingFCNodes}:ncpus=${CyclingFCPEPerNode}:mpiprocs=${CyclingFCPEPerNode}
{% for mem in EnsDAMembers %}
  [[CyclingMemberFC{{mem}}]]
    inherit = CyclingFC
    script = \$origin/CyclingFC.csh "{{mem}}"
    [[[job]]]
      execution retry delays = ${CyclingFCRetry}
{% endfor %}
  [[CyclingFCFinished]]
    [[[job]]]
      batch system = background
  [[ExtendedFCBase]]
    [[[job]]]
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -m = ae
      -q = ${VFQueueName}
      -l = select=${ExtendedFCNodes}:ncpus=${ExtendedFCPEPerNode}:mpiprocs=${ExtendedFCPEPerNode}
## Extended mean analysis, forecast, and verification
  [[MeanAnalysis]]
    script = \$origin/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -m = ae
      -q = ${VFQueueName}
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
    env-script = cd ${mainScriptDir}; ./jediPrepHofXMeanFC.csh "1" "{{dt}}" "FC"
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
{% for mem in VerifyMembers %}
## Ensemble BG/AN verification
  {% for state in ['BG', 'AN']%}
  [[HofX{{state}}{{mem}}]]
    inherit = HofX{{state}}
    env-script = cd ${mainScriptDir}; ./jediPrepHofX{{state}}.csh "{{mem}}" "0" "{{state}}"
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
    env-script = cd ${mainScriptDir}; ./jediPrepHofXEnsFC.csh "{{mem}}" "{{dt}}" "FC"
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
      -q = ${VFQueueName}
  [[HofXEnsMeanBG]]
    inherit = HofXBase
    env-script = cd ${mainScriptDir}; ./jediPrepHofXEnsMeanBG.csh "1" "0" "BG"
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

cylc register ${ExperimentName} ${mainScriptDir}
cylc validate ${ExperimentName}
cylc run ${ExperimentName}

exit
