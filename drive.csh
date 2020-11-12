#!/bin/csh

date

source control.csh

## Top-level workflow controls
# CriticalPathType: controls dependcies between and chilrdren of
#                   DA and FC cycling components
# options: Normal, Bypass, Reanalysis, Reforecast
set CriticalPathType = Normal
set VerifyOnly = False
set VerifyDeterministicDA = False
set VerifyExtendedMeanFC = False
set VerifyMemberBG = False
set VerifyEnsMeanBG = False
set VerifyMemberAN = False
set VerifyExtendedEnsFC = False

## Cycle bounds
set initialCyclePoint = 20180415T00
set finalCyclePoint   = 20180415T12

## Initialize cycling directory if this is the first cycle point
set yymmdd = `echo ${FirstCycleDate} | cut -c 1-8`
set hh = `echo ${FirstCycleDate} | cut -c 9-10`
set firstCyclePoint = ${yymmdd}T${hh}
if ($initialCyclePoint == $firstCyclePoint) then
  ./MakeCyclingScripts.csh
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
{% set VerifyOnly = ${VerifyOnly} %}
{% if VerifyOnly %}
  {% set CriticalPathType = "Bypass" %}
{% endif %}
{% set VerifyDeterministicDA = ${VerifyDeterministicDA} %}
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %}
{% set VerifyMemberBG = ${VerifyMemberBG} %}
{% set VerifyEnsMeanBG = ${VerifyEnsMeanBG} %}
{% set VerifyMemberAN = ${VerifyMemberAN} %}
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %}
{% set nEnsDAMembers = ${nEnsDAMembers} %}
{% set RTPPInflationFactor = ${RTPPInflationFactor} %}
[meta]
  title = "${PKGBASE}--${WholeExpName}"
