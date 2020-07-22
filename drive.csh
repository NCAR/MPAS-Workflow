#!/bin/csh

date

./MakeCyclingScripts.csh

source control.csh
cd ${mainScriptDir}

echo "Initializing ${PKGBASE}"
module purge
module load cylc
module load graphviz

rm -fr ${HOME}/cylc-run/${WholeExpName}

cat >! suite.rc << EOF
#!Jinja2
[meta]
  title = "${PKGBASE}"
  {% set ExtendedFCLengths = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
  {% set EnsDAMembers = range(1, ${nEnsDAMembers}+1, 1) %}
  {% set ExtendedFCMembers = [0] %}
[cylc]
  UTC mode = False
  [[environment]]
[scheduling]
  max active cycle points = 200
  initial cycle point = 20180415T00
  final cycle point   = 20180415T06
  [[dependencies]]
#    # Initial cycle point
    [[[R1]]]    # Run once, at the initial point.
      graph = CyclingDA => CyclingEnsFC
    [[[PT${CyclingWindowHR}H]]]
      graph = '''
      CyclingEnsFC[-PT${CyclingWindowHR}H]:succeed-all => CyclingDA => CyclingEnsFC
#      {% for mem in EnsDAMembers%}
#        CyclingDA => \
#          CalcOMAN{{mem}} \
#          & VerifyModelAN{{mem}}
#        CyclingFC{{mem}}[-PT${CyclingWindowHR}H] => \
#          CalcOMBG{{mem}} & VerifyModelBG{{mem}}
#        CalcOMAN{{mem}} => VerifyObsAN{{mem}}
#        CalcOMBG{{mem}} => VerifyObsBG{{mem}}
#      {% endfor %}
      '''
## Extended forecast from mean of analysis states
    [[[${ExtendedMeanFCTimes}]]]
      graph = '''
      CyclingDA => MeanAnalysis => ExtendedMeanFC
      {% for dt in ExtendedFCLengths%}
        ExtendedMeanFC => CalcOMMeanFC{{dt}}hr & VerifyModelMeanFC{{dt}}hr
        CalcOMMeanFC{{dt}}hr => VerifyObsMeanFC{{dt}}hr
      {% endfor %}
      '''
## Extended forecast from ensemble of analysis states
#    [[[${ExtendedEnsFCTimes}]]]
#      graph = '''
#      CyclingDA => ExtendedEnsFC
#      {% for mem in ExtendedFCMembers%}
#        {% for dt in ExtendedFCLengths%}
#          ExtendedFC{{mem}} => CalcOMEnsFC{{mem}}-{{dt}}hr & VerifyModelEnsFC{{mem}}-{{dt}}hr
#          CalcOMEnsFC{{mem}}-{{dt}}hr => VerifyObsEnsFC{{mem}}-{{dt}}hr
#        {% endfor %}
#      {% endfor %}
#      '''
[runtime]
  [[root]] # suite defaults
    pre-script = "cd  \$origin/; \$myPreScript"
    [[[environment]]]
      origin = ${mainScriptDir}
      myPreScript = ""
#Base components
## PBS
  [[JobBase]]
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
#  [[JobBase]]
#    [[[job]]]
#      batch system = slurm
#    [[[directives]]]
#      --account = ${CYAccountNumber}
#      --mem = 45G
#      --ntasks = 1
#      --cpus-per-task = 36
#      --partition = dav
  [[VerifyBase]]
    inherit = JobBase
    [[[job]]]
      execution time limit = PT15M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=1:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
  [[OMMBase]]
    inherit = JobBase
    [[[job]]]
      execution time limit = PT${CalcOMMJobMinutes}M
    [[[directives]]]
      -q = ${VFQueueName}
      -A = ${VFAccountNumber}
      -l = select=${CalcOMMNodes}:ncpus=${CalcOMMPEPerNode}:mpiprocs=${CalcOMMPEPerNode}:mem=109GB
#Cycling components
  [[CyclingDA]]
    inherit = JobBase
    script = \$origin/CyclingDA.csh
    [[[environment]]]
      myPreScript = \$origin/jediPrepCyclingDA.csh "0" "0" "DA"
    [[[job]]]
      execution time limit = PT${CyclingDAJobMinutes}M
    [[[directives]]]
      -l = select=${CyclingDANodes}:ncpus=${CyclingDAPEPerNode}:mpiprocs=${CyclingDAPEPerNode}:mem=109GB
  [[CyclingEnsFC]]
    inherit = JobBase
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
    inherit = JobBase
    [[[job]]]
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -l = select=${ExtendedFCNodes}:ncpus=${ExtendedFCPEPerNode}:mpiprocs=${ExtendedFCPEPerNode}
## Extended mean analysis, forecast, and verification
  [[MeanAnalysis]]
    inherit = JobBase
    script = \$origin/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
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

#    [[[environment]]]
#      CYCLE_POINT = \$CYLC_TASK_CYCLE_POINT
##      {% set CYCLEDATE = CYCLE_POINT %}
#      {{ CYCLE_POINT | strftime('%Y%m%d%H') }}

cylc register ${WholeExpName} ${mainScriptDir}
cylc validate ${WholeExpName}
cylc run ${WholeExpName}

exit
