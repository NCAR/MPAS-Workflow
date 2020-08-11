#!/bin/csh

date

./MakeCyclingScripts.csh

source control.csh
cd ${mainScriptDir}

echo "Initializing ${PKGBASE}"
module purge
module load cylc
module load graphviz

## CriticalPath
set CriticalPath = "CyclingEnsFC[-PT${CyclingWindowHR}H]:succeed-all => CyclingDA =>"
set CyclingDAFinished = "CyclingDA =>"
if ($nEnsDAMembers > 1) then
  set CyclingDAFinished = "RTPPInflation =>"
  set CriticalPath = "$CriticalPath ${CyclingDAFinished}"
endif
set CriticalPath = "$CriticalPath CyclingEnsFC"

#set CriticalPath = \
#'''    [[[PT'${CyclingWindowHR}'H]]]
#      graph = '${CriticalPath}'
#'''

## Verification
#set CyclingDAFinished = ""
#set CriticalPath = ""

rm -fr ${HOME}/cylc-run/${WholeExpName}
echo "creating suite.rc"
cat >! suite.rc << EOF
#!Jinja2
[meta]
  title = "${PKGBASE}--${WholeExpName}"
  {% set ExtendedFCLengths = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
  {% set EnsDAMembers = range(1, ${nEnsDAMembers}+1, 1) %}
  {% set ExtendedFCMembers = [0] %}
[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  max active cycle points = 200
  initial cycle point = 20180415T00
  final cycle point   = 20180418T00
  [[dependencies]]
## Initial cycle point
#    [[[R1]]]
#      graph = MakeScripts => CyclingDA
## Cycling every CyclingWindowHR
    [[[PT${CyclingWindowHR}H]]]
      graph = ${CriticalPath}
### BG/AN verification (all members)
#    [[[PT${CyclingWindowHR}H]]]
#      graph = '''
#      {% for mem in EnsDAMembers%}
#        ${CyclingDAFinished}VerifyModelAN{{mem}}
#        ${CyclingDAFinished}CalcOMAN{{mem}}
#        CalcOMAN{{mem}} => VerifyObsAN{{mem}}
#        CyclingFC{{mem}}[-PT${CyclingWindowHR}H] => VerifyModelBG{{mem}}
#        CyclingFC{{mem}}[-PT${CyclingWindowHR}H] => CalcOMBG{{mem}}
#        CalcOMBG{{mem}} => VerifyObsBG{{mem}}
#      {% endfor %}
#      '''
## Extended forecast and verification from mean of analysis states
    [[[${ExtendedMeanFCTimes}]]]
      graph = '''
      ${CyclingDAFinished}MeanAnalysis => ExtendedMeanFC
      {% for dt in ExtendedFCLengths%}
        ExtendedMeanFC => VerifyModelMeanFC{{dt}}hr
        ExtendedMeanFC => CalcOMMeanFC{{dt}}hr
        VerifyModelMeanFC{{dt}}hr
        CalcOMMeanFC{{dt}}hr => VerifyObsMeanFC{{dt}}hr
      {% endfor %}
      '''
## Extended forecast and verification from ensemble of analysis states
#    [[[${ExtendedEnsFCTimes}]]]
#      graph = '''
#      ${CyclingDAFinished}ExtendedEnsFC
#      {% for mem in ExtendedFCMembers%}
#        {% for dt in ExtendedFCLengths%}
#          ExtendedFC{{mem}} => VerifyModelEnsFC{{mem}}-{{dt}}hr
#          ExtendedFC{{mem}} => CalcOMEnsFC{{mem}}-{{dt}}hr
#          CalcOMEnsFC{{mem}}-{{dt}}hr => VerifyObsEnsFC{{mem}}-{{dt}}hr
#        {% endfor %}
#      {% endfor %}
#      '''
### Verification every CyclingWindowHR
#    [[[PT${CyclingWindowHR}H]]]
#      graph = '''
#      {% for mem in EnsDAMembers%}
#        VerifyModelAN{{mem}}
#        VerifyModelBG{{mem}}
#        VerifyObsAN{{mem}}
#        VerifyObsBG{{mem}}
#      {% endfor %}
#      '''
### Verification at mean of analysis states
#    [[[${ExtendedMeanFCTimes}]]]
#      graph = '''
#      {% for dt in ExtendedFCLengths%}
#        VerifyModelMeanFC{{dt}}hr
#        VerifyObsMeanFC{{dt}}hr
#      {% endfor %}
#      '''
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
  [[VerifyBase]]
    [[[job]]]
      execution time limit = PT15M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=1:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
  [[OMMBase]]
    [[[job]]]
      execution time limit = PT${CalcOMMJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${CalcOMMNodes}:ncpus=${CalcOMMPEPerNode}:mpiprocs=${CalcOMMPEPerNode}:mem=109GB
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
  [[CyclingEnsFC]]
    [[[job]]]
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
      -l = select=${CyclingFCNodes}:ncpus=${CyclingFCPEPerNode}:mpiprocs=${CyclingFCPEPerNode}
{% for mem in EnsDAMembers%}
  [[CyclingFC{{mem}}]]
    inherit = CyclingEnsFC
    script = \$origin/CyclingFC.csh "{{mem}}"
{% endfor %}
{% for state in ['BG', 'AN']%}
  {% for mem in EnsDAMembers%}
    [[CalcOM{{state}}{{mem}}]]
      inherit = OMMBase
      script = \$origin/CalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
      [[[environment]]]
        myPreScript = \$origin/jediPrepCalcOM{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[VerifyObs{{state}}{{mem}}]]
      inherit = VerifyBase
      script = \$origin/VerifyObs{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[VerifyModel{{state}}{{mem}}]]
      inherit = VerifyBase
      script = \$origin/VerifyModel{{state}}.csh "{{mem}}" "0" "{{state}}"
  {% endfor %}
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
    inherit = VerifyBase
    script = \$origin/VerifyObsMeanFC.csh "0" "{{dt}}" "FC"
  [[VerifyModelMeanFC{{dt}}hr]]
    inherit = VerifyBase
    script = \$origin/VerifyModelMeanFC.csh "0" "{{dt}}" "FC"
{% endfor %}
## Extended ensemble forecasts and verification
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase
{% for mem in ExtendedFCMembers%}
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
      inherit = VerifyBase
      script = \$origin/VerifyObsEnsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[VerifyModelEnsFC{{mem}}-{{dt}}hr]]
      inherit = VerifyBase
      script = \$origin/VerifyModelEnsFC.csh "{{mem}}" "{{dt}}" "FC"
  {% endfor %}
{% endfor %}
[visualization]
  initial cycle point = 20180415T00
  final cycle point   = 20180415T00
  number of cycle points = 20
  default node attributes = "style=filled", "fillcolor=grey"
EOF

cylc register ${WholeExpName} ${mainScriptDir}
cylc validate ${WholeExpName}
cylc run ${WholeExpName}

exit
