#!/usr/bin/env python3

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory

class ExtendedForecast(Component):
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

  def __init__(self, config, hpc, members, forecast, extAnaIC:list, meanAnaIC:dict, ensAnaIC:list):
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

    self._cylcVars = ['extMeanTimes', 'extEnsTimes',
      'extMeanTimesList', 'extEnsTimesList',
      'EnsVerifyMembers', 'extIntervHR', 'extLengths', 'nExtOuts']

    ########################
    # tasks and dependencies
    ########################
    # job settings

    # ExtendedFCBase
    job = forecast.job
    job._set('seconds', job['baseSeconds'] + job['secondsPerForecastHR'] * lengthHR)
    job._set('queue', hpc['NonCriticalQueue'])
    job._set('account', hpc['NonCriticalAccount'])
    fctask = TaskFactory[hpc.system](job)

    # MeanAnalysis
    attr = {
      'seconds': {'def': 300},
      'nodes': {'def': 1, 't': int},
      'PEPerNode': {'def': 36, 't': int},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
    }
    meanjob = Resource(self._conf, attr, ('job', 'meananalysis'))
    meantask = TaskFactory[hpc.system](meanjob)

    args = [
      1,
      lengthHR,
      outIntervalHR,
      False,
      forecast.mesh.name,
      False,
      False,
      False,
      self.workDir+'/{{thisCycleDate}}/mean',
      extAnaIC[0]['directory'],
      extAnaIC[0]['prefix'],
    ]
    extAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    args = [
      1,
      lengthHR,
      outIntervalHR,
      False,
      forecast.mesh.name,
      True,
      False,
      False,
      self.workDir+'/{{thisCycleDate}}/mean',
      meanAnaIC['directory'],
      meanAnaIC['prefix'],
    ]
    meanAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

    self.groupName = self.__class__.__name__
    self._tasks = ['''
  [['''+self.groupName+''']]
'''+fctask.job()+fctask.directives()+'''

  ## from external analysis
  [[ExtendedFCFromExternalAnalysis]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/Forecast.csh '''+extAnaArgs+'''

  # TODO: move MeanAnalysis somewhere else
  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = '''+self.groupName+''', Mean, BATCH
    script = $origin/applications/MeanAnalysis.csh
'''+meantask.job()+meantask.directives()+'''
  [[ExtendedMeanFC]]
    inherit = '''+self.groupName+''', BATCH
    script = $origin/applications/Forecast.csh '''+meanAnaArgs+'''


  [[ExtendedForecastFinished]]
    inherit = '''+self.groupName+''', BACKGROUND

  ## from ensemble of analyses
  [[ExtendedEnsFC]]
    inherit = '''+self.groupName]

    memFmt = '/mem{:03d}'
    for mm in EnsVerifyMembers:
      args = [
        mm,
        lengthHR,
        outIntervalHR,
        False,
        forecast.mesh.name,
        True,
        False,
        False,
        self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
        ensAnaIC[mm-1]['directory'],
        ensAnaIC[mm-1]['prefix'],
      ]
      ensAnaArgs = ' '.join(['"'+str(a)+'"' for a in args])

      self._tasks += ['''
  [[ExtendedFC'''+str(mm)+''']]
    inherit = ExtendedEnsFC, BATCH
    script = $origin/applications/Forecast.csh '''+ensAnaArgs]

    #########
    # outputs
    #########
    self.outputs = {}
    self.outputs['members'] = []
    for mm in range(1, members.n+1, 1):
      self.outputs['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}'+memFmt.format(mm),
        'prefix': forecast.forecastPrefix,
      })

    self.outputs['mean'] = {
        'directory': self.workDir+'/{{thisCycleDate}}/mean',
        'prefix': forecast.forecastPrefix,
    }
