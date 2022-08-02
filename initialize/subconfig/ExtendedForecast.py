#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class ExtendedForecast(Component):
  baseKey = 'extendedforecast'
  workDir = 'ExtendedFC'

  variablesWithDefaults = {
    # length of verification extended forecasts
    'lengthHR': [240, int],

    # interval between OMF verification times of an individual forecast
    'outIntervalHR': [12, int],

    # UTC times to run extended forecast from mean analysis
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    'meanTimes': ['T00,T12', str],

    # UTC times to run ensemble of extended forecasts
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    'ensTimes': ['T00', str],
  }

  def __init__(self, config, hpc, members, forecast):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    lengthHR = self['lengthHR']
    outIntervalHR = self['outIntervalHR']
    self._set('extMeanTimes', self['meanTimes'])
    self._set('extEnsTimes', self['ensTimes'])
    self._set('extMeanTimesList', self['meanTimes'].split(','))
    self._set('extEnsTimesList', self['ensTimes'].split(','))

    EnsVerifyMembers = range(1, members.n+1, 1)
    self._set('EnsVerifyMembers', EnsVerifyMembers)

    extLengths = range(0, lengthHR+outIntervalHR, outIntervalHR)
    self._set('extIntervHR', outIntervalHR)
    self._set('extLengths', extLengths)
    self._set('nExtOuts', len(extLengths))

    cylc = ['extMeanTimes', 'extEnsTimes',
      'extMeanTimesList', 'extEnsTimesList',
      'EnsVerifyMembers', 'extIntervHR', 'extLengths', 'nExtOuts']

    ###############################
    # export for use outside python
    ###############################
    self.exportVarsToCylc(cylc)

    ########################
    # tasks and dependencies
    ########################
    # job settings

    # ExtendedFCBase
    job = forecast.job
    job._set('seconds', job['baseSeconds'] + job['secondsPerForecastHR'] * lengthHR)
    job._set('queue', hpc['NonCriticalQueue'])
    job._set('account', hpc['NonCriticalAccount'])
    fctask = TaskFactory[hpc.name](job)

    # MeanAnalysis
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, 'job', 'meananalysis')
    meantask = TaskFactory[hpc.name](meanjob)

    tasks = ['''
  [[ExtendedFCBase]]
    inherit = BATCH
'''+fctask.job()+fctask.directives()+'''

  ## from external analysis
  [[ExtendedFCFromExternalAnalysis]]
    inherit = ExtendedFCBase
    script = $origin/applications/ExtendedFCFromExternalAnalysis.csh "1" "'''+str(lengthHR)+'''" "'''+str(outIntervalHR)+'''" "False" "'''+forecast.mesh.name+'''" "False" "False" "False"

  # TODO: move MeanAnalysis somewhere else
  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = BATCH
    script = $origin/applications/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()+'''
  [[ExtendedMeanFC]]
    inherit = ExtendedFCBase
    script = $origin/applications/ExtendedMeanFC.csh "1" "'''+str(lengthHR)+'''" "'''+str(outIntervalHR)+'''" "False" "'''+forecast.mesh.name+'''" "True" "False" "False"


  [[ExtendedForecastFinished]]
    inherit = BACKGROUND

  ## from ensemble of analyses
  [[ExtendedEnsFC]]
    inherit = ExtendedFCBase''']

    for mm in EnsVerifyMembers:
      tasks += ['''
  [[ExtendedFC'''+str(mm)+''']]
    inherit = ExtendedEnsFC
    script = $origin/applications/ExtendedEnsFC.csh "'''+str(mm)+'''" "'''+str(lengthHR)+'''" "'''+str(outIntervalHR)+'''" "False" "'''+forecast.mesh.name+'''" "True" "False" "False"''']

    self.exportTasks(tasks)
