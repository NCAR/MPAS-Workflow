#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class Forecast(Component):
  defaults = 'scenarios/defaults/forecast.yaml'
  workDir = 'CyclingFC'
#  RSTFilePrefix = 'restart'
#  ICFilePrefix = 'mpasin'
#
#  FCFilePrefix = 'mpasout'
#  fcDir = 'fc'
#  DIAGFilePrefix = 'diag'

  variablesWithDefaults = {
    ## updateSea
    # whether to update surface fields before a forecast (e.g., sst, xice)
    'updateSea': [True, bool],

    ## IAU
    # whether to use incremental analysis update
    'IAU': [False, bool],
  }

  def __init__(self, config, hpc, mesh, members, workflow):
    super().__init__(config)

    self.mesh = mesh

    ###################
    # derived variables
    ###################

    IAU = self['IAU']

    if IAU:
      outIntervalHR = workflow['CyclingWindowHR'] // 2
      lengthHR = 3 * outIntervalHR
    else:
      outIntervalHR = workflow['CyclingWindowHR']
      lengthHR = workflow['CyclingWindowHR']

    ########################
    # tasks and dependencies
    ########################
    # job settings
    updateSea = self['updateSea']

    attr = {
      'retry': {'t': str},
      'baseSeconds': {'t': int},
      'secondsPerForecastHR': {'t': int},
      'nodes': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 't': bool},
    }
    # store job for ExtendedForecast to re-use
    self.job = Resource(self._conf, attr, 'job', mesh.name)
    self.job._set('seconds', self.job['baseSeconds'] + self.job['secondsPerForecastHR'] * lengthHR)
    task = TaskFactory[hpc.system](self.job)

    tasks = ['''
  [[ForecastBase]]
'''+task.job()+task.directives()+'''

  [[Forecast]]
    inherit = ForecastBase, BATCH
  [[ColdForecast]]
    inherit = ForecastBase, BATCH
  [[ForecastFinished]]
    inherit = BACKGROUND''']

    for mm in range(1, members.n+1, 1):
      # ColdArgs explanation
      # IAU (False) cannot be used until 1 cycle after DA analysis
      # DACycling (False), IC ~is not~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      # updateSea (False) is not needed since the IC is already an external analysis
      ColdArgs = '"'+str(mm)+'" "'+str(lengthHR)+'" "'+str(outIntervalHR)+'" "False" "'+mesh.name+'" "False" "True" "False"'

      # WarmArgs explanation
      # DACycling (True), IC ~is~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      WarmArgs = '"'+str(mm)+'" "'+str(lengthHR)+'" "'+str(outIntervalHR)+'" "'+str(IAU)+'" "'+mesh.name+'" "True" "True" "'+str(updateSea)+'"'

      tasks += ['''
  [[ColdForecastMember'''+str(mm)+''']]
    inherit = ColdForecast
    script = $origin/applications/ColdForecast.csh '''+ColdArgs+'''
  [[ForecastMember'''+str(mm)+''']]
    inherit = Forecast
    script = $origin/applications/Forecast.csh '''+WarmArgs]

    self.exportTasks(tasks)

    dependencies = ['''
        # ensure there is a valid sea-surface update file before forecast
        {{PrepareSeaSurfaceUpdate}} => Forecast

        # all members must succeed in order to proceed
        Forecast:succeed-all => ForecastFinished''']

    self.exportDependencies(dependencies)
