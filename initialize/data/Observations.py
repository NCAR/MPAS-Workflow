#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from copy import deepcopy

from initialize.config.Config import Config
from initialize.config.Component import Component
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import placeholdertask

from initialize.framework.HPC import HPC

## benchmarkObservations
# base set of observation types assimilated in all experiments
# not included in auto-generated experiment names
benchmarkObservations = [
  # anchor
  'aircraft',
#  'gnssrorefncep',
  'gnssrobndropp1d',
  'satwind',
  'satwnd',
  'sfc',
  'sondes',
  # MW satellite-based
  'amsua_aqua',
  'amsua_metop-a',
  'amsua_metop-b',
  'amsua_n15',
  'amsua_n18',
  'amsua_n19',
  'mhs_metop-a',
  'mhs_metop-b',
  'mhs_n18',
  'mhs_n19',
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
    # OPTIONS: PANDACArchive, CampaignOnline, NCEPFTPOnline, GenerateObs (see defaults)
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

    ## AROWindowHours
    # assimilation time window (hours) used to bucket ARO (gnssaro) observations into
    # synoptic cycles when downloading/converting them in GetObs.csh
    'AROWindowHours': [6, int],

    ## AROFormat
    # raw ARO (gnssaro) file format to download/convert in GetObs.csh/ObsToIODA.csh:
    # 'netcdf' (AGS atmPrf profiles; receiver/tailnumber/antenna are read directly from
    # the file) or 'bufr' (AGS bfrPrf profiles, WMO GNSS-RO template 3-10-026; smaller,
    # but receiver/tailnumber/antenna are not carried in the message and are populated
    # only for aircraft with a confirmed netcdf cross-reference). Per AGS, the bufr
    # product is "self-developed based on the WMO standard, still under testing".
    # OPTIONS: netcdf, bufr
    'AROFormat': ['netcdf', str],

    ## AROSource
    # where GetObs.csh fetches raw ARO (gnssaro) files from:
    # 'nrt': near-real-time, processed with UCAR/COSMIC real-time GNSS clocks. Per AGS,
    #   "data quality has not been verified". Fetched per-cycle from AGS's per-day
    #   level2 listing (https://agsweb.ucsd.edu/gnss-aro/<ccyy>/nrt/level2/<ccyy>.<ddd>/).
    # 'postProc': a fixed, dated re-processed release using CODE final GNSS clocks
    #   (higher quality), identified by AROPostProcRelease. Use for retrospective/
    #   reanalysis-style experiments over a period AGS has already re-processed.
    # OPTIONS: nrt, postProc
    'AROSource': ['nrt', str],

    ## AROPostProcRelease
    # AGS post-processed release directory, relative to https://agsweb.ucsd.edu/gnss-aro/.
    # Only used when AROSource == postProc. Available releases as of 2026-08 (see
    # https://agsweb.ucsd.edu/gnss-aro/ar2026/readme.txt):
    #   ar2026/postProc_20260408  (NOAA G-IV only)
    #   ar2026/postProc_20260528  (NOAA G-IV, USAF WC-130s, NASA G-III, DLR G-550)
    # Note the release directory name is fixed and not derived from each profile's own
    # date -- e.g. postProc_20260528 also contains flights from late 2025.
    'AROPostProcRelease': ['ar2026/postProc_20260528', str],

    ## AROVersion
    # AGS retrieval version, only used when AROSource == postProc (nrt is only ever
    # published as 0027.0004): '0027.0004' (flight-level data as initial value, all
    # aircraft) or '0028.0004' (ERA5-derived initial value, all aircraft except NASA G-III)
    # OPTIONS: 0027.0004, 0028.0004
    'AROVersion': ['0027.0004', str],

    ## GDAS observations error table
    # This file provides observation errors for all types of conventional and satwnd data
    # for 33 pressure levels (1100 hPa to 0 hPa). More information on this table can be
    # found in the GSI User's guide (https://dtcenter.ucar.edu/com-GSI/users/docs/users_guide/GSIUserGuide_v3.7.pdf)
    'GDASObsErrtable': ['/glade/campaign/mmm/parc/liuz/pandac_common/fixed_input/GSI_errtables/HRRRENS_errtable_10sep2018.r3dv', str],

    ## CRTM
    'CRTMTABLES': ['/glade/campaign/mmm/parc/jban/pandac_common/crtm_coeffs_v3/', str],

    # static directories for bias correction files
    'fixedCoeff': ['/glade/campaign/mmm/parc/jban/pandac_common/obs/satbias', str],
    'fixedTlapmeanCov': ['/glade/campaign/mmm/parc/jban/pandac_common/obs/satbias/2018', str],
    'initialVARBCcoeff': ['/glade/campaign/mmm/parc/jban/pandac_common/obs/satbias/2018', str],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
  ):
    super().__init__(config)

    # AROFormat=bufr + AROSource=postProc is not currently usable: AGS's postProc bfrPrf
    # files use a different BUFR encoding (masterTablesVersionNumber=43, bufrHeaderCentre=183)
    # than nrt bfrPrf files (masterTablesVersionNumber=12, bufrHeaderCentre=0), and eccodes
    # has no local table definitions for centre 183 -- every postProc bufr file fails to
    # unpack with gribapi.errors.HashArrayNoMatchError inside ObsToIODA.csh, regardless of
    # environment. This is an AGS data-encoding issue, not something fixable here.
    assert not (self['AROFormat'] == 'bufr' and self['AROSource'] == 'postProc'), \
      self._msg("AROFormat=bufr is not supported with AROSource=postProc -- AGS's postProc "
        "bfrPrf files use a BUFR encoding eccodes cannot decode. Use AROFormat=netcdf for "
        "postProc, or AROSource=nrt for bufr.")

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

    self.Queue = hpc['SharedQueue']
    self.Account = hpc['CriticalAccount']

    '''
    Create a Task to automatically convert to derecho PBS args if neccessary.
    This may specify a job priority for derecho based on the queue type.
    '''
    attr = {
      'seconds': {'def': 900, 'typ': int},
      'nodes': {'def': 1, 'typ': int},
      'PEPerNode': {'def': 8, 'typ': int},
      'memory': {'def': '8GB', 'typ': str},
      'queue': {'def': self.Queue},
      'account': {'def': self.Account},
      'email': {'def': True, 'typ': bool},
    }
    resource = Resource(self._conf, attr, ('job',))
    self.task = TaskLookup[hpc.system](resource)

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
'''+self.task.job()+'''
      # currently ObsToIODA has to be on Cheyenne, because ioda-upgrade.x is built there
      # TODO: build ioda-upgrade.x on casper, remove Critical directives below, deferring to
      #       SingleBatch inheritance
      # Note: memory for ObsToIODA may need to be increased when hyperspectral and/or
      #       geostationary instruments are added
'''+self.task.directives()]

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
