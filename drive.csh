#!/bin/csh

./MakeCyclingScripts.csh

source control.csh
cd ${MAIN_SCRIPT_DIR}

echo "test cylc setup" 
module purge
module load cylc
module load graphviz

rm -fr ${HOME}/cylc-run/${WholeExpName}
mkdir /glade/scratch/${USER}/pandac/cylc-run_${WholeExpName}

cat >! suite.rc << EOF
#!Jinja2
[meta]
  title = "MPAS-Workflow"
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
      {% for mem in EnsDAMembers%}
        graph = CyclingDA => CyclingFC{{mem}}
      {% endfor %}
    [[[PT${CYWindowHR}H]]]
      graph = '''
      {% for mem in EnsDAMembers%}
        CyclingFC{{mem}}[-PT${CYWindowHR}H] => CyclingDA => CyclingFC{{mem}}
        CyclingDA => CalculateOMA{{mem}} & VerifyModelAN{{mem}}
        CalculateOMA{{mem}} => VerifyObsAN{{mem}}
        CyclingFC{{mem}}[-PT${CYWindowHR}H] => CalculateOMBG{{mem}} & VerifyModelBG{{mem}}
        CalculateOMBG{{mem}} => VerifyObsBG{{mem}}
      {% endfor %}
      '''
#    [[[${ExtendedFCTimes}]]]
#      graph = '''
#      {% for mem in ExtendedFCMembers%}
#        CyclingDA => ExtendedFC{{mem}}
#        {% for dt in ExtFChrs%}
#          ExtendedFC{{mem}} => CalculateOMF{{mem}}-{{dt}}hr
#        {% endfor %}
#      {% endfor %}
#      '''
[runtime]
  [[root]] # suite defaults
    pre-script = "cd  ${MAIN_SCRIPT_DIR}/"
  [[CyclingDA]]
    pre-script = ${MAIN_SCRIPT_DIR}/jediPrepCyclingDA.csh "0" "0" "DA"
    script = ${MAIN_SCRIPT_DIR}/CyclingDA.csh
    [[[job]]]
#      batch system = pbs
#      shell = /bin/csh
      batch system = slurm
      execution time limit = PT25M
    [[[directives]]]
#      -j = oe
#      -S = /bin/csh
#      -l = select=${CyclingDANodes}:ncpus=${CyclingDAPEPerNode}:mpiprocs=${CyclingDAPEPerNode}:mem=109GB
#      -q = ${CYQueueName}
#      -A = ${CYAccountNumber}
#      -l = /bin/csh
      --account=${CYAccountNumber}
      --mem=109G
      --ntasks=${CyclingDANodes}
      --cpus-per-task=${CyclingDAPEPerNode}
      --partition=dav
{% for mem in EnsDAMembers%}
  [[CyclingFC{{mem}}]]
    script = ${MAIN_SCRIPT_DIR}/CyclingFC.csh "{{mem}}"
    [[[job]]]
#      batch system = pbs
      batch system = slurm
      shell = /bin/csh
      execution time limit = PT${CyclingFCJobMinutes}M
    [[[directives]]]
#      -j = oe
#      -S = /bin/csh
#      -l = select=4:ncpus=32:mpiprocs=32
#      -q = ${CYQueueName}
#      -A = ${CYAccountNumber}
#      -l = /bin/csh
      --account=${CYAccountNumber}
      --ntasks=4
      --cpus-per-task=32
      --partition=dav
{% endfor %}
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
{% for mem in EnsDAMembers%}
  {% for state in ['BG', 'AN']%}
    [[CalculateOM{{state}}{{mem}}]]
      inherit = OMMBase
      pre-script = ${MAIN_SCRIPT_DIR}/jediPrepCalculateOM{{state}}.csh "{{mem}}" "0" "{{state}}"
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
    script = ${MAIN_SCRIPT_DIR}/ExtendedFC.csh "{{mem}}"
    [[[job]]]
      batch system = pbs
      execution time limit = PT${ExtendedFCJobMinutes}M
    [[[directives]]]
      -j = oe
      -S = /bin/csh
      -l = select=4:ncpus=32:mpiprocs=32
      -q = ${CYQueueName}
      -A = ${CYAccountNumber}
  {% for dt in ExtFChrs %}
    [[CalculateOMFC{{mem}}-{{dt}}hr]]
      inherit = OMMBase
      pre-script = ${MAIN_SCRIPT_DIR}/jediPrepCalculateOMFC.csh "{{mem}}" "{{dt}}" "FC"
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
#cylc run ${WholeExpName}

exit
