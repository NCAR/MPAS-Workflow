#!/bin/csh

## Top-level workflow configuration

# Cycle bounds
set initialCyclePoint = 20180415T00
set finalCyclePoint   = 20180415T06

# CriticalPathType: controls dependencies between and chilrdren of
#                   DA and FC cycling components
# options: Normal, Bypass, Reanalysis, Reforecast
set CriticalPathType = Normal

# VerifyDeterministicDA: whether to run verification scripts for
#    obs feedback files from DA.  Does not work for ensemble DA.
# options: True/False
set VerifyDeterministicDA = True

# VerifyExtendedMeanFC: whether to run verification scripts across
#    extended forecast states, first intialized at mean analysis
# options: True/False
set VerifyExtendedMeanFC = False

# VerifyMemberBG: whether to run verification scripts for CyclingWindowHR
#    forecast length. Utilizes critical path forecast states from
#    individual ensemble member analyses or deterministic analysis
# options: True/False
set VerifyMemberBG = True

# VerifyEnsMeanBG: whether to run verification scripts for ensemble
#    mean background state.
# options: True/False
set VerifyEnsMeanBG = True

# DiagnoseEnsSpreadBG: whether to diagnose the ensemble spread in observation
#    space while VerifyEnsMeanBG is True.  Automatically triggers OMF calculation
#    for all ensemble members. VerifyEnsMeanBG is nearly free when
#    DiagnoseEnsSpreadBG is True.
#    mean background state.
# options: True/False
set DiagnoseEnsSpreadBG = True

# VerifyEnsMeanAN: whether to run verification scripts for ensemble
#    mean analysis state.
# options: True/False
set VerifyMemberAN = False

# VerifyExtendedEnsBG: whether to run verification scripts across
#    extended forecast states, first intialized at ensemble of analysis
#    states.
# options: True/False
set VerifyExtendedEnsFC = False

date

## Initialize environment and experimental configuration
source control.csh

