#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class ExtendedForecast(SubConfig):
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

  def __init__(self, config, members, forecast):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    lengthHR = self.get('lengthHR')
    outIntervalHR = self.get('outIntervalHR')
    self._set('extMeanTimes', self.get('meanTimes'))
    self._set('extEnsTimes', self.get('ensTimes'))
    self._set('extMeanTimesList', self.get('meanTimes').split(','))
    self._set('extEnsTimesList', self.get('ensTimes').split(','))

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
    retry = self.extractResourceOrDefault('job', None, 'retry', '1*PT30S', str)
    baseSeconds = forecast.get('baseSeconds')
    secondsPerForecastHR = forecast.get('secondsPerForecastHR')
    nodes = forecast.get('nodes')
    PEPerNode = forecast.get('PEPerNode')
    memory = forecast.get('memory')

    seconds = baseSeconds + secondsPerForecastHR * lengthHR

    tasks = ['''
  [[ExtendedFCBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT'''+str(seconds)+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -m = ae
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select='''+str(nodes)+':ncpus='+str(PEPerNode)+':mpiprocs='+str(PEPerNode)+':mem='+memory+'''

  ## from external analysis
  [[ExtendedFCFromExternalAnalysis]]
    inherit = ExtendedFCBase
    script = $origin/applications/ExtendedFCFromExternalAnalysis.csh "1" "'''+str(lengthHR)+'''" "'''+str(outIntervalHR)+'''" "False" "'''+forecast.mesh.name+'''" "False" "False" "False"

  ## from mean analysis (including single-member deterministic)
  [[MeanAnalysis]]
    inherit = BATCH
    script = $origin/applications/MeanAnalysis.csh
    [[[job]]]
      execution time limit = PT5M
    [[[directives]]]
      -m = ae
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select=1:ncpus=36:mpiprocs=36
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
