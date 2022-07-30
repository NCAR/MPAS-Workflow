#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Forecast(SubConfig):
  baseKey = 'forecast'
  defaults = 'scenarios/defaults/forecast.yaml'
  workDir = 'CyclingFC'

  variablesWithDefaults = {
    ## updateSea
    # whether to update surface fields before a forecast (e.g., sst, xice)
    'updateSea': [True, bool],

    ## IAU
    # whether to use incremental analysis update
    'IAU': [False, bool],
  }

  def __init__(self, config, mesh, members, workflow):
    super().__init__(config)

    self.mesh = mesh

    ###################
    # derived variables
    ###################

    updateSea = self.get('updateSea')

    # TODO: set based on IAU
    IAU = self.get('IAU')
    outIntervalHR = workflow.get('CyclingWindowHR')
    lengthHR = workflow.get('CyclingWindowHR')

    # job settings
    retry = self.extractResourceOrDie('job', None, 'retry', str)
    baseSeconds = self.extractResourceOrDie('job', mesh.name, 'baseSeconds', int)
    secondsPerForecastHR = self.extractResourceOrDie('job', mesh.name, 'secondsPerForecastHR', int)
    nodes = self.extractResourceOrDie('job', mesh.name, 'nodes', int)
    PEPerNode = self.extractResourceOrDie('job', mesh.name, 'PEPerNode', int)
    memory = self.extractResourceOrDefault('job', mesh.name, 'memory', '45GB', str)
    seconds = baseSeconds + secondsPerForecastHR * lengthHR

    # for use by ExtendedForecast
    self._set('baseSeconds', baseSeconds)
    self._set('secondsPerForecastHR', secondsPerForecastHR)
    self._set('nodes', nodes)
    self._set('PEPerNode', PEPerNode)
    self._set('memory', memory)

    ###############################
    # export for use outside python
    ###############################
    cylc = []
    csh = []
    self.exportVars(csh, cylc)

    tasks = ['''
  [[ForecastBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT'''+str(seconds)+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select='''+str(nodes)+':ncpus='+str(PEPerNode)+':mpiprocs='+str(PEPerNode)+':mem='+memory+'''

  [[Forecast]]
    inherit = ForecastBase
  [[ColdForecast]]
    inherit = ForecastBase
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
