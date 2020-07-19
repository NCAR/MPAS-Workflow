#!/bin/csh

./MakeCyclingScripts.csh

source control.csh
cd ${MAIN_SCRIPT_DIR}

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
  final cycle point   = 20180415T00
  [[dependencies]]
#    # Initial cycle point
    [[[R1]]]    # Run once, at the initial point.
      graph = CyclingDA => CyclingEnsFC
    [[[PT${CYWindowHR}H]]]
      graph = '''
      CyclingEnsFC[-PT${CYWindowHR}H]:succeed-all => CyclingDA => CyclingEnsFC
      {% for mem in EnsDAMembers%}
        CyclingDA => CalculateOMAN{{mem}} & VerifyModelAN{{mem}}
        CyclingFC{{mem}}[-PT${CYWindowHR}H] => CalculateOMBG{{mem}} & VerifyModelBG{{mem}}
        CalculateOMAN{{mem}} => VerifyObsAN{{mem}}
        CalculateOMBG{{mem}} => VerifyObsBG{{mem}}
      {% endfor %}
      '''
#    [[[${ExtendedFCTimes}]]]
#      graph = '''
#      {% for mem in ExtendedFCMembers%}
#        CyclingDA => ExtendedFC{{mem}}
#        {% for dt in ExtFChrs%}
#          ExtendedFC{{mem}} => CalculateOMF{{mem}}-{{dt}}hr & VerifyModelAN{{mem}}-{{dt}}hr
#          CalculateOMFC{{mem}} => VerifyObsFC{{mem}}
#        {% endfor %}
#      {% endfor %}
#      '''
[runtime]
  [[root]] # suite defaults
    pre-script = "cd  ${MAIN_SCRIPT_DIR}/"
#Base components
  [[CyclingBasePBS]]
    [[[job]]]
      batch system = pbs
    [[[directives]]]
      -j = oe
      -S = /bin/csh
      -q = ${CYQueueName}
      -A = ${CYAccountNumber}
#  [[CyclingBaseSLURM]]
#    [[[job]]]
#      batch system = slurm
#      execution time limit = PT25M
#    [[[directives]]]
#      --account=${CYAccountNumber}
#      --mem=109G
#      --ntasks=${CyclingDANodes}
#      --cpus-per-task=${CyclingDAPEPerNode}
#      --partition=dav
  [[VerifyBase]]
    [[[job]]]
      batch system = pbs
      execution time limit = PT15M
      [[[directives]]]
        -j = oe
        -S = /bin/csh
        -l = select=${VerifyObsNodes}:ncpus=${VerifyObsPEPerNode}:mpiprocs=${VerifyObsPEPerNode}
        -q = ${VFQueueName}
        -A = ${VFAccountNumber}
  [[OMMBase]]
    [[[job]]]
      batch system = pbs
      execution time limit = PT10M
      [[[directives]]]
        -j = oe
        -S = /bin/csh
        -l = select=${OMMNodes}:ncpus=${OMMPEPerNode}:mpiprocs=${OMMPEPerNode}
        -q = ${VFQueueName}
        -A = ${VFAccountNumber}
#Actual components
  [[CyclingDA]]
    inherit = CyclingBasePBS
    pre-script = cd ${MAIN_SCRIPT_DIR}; ${MAIN_SCRIPT_DIR}/jediPrepCyclingDA.csh "0" "0" "DA"
    script = ${MAIN_SCRIPT_DIR}/CyclingDA.csh
    [[[job]]]
      execution time limit = PT25M
    [[[directives]]]
      -l = select=${CyclingDANodes}:ncpus=${CyclingDAPEPerNode}:mpiprocs=${CyclingDAPEPerNode}:mem=109GB
  [[CyclingEnsFC]]
    inherit = CyclingBasePBS
    script = ${MAIN_SCRIPT_DIR}/CyclingFC.csh "\$Member"
    [[[job]]]
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
      -l = select=4:ncpus=32:mpiprocs=32
{% for mem in EnsDAMembers%}
  [[CyclingFC{{mem}}]]
    inherit = CyclingEnsFC
    [[[environment]]]
      Member = {{mem}}
{% endfor %}
{% for state in ['BG', 'AN']%}
  {% for mem in EnsDAMembers%}
    [[CalculateOM{{state}}{{mem}}]]
      inherit = OMMBase
      pre-script = cd ${MAIN_SCRIPT_DIR}; ${MAIN_SCRIPT_DIR}/jediPrepCalculateOM{{state}}.csh "{{mem}}" "0" "{{state}}"
      script = ${MAIN_SCRIPT_DIR}/CalculateOM{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[VerifyObs{{state}}{{mem}}]]
      inherit = VerifyBase
      script = ${MAIN_SCRIPT_DIR}/VerifyObs{{state}}.csh "{{mem}}" "0" "{{state}}"
    [[VerifyModel{{state}}{{mem}}]]
      inherit = VerifyBase
      script = ${MAIN_SCRIPT_DIR}/VerifyModel{{state}}.csh "{{mem}}" "0" "{{state}}"
  {% endfor %}
{% endfor %}
{% for mem in ExtendedFCMembers%}
  [[ExtendedFC{{mem}}]]
    inherit = CyclingBasePBS
    script = ${MAIN_SCRIPT_DIR}/ExtendedFC.csh "{{mem}}"
    [[[job]]]
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -l = select=4:ncpus=32:mpiprocs=32
  {% for dt in ExtFChrs %}
    [[CalculateOMFC{{mem}}-{{dt}}hr]]
      inherit = OMMBase
      pre-script = cd ${MAIN_SCRIPT_DIR}; ${MAIN_SCRIPT_DIR}/jediPrepCalculateOMFC.csh "{{mem}}" "{{dt}}" "FC"
      script = ${MAIN_SCRIPT_DIR}/CalculateOMFC.csh "{{mem}}" "{{dt}}" "FC"
    [[VerifyObsFC{{mem}}-{{dt}}hr]]
      inherit = VerifyBase
      script = ${MAIN_SCRIPT_DIR}/VerifyObsFC.csh "{{mem}}" "{{dt}}" "FC"
    [[VerifyModelFC{{mem}}-{{dt}}hr]]
      inherit = VerifyBase
      script = ${MAIN_SCRIPT_DIR}/VerifyModelFC.csh "{{mem}}" "{{dt}}" "FC"
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

cylc register ${WholeExpName} ${MAIN_SCRIPT_DIR}
cylc validate ${WholeExpName}
cylc run ${WholeExpName}

exit
