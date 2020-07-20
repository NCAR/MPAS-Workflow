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
  {% set ExtFChrs = range(0, ${ExtendedFCWindowHR}+${ExtendedFC_DT_HR}, ${ExtendedFC_DT_HR}) %}
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
    [[[PT${CYWindowHR}H]]]
      graph = '''
      CyclingEnsFC[-PT${CYWindowHR}H]:succeed-all => CyclingDA => CyclingEnsFC
      {% for mem in EnsDAMembers%}
        CyclingDA => \
          CalcOMAN{{mem}} \
          & VerifyModelAN{{mem}}
        CyclingFC{{mem}}[-PT${CYWindowHR}H] => \
          CalcOMBG{{mem}} & VerifyModelBG{{mem}}
        CalcOMAN{{mem}} => VerifyObsAN{{mem}}
        CalcOMBG{{mem}} => VerifyObsBG{{mem}}
      {% endfor %}
      '''
#    [[[${ExtendedFCTimes}]]]
#      graph = '''
#      CyclingDA => ExtendedEnsFC
#      {% for mem in ExtendedFCMembers%}
#        {% for dt in ExtFChrs%}
#          ExtendedFC{{mem}} => CalcOMF{{mem}}-{{dt}}hr & VerifyModelAN{{mem}}-{{dt}}hr
#          CalcOMFC{{mem}} => VerifyObsFC{{mem}}
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
  [[ExtendedEnsFC]]
    inherit = JobBase
    [[[job]]]
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -l = select=${ExtendedFCNodes}:ncpus=${ExtendedFCPEPerNode}:mpiprocs=${ExtendedFCPEPerNode}
{% for mem in ExtendedFCMembers%}
  [[ExtendedFC{{mem}}]]
    inherit = ExtendedEnsFC
    script = \$origin/ExtendedFC.csh "{{mem}}"
  {% for dt in ExtFChrs %}
    [[CalcOMFC{{mem}}-{{dt}}hr]]
      inherit = OMMBase
      script = \$origin/CalcOMFC.csh "{{mem}}" "{{dt}}" "FC"
      [[[environment]]]
        myPreScript = \$origin/jediPrepCalcOMFC.csh "{{mem}}" "0" "FC"
    [[VerifyObsFC{{mem}}-{{dt}}hr]]
      inherit = VerifyBase
      script = \$origin/VerifyObsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[VerifyModelFC{{mem}}-{{dt}}hr]]
      inherit = VerifyBase
      script = \$origin/VerifyModelFC.csh "{{mem}}" "{{dt}}" "FC"
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