## Initialize cycling directory if this is the first cycle point
set yymmdd = `echo ${FirstCycleDate} | cut -c 1-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
set firstCyclePoint = ${yymmdd}T${hh}
if ($initialCyclePoint == $firstCyclePoint) then
  ./SetupWorkflow.csh
endif

## Change to the cylc suite directory
cd ${mainScriptDir}

echo "Initializing ${PKGBASE}"
module purge
module load cylc
module load graphviz

rm -fr ${HOME}/cylc-run/${WholeExpName}
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
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %}
{% set VerifyMemberBG = ${VerifyMemberBG} %}
{% set VerifyEnsMeanBG = ${VerifyEnsMeanBG} %}
{% set DiagnoseEnsSpreadBG = ${DiagnoseEnsSpreadBG} %}
{% set VerifyMemberAN = ${VerifyMemberAN} %}
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %}
{% set nEnsDAMembers = ${nEnsDAMembers} %}
{% set RTPPInflationFactor = ${RTPPInflationFactor} %}
{% set ABEInflation = ${ABEInflation} %}
[meta]
  title = "${PKGBASE}--${WholeExpName}"
# critical path cycle dependencies
  {% set PrimaryCPGraph = "" %}
  {% set SecondaryCPGraph = "" %}
{% if CriticalPathType == "Bypass" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished" %}
{% elif CriticalPathType == "Reanalysis" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDA => CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished" %}
  {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        CyclingDAFinished => CleanupCyclingDA" %}
{% elif CriticalPathType == "Reforecast" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished" %}
{% else %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFCFinished[-PT${CyclingWindowHR}H]" %}
  {% if (ABEInflation and nEnsDAMembers > 1) %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => MeanBackground" %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => CalcOMEnsMeanBG" %}
    {% set PrimaryCPGraph = PrimaryCPGraph + " => GenerateABEInflation" %}
    {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        GenerateABEInflation => CleanupCalcOMEnsMeanBG" %}
  {% endif %}
  {% set PrimaryCPGraph = PrimaryCPGraph + " => CyclingDA" %}
  {% if (RTPPInflationFactor > 0.0 and nEnsDAMembers > 1) %}
    {% set PrimaryCPGraph = PrimaryCPGraph+" => RTPPInflation" %}
  {% endif %}
  {% set PrimaryCPGraph = PrimaryCPGraph + " => CyclingDAFinished" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingDAFinished => CyclingFC" %}
  {% set PrimaryCPGraph = PrimaryCPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set SecondaryCPGraph = SecondaryCPGraph + "\\n        CyclingDAFinished => CleanupCyclingDA" %}
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
  max active cycle points = 40
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
{% if VerifyDeterministicDA and nEnsDAMembers < 2 %}
#TODO: enable VerifyObsDA to handle more than one ensemble member
#      and use feedback files from EDA for VerifyEnsMeanBG
## Verification of deterministic DA with observations (BG+AN together)
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
        CyclingDAFinished => VerifyObsDA
        VerifyObsDA => CleanupCyclingDA
      '''
{% endif %}
{% if VerifyExtendedMeanFC %}
## Extended forecast and verification from mean of analysis states
    [[[${ExtendedMeanFCTimes}]]]
      graph = '''
        CyclingDAFinished => MeanAnalysis => ExtendedMeanFC
  {% for dt in ExtendedFCLengths %}
        ExtendedMeanFC => VerifyModelMeanFC{{dt}}hr
        ExtendedMeanFC => CalcOMMeanFC{{dt}}hr
        CalcOMMeanFC{{dt}}hr => VerifyObsMeanFC{{dt}}hr
        VerifyObsMeanFC{{dt}}hr => CleanupCalcOMMeanFC{{dt}}hr
  {% endfor %}
      '''
{% endif %}
{% if VerifyMemberBG %}
## Ensemble BG verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
        CyclingFCFinished[-PT${CyclingWindowHR}H] => CalcOMBG
        CyclingFCFinished[-PT${CyclingWindowHR}H] => VerifyModelBG
  {% for mem in VerifyMembers %}
        CalcOMBG{{mem}} => VerifyObsBG{{mem}}
        VerifyObsBG{{mem}} => CleanupCalcOMBG{{mem}}
  {% endfor %}
      '''
{% endif %}
{% if VerifyEnsMeanBG and nEnsDAMembers > 1 %}
## Ensemble Mean BG verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
        CyclingFCFinished[-PT${CyclingWindowHR}H] => MeanBackground
        MeanBackground => CalcOMEnsMeanBG
        MeanBackground => VerifyModelEnsMeanBG
        CalcOMEnsMeanBG => VerifyObsEnsMeanBG
        VerifyObsEnsMeanBG => CleanupCalcOMEnsMeanBG
  {% if DiagnoseEnsSpreadBG %}
        CyclingFCFinished[-PT${CyclingWindowHR}H] => CalcOMBG
        CalcOMBG:succeed-all => VerifyObsEnsMeanBG
        VerifyObsEnsMeanBG => CleanupCalcOMBG
  {% endif %}
      '''
{% endif %}
{% if VerifyMemberAN %}
## Ensemble AN verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
  {% for mem in VerifyMembers %}
        CyclingDAFinished => VerifyModelAN{{mem}}
        CyclingDAFinished => CalcOMAN{{mem}}
        CalcOMAN{{mem}} => VerifyObsAN{{mem}}
        VerifyObsAN{{mem}} => CleanupCalcOMAN{{mem}}
  {% endfor %}
      '''
{% endif %}
{% if VerifyExtendedEnsFC %}
## Extended forecast and verification from ensemble of analysis states
    [[[${ExtendedEnsFCTimes}]]]
      graph = '''
        CyclingDAFinished => ExtendedEnsFC
  {% for mem in VerifyMembers %}
    {% for dt in ExtendedFCLengths %}
        ExtendedFC{{mem}} => VerifyModelEnsFC{{mem}}-{{dt}}hr
        ExtendedFC{{mem}} => CalcOMEnsFC{{mem}}-{{dt}}hr
        CalcOMEnsFC{{mem}}-{{dt}}hr => VerifyObsEnsFC{{mem}}-{{dt}}hr
        VerifyObsEnsFC{{mem}}-{{dt}}hr => CleanupCalcOMEnsFC{{mem}}-{{dt}}hr
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
  [[OMMBase]]
    [[[job]]]
      execution time limit = PT${CalcOMMJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${CalcOMMNodes}:ncpus=${CalcOMMPEPerNode}:mpiprocs=${CalcOMMPEPerNode}:mem=${CalcOMMMemory}GB
  [[VerifyModelBase]]
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${VerifyModelNodes}:ncpus=${VerifyModelPEPerNode}:mpiprocs=${VerifyModelPEPerNode}
  [[VerifyObsBase]]
    [[[job]]]
      execution time limit = PT10M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${VerifyObsNodes}:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
  [[CleanupBase]]
    [[[job]]]
      batch system = background
#Cycling components
  [[CyclingDA]]
    env-script = cd ${mainScriptDir}; ./jediPrepCyclingDA.csh "1" "0" "DA"
    script = \$origin/CyclingDA.csh
    [[[job]]]
      execution time limit = PT${CyclingDAJobMinutes}M
      execution retry delays = 4*PT30S
    [[[directives]]]
      -m = ae
      -l = select=${CyclingDANodes}:ncpus=${CyclingDAPEPerNode}:mpiprocs=${CyclingDAPEPerNode}:mem=${CyclingDAMemory}GB
  [[RTPPInflation]]
    script = \$origin/RTPPInflation.csh
    [[[job]]]
      execution time limit = PT${CyclingInflationJobMinutes}M
      execution retry delays = 4*PT30S
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
  [[CleanupCyclingDA]]
    inherit = CleanupBase
    script = \$origin/CleanupCyclingDA.csh
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
      execution retry delays = 4*PT30S
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
{% for dt in ExtendedFCLengths %}
  [[CalcOMMeanFC{{dt}}hr]]
    inherit = OMMBase
    env-script = cd ${mainScriptDir}; ./jediPrepCalcOMMeanFC.csh "1" "{{dt}}" "FC"
    script = \$origin/CalcOMMeanFC.csh "1" "{{dt}}" "FC"
    [[[job]]]
      execution retry delays = 4*PT30S
  [[CleanupCalcOMMeanFC{{dt}}hr]]
    inherit = CleanupBase
    script = \$origin/CleanupCalcOMMeanFC.csh "1" "{{dt}}" "FC"
  [[VerifyObsMeanFC{{dt}}hr]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsMeanFC.csh "1" "{{dt}}" "FC" "0"
  [[VerifyModelMeanFC{{dt}}hr]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelMeanFC.csh "1" "{{dt}}" "FC"
{% endfor %}
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase
{% for state in ['BG', 'AN']%}
  [[CalcOM{{state}}]]
    inherit = OMMBase
  [[VerifyModel{{state}}]]
    inherit = VerifyModelBase
  [[VerifyObs{{state}}]]
    inherit = VerifyObsBase
  [[CleanupCalcOM{{state}}]]
    inherit = CleanupBase
{% endfor %}
{% for mem in VerifyMembers %}
## Ensemble BG/AN verification
  {% for state in ['BG', 'AN']%}
  [[CalcOM{{state}}{{mem}}]]
    inherit = CalcOM{{state}}
    env-script = cd ${mainScriptDir}; ./jediPrepCalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
    script = \$origin/CalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[[job]]]
      execution retry delays = 4*PT30S
  [[VerifyModel{{state}}{{mem}}]]
    inherit = VerifyModel{{state}}
    script = \$origin/VerifyModel{{state}}.csh "{{mem}}" "0" "{{state}}"
  [[VerifyObs{{state}}{{mem}}]]
    inherit = VerifyObs{{state}}
    script = \$origin/VerifyObs{{state}}.csh "{{mem}}" "0" "{{state}}" "0"
  [[CleanupCalcOM{{state}}{{mem}}]]
    inherit = CleanupCalcOM{{state}}
    script = \$origin/CleanupCalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
  {% endfor %}
## Extended ensemble forecasts and verification
  [[ExtendedFC{{mem}}]]
    inherit = ExtendedEnsFC
    script = \$origin/ExtendedEnsFC.csh "{{mem}}"
  {% for dt in ExtendedFCLengths %}
  [[CalcOMEnsFC{{mem}}-{{dt}}hr]]
    inherit = OMMBase
    env-script = cd ${mainScriptDir}; ./jediPrepCalcOMEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    script = \$origin/CalcOMEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[[job]]]
      execution retry delays = 4*PT30S
  [[VerifyModelEnsFC{{mem}}-{{dt}}hr]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelEnsFC.csh "{{mem}}" "{{dt}}" "FC"
  [[VerifyObsEnsFC{{mem}}-{{dt}}hr]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsEnsFC.csh "{{mem}}" "{{dt}}" "FC" "0"
  [[CleanupCalcOMEnsFC{{mem}}-{{dt}}hr]]
    inherit = CleanupBase
    script = \$origin/CleanupCalcOMEnsFC.csh "{{mem}}" "{{dt}}" "FC"
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
  [[CalcOMEnsMeanBG]]
    inherit = OMMBase
    env-script = cd ${mainScriptDir}; ./jediPrepCalcOMEnsMeanBG.csh "1" "0" "BG"
    script = \$origin/CalcOMEnsMeanBG.csh "1" "0" "BG"
    [[[directives]]]
      -q = ${EnsMeanBGQueueName}
      -A = ${EnsMeanBGAccountNumber}
    [[[job]]]
      execution retry delays = 4*PT30S
  [[VerifyModelEnsMeanBG]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelEnsMeanBG.csh "1" "0" "BG"
  [[VerifyObsEnsMeanBG]]
    inherit = VerifyObsBase
{% if DiagnoseEnsSpreadBG %}
    script = \$origin/VerifyObsEnsMeanBG.csh "1" "0" "BG" "{{nEnsDAMembers}}"
{% else %}
    script = \$origin/VerifyObsEnsMeanBG.csh "1" "0" "BG" "0"
{% endif %}
  [[CleanupCalcOMEnsMeanBG]]
    inherit = CleanupBase
    script = \$origin/CleanupCalcOMEnsMeanBG.csh "1" "0" "BG"
[visualization]
  initial cycle point = {{initialCyclePoint}}
  final cycle point   = {{finalCyclePoint}}
  number of cycle points = 200
  default node attributes = "style=filled", "fillcolor=grey"
EOF

cylc register ${WholeExpName} ${mainScriptDir}
cylc validate ${WholeExpName}
cylc run ${WholeExpName}

exit
