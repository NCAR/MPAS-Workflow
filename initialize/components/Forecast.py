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
  forecastPrefix = 'mpasout'
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

  def __init__(self, config, hpc, mesh, members, workflow, coldIC:list, warmIC:list):
    super().__init__(config)

    if members.n > 1:
      memFmt = '/mem{:03d}'
    else:
      memFmt = ''

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
    self.job = Resource(self._conf, attr, ('job', mesh.name))
    self.job._set('seconds', self.job['baseSeconds'] + self.job['secondsPerForecastHR'] * lengthHR)
    task = TaskFactory[hpc.system](self.job)

    self.groupName = 'ForecastFamily'
    self._tasks = ['''
  [['''+self.groupName+''']]
  [[ColdForecast]]
    inherit = '''+self.groupName+'''
'''+task.job()+task.directives()+'''

  [[Forecast]]
    inherit = '''+self.groupName+'''
'''+task.job()+task.directives()+'''

  [[ForecastFinished]]
    inherit = '''+self.groupName+''', BACKGROUND''']

    for mm in range(1, members.n+1, 1):
      # ColdArgs explanation
      # IAU (False) cannot be used until 1 cycle after DA analysis
      # DACycling (False), IC ~is not~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      # updateSea (False) is not needed since the IC is already an external analysis
      ColdArgs = '"1"'
      ColdArgs += ' "'+str(lengthHR)+'"'
      ColdArgs += ' "'+str(outIntervalHR)+'"'
      ColdArgs += ' "False"'
      ColdArgs += ' "'+mesh.name+'"'
      ColdArgs += ' "False"'
      ColdArgs += ' "True"'
      ColdArgs += ' "False"'
      ColdArgs += ' "'+self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm)+'"'
      ColdArgs += ' "'+coldIC[0]['directory']+'"'
      ColdArgs += ' "'+coldIC[0]['prefix']+'"'

      # WarmArgs explanation
      # DACycling (True), IC ~is~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      WarmArgs = '"'+str(mm)+'"'
      WarmArgs += ' "'+str(lengthHR)+'"'
      WarmArgs += ' "'+str(outIntervalHR)+'"'
      WarmArgs += ' "'+str(IAU)+'"'
      WarmArgs += ' "'+mesh.name+'"'
      WarmArgs += ' "True"'
      WarmArgs += ' "True"'
      WarmArgs += ' "'+str(updateSea)+'"'
      WarmArgs += ' "'+self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm)+'"'
      WarmArgs += ' "'+warmIC[mm-1]['directory']+'"'
      WarmArgs += ' "'+warmIC[mm-1]['prefix']+'"'

      self._tasks += ['''
  [[ColdForecast'''+str(mm)+''']]
    inherit = ColdForecast, BATCH
    script = $origin/applications/Forecast.csh '''+ColdArgs+'''
  [[Forecast'''+str(mm)+''']]
    inherit = Forecast, BATCH
    script = $origin/applications/Forecast.csh '''+WarmArgs]

    self._dependencies = ['''
        # ensure there is a valid sea-surface update file before forecast
        {{PrepareSeaSurfaceUpdate}} => Forecast

        # all members must succeed in order to proceed
        Forecast:succeed-all => ForecastFinished''']

    #########
    # outputs
    #########
    self.outputs = {}
    self.outputs['members'] = []
    for mm in range(1, members.n+1, 1):
      self.outputs['members'].append({
        'directory': self.workDir+'/[[prevCycleDate]]'+memFmt.format(mm),
        'prefix': self.forecastPrefix,
      })

    #self.outputs['mean'] = {
    #    'directory': self.workDir+'/[[prevCycleDate]]/mean',
    #    'prefix': self.forecastPrefix,
    #}
