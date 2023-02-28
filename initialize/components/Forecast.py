#!/usr/bin/env python3

from initialize.Component import Component
from initialize.data.StateEnsemble import StateEnsemble
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

  def __init__(self, config, hpc, mesh, members, workflow, coldIC:StateEnsemble, warmIC:StateEnsemble):
    super().__init__(config)

    if members.n > 1:
      memFmt = '/mem{:03d}'
    else:
      memFmt = ''

    self.mesh = mesh
    assert self.mesh == coldIC.mesh(), 'coldIC must be on same mesh as forecast'
    assert self.mesh == warmIC.mesh(), 'warmIC must be on same mesh as forecast'

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
    inherit = '''+self.groupName]

    for mm in range(1, members.n+1, 1):
      # ColdArgs explanation
      # IAU (False) cannot be used until 1 cycle after DA analysis
      # DACycling (False), IC ~is not~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      # updateSea (False) is not needed since the IC is already an external analysis
      args = [
        1,
        lengthHR,
        outIntervalHR,
        False,
        mesh.name,
        False,
        True,
        False,
        self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
        coldIC[0].directory(),
        coldIC[0].prefix(),
      ]
      ColdArgs = ' '.join(['"'+str(a)+'"' for a in args])


      # WarmArgs explanation
      # DACycling (True), IC ~is~ a DA analysis for which re-coupling is required
      # DeleteZerothForecast (True), not used anywhere else in the workflow
      args = [
        mm,
        lengthHR,
        outIntervalHR,
        IAU,
        mesh.name,
        True,
        True,
        updateSea,
        self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
        warmIC[mm-1].directory(),
        warmIC[mm-1].prefix(),
      ]
      WarmArgs = ' '.join(['"'+str(a)+'"' for a in args])

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
    self.outputs['state'] = {}
    self.outputs['state']['members'] = StateEnsemble(self.mesh)
    for mm in range(1, members.n+1, 1):
      self.outputs['state']['members'].append({
        'directory': self.workDir+'/[[prevCycleDate]]'+memFmt.format(mm),
        'prefix': self.forecastPrefix,
      })

    #self.outputs['sate']['mean'] = {
    #    'directory': self.workDir+'/[[prevCycleDate]]/mean',
    #    'prefix': self.forecastPrefix,
    #}