# critical path cycle dependencies
  {% set CPGraph = "" %}
{% if CriticalPathType == "Bypass" %}
  {% set CPGraph = CPGraph + "\\n        CyclingDAFinished" %}
  {% set CPGraph = CPGraph + "\\n        CyclingFCFinished" %}
{% elif CriticalPathType == "Reanalysis" %}
  {% set CPGraph = CPGraph + "\\n        CyclingDA => CyclingDAFinished" %}
  {% set CPGraph = CPGraph + "\\n        CyclingFCFinished" %}
{% elif CriticalPathType == "Reforecast" %}
  {% set CPGraph = CPGraph + "\\n        CyclingFC" %}
  {% set CPGraph = CPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
  {% set CPGraph = CPGraph + "\\n        CyclingDAFinished" %}
{% else %}
  {% set CPGraph = CPGraph + "\\n        CyclingFCFinished[-PT${CyclingWindowHR}H] => CyclingDA" %}
  {% if (nEnsDAMembers > 1 and RTPPInflationFactor > 0.0) %}
    {% set CPGraph = CPGraph+" => RTPPInflation" %}
  {% endif %}
  {% set CPGraph = CPGraph + " => CyclingDAFinished" %}
  {% set CPGraph = CPGraph + "\\n        CyclingDAFinished => CyclingFC" %}
  {% set CPGraph = CPGraph + "\\n        CyclingFC:succeed-all => CyclingFCFinished" %}
{% endif %}
# verification and extended forecast controls
{% set ExtendedFCLengths = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
{% set EnsDAMembers = range(1, nEnsDAMembers+1, 1) %}
{% set VerifyMembers = range(1, nEnsDAMembers+1, 1) %}
[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  max active cycle points = 200
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
      graph = '''{{CPGraph}}
      '''
## Many kinds of verification
{% if VerifyDeterministicDA and nEnsDAMembers < 2 %}
#TODO: enable VerifyObsDA to handle more than one ensemble member
#      and use feedback files from EDA for VerifyEnsMeanBG
## Verification of deterministic DA with observations (BG+AN)
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
  {% if not VerifyOnly %}
        CyclingDAFinished => MeanAnalysis => ExtendedMeanFC
    {% for dt in ExtendedFCLengths %}
        ExtendedMeanFC => VerifyModelMeanFC{{dt}}hr
        ExtendedMeanFC => CalcOMMeanFC{{dt}}hr
        CalcOMMeanFC{{dt}}hr => VerifyObsMeanFC{{dt}}hr
        VerifyObsMeanFC{{dt}}hr => CleanupCalcOMMeanFC{{dt}}hr
    {% endfor %}
  {% else %}
    {% for dt in ExtendedFCLengths %}
        VerifyModelMeanFC{{dt}}hr
        VerifyObsMeanFC{{dt}}hr
    {% endfor %}
  {% endif %}
      '''
{% endif %}
{% if (VerifyMemberBG or (VerifyEnsMeanBG and nEnsDAMembers > 1)) and not VerifyOnly%}
## Ensemble BG verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
        CyclingFCFinished[-PT${CyclingWindowHR}H] => CalcOMBG
      '''
{% endif %}
{% if VerifyMemberBG %}
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
  {% if not VerifyOnly %}
        CyclingFCFinished[-PT${CyclingWindowHR}H] => VerifyModelBG
    {% for mem in VerifyMembers %}
        CalcOMBG{{mem}} => VerifyObsBG{{mem}}
        VerifyObsBG{{mem}} => CleanupCalcOMBG{{mem}}
    {% endfor %}
  {% else %}
        VerifyModelBG
        VerifyObsBG
  {% endif %}
      '''
{% endif %}
{% if VerifyEnsMeanBG and nEnsDAMembers > 1 %}
## Obs-space verification of mean background
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
  {% if not VerifyOnly %}
        CyclingFCFinished[-PT${CyclingWindowHR}H] => MeanBackground
        MeanBackground => CalcOMEnsMeanBG
        CalcOMBG:succeed-all & CalcOMEnsMeanBG => VerifyObsEnsMeanBG
        VerifyObsEnsMeanBG => CleanupCalcOMEnsMeanBG
        VerifyObsEnsMeanBG => CleanupCalcOMBG
  {% else %}
        VerifyObsEnsMeanBG
  {% endif %}
      '''
{% endif %}
{% if VerifyMemberAN %}
## Ensemble AN verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
  {% for mem in VerifyMembers %}
    {% if not VerifyOnly %}
        CyclingDAFinished => VerifyModelAN{{mem}}
        CyclingDAFinished => CalcOMAN{{mem}}
        CalcOMAN{{mem}} => VerifyObsAN{{mem}}
        VerifyObsAN{{mem}} => CleanupCalcOMAN{{mem}}
    {% else %}
        VerifyModelAN{{mem}}
        VerifyObsAN{{mem}}
    {% endif %}
  {% endfor %}
      '''
{% endif %}
{% if VerifyExtendedEnsFC %}
## Extended forecast and verification from ensemble of analysis states
    [[[${ExtendedEnsFCTimes}]]]
      graph = '''
  {% if not VerifyOnly %}
        CyclingDAFinished => ExtendedEnsFC
    {% for mem in VerifyMembers %}
      {% for dt in ExtendedFCLengths %}
        ExtendedFC{{mem}} => VerifyModelEnsFC{{mem}}-{{dt}}hr
        ExtendedFC{{mem}} => CalcOMEnsFC{{mem}}-{{dt}}hr
        CalcOMEnsFC{{mem}}-{{dt}}hr => VerifyObsEnsFC{{mem}}-{{dt}}hr
        VerifyObsEnsFC{{mem}}-{{dt}}hr => CleanupCalcOMEnsFC{{mem}}-{{dt}}hr
      {% endfor %}
    {% endfor %}
  {% else %}
    {% for mem in VerifyMembers %}
      {% for dt in ExtendedFCLengths %}
        VerifyModelEnsFC{{mem}}-{{dt}}hr
        VerifyObsEnsFC{{mem}}-{{dt}}hr
      {% endfor %}
    {% endfor %}
  {% endif %}
      '''
{% endif %}
[runtime]
#Base components
  [[root]] # suite defaults
    pre-script = "cd  \$origin/; \$myPreScript"
    [[[environment]]]
      origin = ${mainScriptDir}
      myPreScript = ""
## PBS
    [[[job]]]
      batch system = pbs
      execution time limit = PT60M
    [[[directives]]]
      -j = oe
      -S = /bin/csh
      -q = ${CYQueueName}
      -A = ${CYAccountNumber}
      -m = ae
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
    script = \$origin/CyclingDA.csh
    [[[environment]]]
      myPreScript = \$origin/jediPrepCyclingDA.csh "0" "0" "DA"
    [[[job]]]
      execution time limit = PT${CyclingDAJobMinutes}M
    [[[directives]]]
      -l = select=${CyclingDANodes}:ncpus=${CyclingDAPEPerNode}:mpiprocs=${CyclingDAPEPerNode}:mem=${CyclingDAMemory}GB
  [[RTPPInflation]]
    script = \$origin/RTPPInflation.csh
    [[[job]]]
      execution time limit = PT${CyclingInflationJobMinutes}M
    [[[directives]]]
      -l = select=${CyclingInflationNodesPerMember}:ncpus=${CyclingInflationPEPerNode}:mpiprocs=${CyclingInflationPEPerNode}:mem=${CyclingInflationMemory}GB
  [[CyclingDAFinished]]
    [[[job]]]
      batch system = background
  [[VerifyObsDA]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsDA.csh "0" "0" "DA" "0"
  [[CleanupCyclingDA]]
    inherit = CleanupBase
    script = \$origin/CleanupCyclingDA.csh
  [[CyclingFC]]
    [[[job]]]
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
      -l = select=${CyclingFCNodes}:ncpus=${CyclingFCPEPerNode}:mpiprocs=${CyclingFCPEPerNode}
{% for mem in EnsDAMembers %}
  [[CyclingMemberFC{{mem}}]]
    inherit = CyclingFC
    script = \$origin/CyclingFC.csh "{{mem}}"
{% endfor %}
  [[CyclingFCFinished]]
    [[[job]]]
      batch system = background
  [[ExtendedFCBase]]
    [[[job]]]
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -l = select=${ExtendedFCNodes}:ncpus=${ExtendedFCPEPerNode}:mpiprocs=${ExtendedFCPEPerNode}
## Extended mean analysis, forecast, and verification
  [[MeanAnalysis]]
    script = \$origin/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -q = ${VFQueueName}
  [[ExtendedMeanFC]]
    inherit = ExtendedFCBase
    script = \$origin/ExtendedMeanFC.csh "0"
{% for dt in ExtendedFCLengths %}
  [[CalcOMMeanFC{{dt}}hr]]
    inherit = OMMBase
    script = \$origin/CalcOMMeanFC.csh "0" "{{dt}}" "FC"
    [[[environment]]]
      myPreScript = \$origin/jediPrepCalcOMMeanFC.csh "0" "{{dt}}" "FC"
  [[CleanupCalcOMMeanFC{{dt}}hr]]
    inherit = CleanupBase
    script = \$origin/CleanupCalcOMMeanFC.csh "0" "{{dt}}" "FC"
  [[VerifyObsMeanFC{{dt}}hr]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsMeanFC.csh "0" "{{dt}}" "FC" "0"
  [[VerifyModelMeanFC{{dt}}hr]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelMeanFC.csh "0" "{{dt}}" "FC"
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
    script = \$origin/CalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[[environment]]]
      myPreScript = \$origin/jediPrepCalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
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
    script = \$origin/CalcOMEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[[environment]]]
      myPreScript = \$origin/jediPrepCalcOMEnsFC.csh "{{mem}}" "{{dt}}" "FC"
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
      -q = ${VFQueueName}
  [[CalcOMEnsMeanBG]]
    inherit = OMMBase
    script = \$origin/CalcOMEnsMeanBG.csh "0" "0" "BG"
    [[[environment]]]
      myPreScript = \$origin/jediPrepCalcOMEnsMeanBG.csh "0" "0" "BG"
  [[VerifyModelEnsMeanBG]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelEnsMeanBG.csh "0" "0" "BG"
  [[VerifyObsEnsMeanBG]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsEnsMeanBG.csh "0" "0" "BG" "{{nEnsDAMembers}}"
  [[CleanupCalcOMEnsMeanBG]]
    inherit = CleanupBase
    script = \$origin/CleanupCalcOMEnsMeanBG.csh "0" "0" "BG"
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
