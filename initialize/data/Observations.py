#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from copy import deepcopy

from initialize.config.Config import Config
from initialize.config.Component import Component
from initialize.config.TaskFamily import placeholdertask

from initialize.framework.HPC import HPC

## benchmarkObservations
# base set of observation types assimilated in all experiments
# not included in auto-generated experiment names
benchmarkObservations = [
  # anchor
  'aircraft',
  'satwind',
  'satwnd',
  'sfc',
  'sondes',
  'gnssrobndropp2d',
#  'gnssarobndropp2d',
#  'gnssrobndropp1d',
#  'gnssrorefncep_tunedErrors',
  # MW satellite-based
#  'amsua_aqua',
#  'amsua_metop-a',
#  'amsua_metop-b',
#  'amsua_n15',
#  'amsua_n18',
#  'amsua_n19',
]

class Observations(Component):
  defaults = 'scenarios/defaults/observations.yaml'
  workDir = 'Observations'
  InDBDir = 'dbIn'
  OutDBDir = 'dbOut'
  VarBCAnalysis = OutDBDir+'/satbias_crtm_ana'
  obsPrefix = 'obsout'
  geoPrefix = 'geoval'
  diagPrefix = 'ydiags'

  requiredVariables = {
    ## resource
    # OPTIONS: PANDACArchive, GladeRDAOnline, NCEPFTPOnline, GenerateObs (see defaults)
    'resource': str,
  }
  variablesWithDefaults = {
    ## convertToIODAObservations
    # list of raw observation types to convert to IODA format, when (resource != PANDACArchive)
    'convertToIODAObservations': [[
      'prepbufr',
      'satwnd',
      'gpsro',
      '1bamua',
      'airsev',
      #'mtiasi',
      #'1bmhs',
      #'cris',
    ], list],

    # cylc retry strings for "GetObs" and "ObsToIODA" tasks
    'getRetry': ['80*PT5M', str],
    'convertRetry': ['2*PT30S', str],

    ## GDAS observations error table
    # This file provides observation errors for all types of conventional and satwnd data
    # for 33 pressure levels (1100 hPa to 0 hPa). More information on this table can be
    # found in the GSI User's guide (https://dtcenter.ucar.edu/com-GSI/users/docs/users_guide/GSIUserGuide_v3.7.pdf)
    'GDASObsErrtable': ['/glade/work/guerrett/pandac/fixed_input/GSI_errtables/HRRRENS_errtable_10sep2018.r3dv', str],

    ## CRTM
    'CRTMTABLES': ['/glade/work/guerrett/pandac/fixed_input/crtm_bin/', str],

    # static directories for bias correction files
    #'fixedCoeff': ['/glade/p/mmm/parc/liuz/pandac_hybrid/fix_input/satbias', str],
    #'fixedTlapmeanCov': ['/glade/p/mmm/parc/liuz/pandac_hybrid/fix_input/satbias/2018', str],
    #'initialVARBCcoeff': ['/glade/p/mmm/parc/liuz/pandac_hybrid/fix_input/satbias/2018', str],
    'fixedCoeff': ['/glade/p/mmm/parc/ivette/sio/SATBIAS_fixed', str],
    'fixedTlapmeanCov': ['/glade/p/mmm/parc/ivette/sio/SATBIAS_fixed/2021', str],
    'initialVARBCcoeff': ['/glade/p/mmm/parc/ivette/sio/SATBIAS_fixed/2021', str],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
  ):
    super().__init__(config)

    # WorkDir is where non-IODA-formatted observation files are linked/downloaded, then converted
    self.WorkDir = self.workDir+'/{{thisValidDate}}'

    ###################
    # derived variables
    ###################
    resourceName = 'observations__resource'
    resource = self['resource']
    self._set(resourceName, resource)

    self._set('InDBDir', self.InDBDir)
    self._set('OutDBDir', self.OutDBDir)
    self._set('VarBCAnalysis', self.VarBCAnalysis)
    self._set('obsPrefix', self.obsPrefix)
    self._set('geoPrefix', self.geoPrefix)
    self._set('diagPrefix', self.diagPrefix)

    # all csh variables above
    self._cshVars = list(self._vtable.keys())

    # PrepareObservationsTasks is a list of strings
    key = 'PrepareObservationsTasks'
    values = self.extractResourceOrDie(('resources', resource), key, list)

    # first add variable as a list of tasks
    self._set(key, values)

    # then add as a joined string with dependencies between subtasks (" => ")
    # e.g.,
    # value: [a, b] becomes "a => b"
    key = 'PrepareObservations'
    value = " => ".join(values)
    self._set(key, value)
    self.workflow = key

    self.Queue = hpc['CriticalQueue']
    self.Account = hpc['CriticalAccount']

  def export(self, dtOffsets:list=[0]):

    subqueues = []
    prevTaskNames = {}
    zeroHR = '-0hr'
    for dt in dtOffsets:
      dtStr = str(dt)
      dtLen = '-'+dtStr+'hr'
      dt_work_Args = '"'+dtStr+'" "'+self.WorkDir+'"'
      taskNames = {}

      # get (not part of subqueue, order does not matter)
      base = 'GetObs'
      if base in self['PrepareObservations']:
        taskName = base+dtLen
        self._tasks += ['''
  [['''+taskName+''']]
    inherit = '''+self.tf.group+''', SingleBatch
    script = $origin/bin/'''+base+'''.csh '''+dt_work_Args+'''
    [[[job]]]
      execution time limit = PT10M
      execution retry delays = '''+self['getRetry']]

        # generic 0hr task name for external classes/tasks to grab
        if dt == 0:
          self._tasks += ['''
  [['''+base+''']]
    inherit = '''+base+zeroHR]

      # convert
      base = 'ObsToIODA'
      queue = 'ConvertObs'
      if base in self['PrepareObservations']:
        subqueues.append(queue)
        taskNames[base] = base+dtLen
        self._tasks += ['''
  [['''+taskNames[base]+''']]
    inherit = '''+queue+''', SingleBatch
    script = $origin/bin/'''+base+'''.csh '''+dt_work_Args+'''
    [[[job]]]
      execution time limit = PT600S
      execution retry delays = '''+self['convertRetry']+'''
    [[[directives]]]
      # currently ObsToIODA has to be on Cheyenne, because ioda-upgrade.x is built there
      # TODO: build ioda-upgrade.x on casper, remove Critical directives below, deferring to
      #       SingleBatch inheritance
      # Note: memory for ObsToIODA may need to be increased when hyperspectral and/or
      #       geostationary instruments are added
      -m = ae
      -q = '''+self.Queue+'''
      -A = '''+self.Account+'''
      -l = select=1:ncpus=1:mem=10GB''']

        # generic 0hr task name for external classes/tasks to grab
        if dt == 0:
          self._tasks += ['''
  [['''+base+''']]
    inherit = '''+base+zeroHR]

      # ready (not part of subqueue, order does not matter)
      base = 'ObsReady__'
