#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class VerifyObs(Component):
  defaults = 'scenarios/defaults/verifyobs.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/obs'
  variablesWithDefaults = {
    'script directory': ['/glade/work/guerrett/pandac/fixed_input/graphics_ioda-conventions', str],
  }

  def __init__(self, config, hpc, members):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._set('ObsDiagnosticsDir', self.diagnosticsDir)

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    # job settings
    attr = {
      'retry': {'t': str},
      'seconds': {'t': int},
      'secondsPerMember': {'t': int},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    job = Resource(self._conf, attr, ('job',))
    ensSeconds = job['seconds'] + job['secondsPerMember'] * members.n
    task = TaskFactory[hpc.system](job)

    self.groupName = self.__class__.__name__
    self._tasks = ['''
  [['''+self.groupName+''']]
'''+task.job()+task.directives()+'''

{% if DiagnoseEnsSpreadBG %}
  {% set nEnsSpreadMem = '''+str(members.n)+''' %}
  {% set obsEnsSeconds = '''+str(ensSeconds)+''' %}
{% else %}
  {% set nEnsSpreadMem = 0 %}
  {% set obsEnsSeconds = '''+str(job['seconds'])+''' %}
{% endif %}
''']
