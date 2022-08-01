#!/usr/bin/env python3

from initialize.Component import Component

class VerifyObs(Component):
  baseKey = 'verifyobs'
  defaults = 'scenarios/defaults/verifyobs.yaml'
  variablesWithDefaults = {
    'pyVerifyDir': ['/glade/work/guerrett/pandac/fixed_input/graphics', str],
  }

  def __init__(self, config, members):
    super().__init__(config)

    ###############################
    # export for use outside python
    ###############################
    csh = list(self._vtable.keys())
    self.exportVarsToCsh(csh)

    ########################
    # tasks and dependencies
    ########################
    # job settings
    retry = self.extractResourceOrDie('job', None, 'retry', str)
    seconds = self.extractResourceOrDie('job', None, 'baseSeconds', int)
    secondsPerMember = self.extractResourceOrDie('job', None, 'secondsPerMember', int)
    ensSeconds = seconds + secondsPerMember * members.n

    tasks = ['''
  [[VerifyObsBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT'''+str(seconds)+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=1:ncpus=36:mpiprocs=36

{% if DiagnoseEnsSpreadBG %}
  {% set nEnsSpreadMem = '''+str(members.n)+''' %}
  {% set obsEnsSeconds = '''+str(seconds)+''' %}
{% else %}
  {% set nEnsSpreadMem = 0 %}
  {% set obsEnsSeconds = '''+str(seconds)+''' %}
{% endif %}
''']

    self.exportTasks(tasks)