# TODO: use 'finished' tag like other tasks
#      self._dependencies += ['''
#        '''+base+''' => '''+self.tf.finished]
      if base in self['PrepareObservations']:
        taskName = base+dtLen
        self._tasks += ['''
  [['''+taskName+''']]
    inherit = '''+self.tf.group+','+placeholdertask]

        # generic 0hr task name for external classes/tasks to grab
        if dt == 0:
          self._tasks += ['''
  [['''+base+''']]
    inherit = '''+base+zeroHR]

      # for all taskNames members, make task[t] depend on task[t-dt]
      for key, t_taskName in taskNames.items():
        if key in prevTaskNames:

          # special catch-all succeed string needed due to 0hr naming below
          if dtOffsets[0] == 0 and dtOffsets.index(dt) == 1:
            success = ':succeed-all'
          else:
            success = ''

          self._dependencies += ['''
    '''+prevTaskNames[key]+success+''' => '''+t_taskName]

      prevTaskNames = deepcopy(taskNames)

    # only 1 task per subqueue to avoid cross-cycle errors
    for queue in set(subqueues):
      self._tasks += ['''
  [['''+queue+''']]
    inherit = '''+self.tf.group]

      self._queues += ['''
    [[['''+queue+''']]]
      members = '''+queue+'''
      limit = 1''']

    ###########################
    # update tasks/dependencies
    ###########################
    self._dependencies = self.tf.updateDependencies(self._dependencies)
    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

    # export all
    super().export()
