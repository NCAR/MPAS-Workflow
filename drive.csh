#!/bin/csh

date

source control.csh

## Top-level workflow controls
set RunCriticalPath = True
set VerifyOnly = False
set VerifyExtendedMeanFC = True
set VerifyEnsBGAN = False
set VerifyExtendedEnsFC = False

## Cycle bounds
set initialCyclePoint = 20180418T06
set finalCyclePoint   = 20180425T00

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
{% set RunCriticalPath = ${RunCriticalPath} %}
{% set VerifyOnly = ${VerifyOnly} %}
{% set VerifyExtendedMeanFC = ${VerifyExtendedMeanFC} %}
{% set VerifyEnsBGAN = ${VerifyEnsBGAN} %}
{% set VerifyExtendedEnsFC = ${VerifyExtendedEnsFC} %}
#TODO: put warm-start file copying in InitEnsFC/firstfc script
{# set firstCyclePoint = "${firstCyclePoint}" #}
{% set initialCyclePoint = "${initialCyclePoint}" %}
{% set finalCyclePoint = "${finalCyclePoint}" %}
{% if VerifyOnly %}
  {% set RunCriticalPath = False %}
{% endif %}
{% set nEnsDAMembers = ${nEnsDAMembers} %}
{% set RTPPInflationFactor = ${RTPPInflationFactor} %}
{% set CriticalPath = "" %}
{% set CriticalPath = CriticalPath+"CyclingEnsFC[-PT${CyclingWindowHR}H]:succeed-all => CyclingDA" %}
{% if (nEnsDAMembers > 1 and RTPPInflationFactor > 0.0) %}
  {% set CriticalPath = CriticalPath+" => RTPPInflation" %}
{% endif %}
{% set CriticalPath = CriticalPath+" => CyclingDAFinished => CyclingEnsFC" %}
[meta]
  title = "${PKGBASE}--${WholeExpName}"
  {% set ExtendedFCLengths = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
  {% set EnsDAMembers = range(1, nEnsDAMembers+1, 1) %}
  {% set VerifyMembers = range(1, nEnsDAMembers+1, 3) %}
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
{% if RunCriticalPath %}
## Critical path for cycling
    [[[PT${CyclingWindowHR}H]]]
      graph = {{CriticalPath}}
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
    {% endfor %}
  {% else %}
    {% for dt in ExtendedFCLengths %}
        VerifyModelMeanFC{{dt}}hr
        VerifyObsMeanFC{{dt}}hr
    {% endfor %}
  {% endif %}
      '''
{% endif %}
{% if VerifyEnsBGAN %}
## Ensemble BG/AN verification
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
  {% for mem in VerifyMembers %}
    {% if not VerifyOnly %}
        CyclingDAFinished => VerifyModelAN{{mem}}
        CyclingDAFinished => CalcOMAN{{mem}}
        CalcOMAN{{mem}} => VerifyObsAN{{mem}}
        CyclingFC{{mem}}[-PT${CyclingWindowHR}H] => VerifyModelBG{{mem}}
        CyclingFC{{mem}}[-PT${CyclingWindowHR}H] => CalcOMBG{{mem}}
        CalcOMBG{{mem}} => VerifyObsBG{{mem}}
    {% else %}
        VerifyModelAN{{mem}}
        VerifyModelBG{{mem}}
        VerifyObsAN{{mem}}
        VerifyObsBG{{mem}}
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
  [[VerifyModelBase]]
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${VerifyModelNodes}:ncpus=${VerifyModelPEPerNode}:mpiprocs=${VerifyModelPEPerNode}
  [[OMMBase]]
    [[[job]]]
      execution time limit = PT${CalcOMMJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${CalcOMMNodes}:ncpus=${CalcOMMPEPerNode}:mpiprocs=${CalcOMMPEPerNode}:mem=109GB
  [[VerifyObsBase]]
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${VerifyObsNodes}:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
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
  [[CyclingEnsFC]]
    [[[job]]]
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
      -l = select=${CyclingFCNodes}:ncpus=${CyclingFCPEPerNode}:mpiprocs=${CyclingFCPEPerNode}
{% for mem in EnsDAMembers %}
  [[CyclingFC{{mem}}]]
    inherit = CyclingEnsFC
    script = \$origin/CyclingFC.csh "{{mem}}"
{% endfor %}
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
  [[VerifyObsMeanFC{{dt}}hr]]
    inherit = VerifyObsBase
    script = \$origin/VerifyObsMeanFC.csh "0" "{{dt}}" "FC"
  [[VerifyModelMeanFC{{dt}}hr]]
    inherit = VerifyModelBase
    script = \$origin/VerifyModelMeanFC.csh "0" "{{dt}}" "FC"
{% endfor %}
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase
{% for mem in VerifyMembers %}
## Ensemble BG/AN verification
  {% for state in ['BG', 'AN']%}
    [[CalcOM{{state}}{{mem}}]]
      inherit = OMMBase
      script = \$origin/CalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
      [[[environment]]]
        myPreScript = \$origin/jediPrepCalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[VerifyObs{{state}}{{mem}}]]
      inherit = VerifyObsBase
      script = \$origin/VerifyObs{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[VerifyModel{{state}}{{mem}}]]
      inherit = VerifyModelBase
      script = \$origin/VerifyModel{{state}}.csh "{{mem}}" "0" "{{state}}"
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
    [[VerifyObsEnsFC{{mem}}-{{dt}}hr]]
      inherit = VerifyObsBase
      script = \$origin/VerifyObsEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[VerifyModelEnsFC{{mem}}-{{dt}}hr]]
      inherit = VerifyModelBase
      script = \$origin/VerifyModelEnsFC.csh "{{mem}}" "{{dt}}" "FC"
  {% endfor %}
{% endfor %}
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
