#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class VerifyModel(Component):
  baseKey = 'verifymodel'
  defaults = 'scenarios/defaults/verifymodel.yaml'
  workDir = 'Verification'
  diagnosticsDir = 'diagnostic_stats/model'
  variablesWithDefaults = {
    'pyVerifyDir': ['/glade/work/guerrett/pandac/fixed_input/graphics', str],
  }

  def __init__(self, config, hpc, mesh, members):
    super().__init__(config)

    self._set('ModelDiagnosticsDir', self.diagnosticsDir)

    ###############################
    # export for use outside python
    ###############################
    csh = list(self._vtable.keys())
    self.exportVarsToCsh(csh)

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
    job = Resource(self._conf, attr, 'job', mesh.name)
    ensSeconds = job['seconds'] + job['secondsPerMember'] * members.n
    task = TaskFactory[hpc.name](job)

    tasks = ['''
  [[VerifyModelBase]]
    inherit = BATCH
'''+task.job()+task.directives()+'''

{% if DiagnoseEnsSpreadBG %}
  {% set nEnsSpreadMem = '''+str(members.n)+''' %}
  {% set modelEnsSeconds = '''+str(ensSeconds)+''' %}
{% else %}
  {% set nEnsSpreadMem = 0 %}
  {% set modelEnsSeconds = '''+str(job['seconds'])+''' %}
{% endif %}
''']

    self.exportTasks(tasks)
