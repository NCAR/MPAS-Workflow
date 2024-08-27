#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

from initialize.data.Model import Mesh
from initialize.data.StateEnsemble import StateEnsemble

from initialize.framework.HPC import HPC

from initialize.applications.ExtendedForecast import ExtendedForecast
from initialize.applications.Forecast import Forecast
from initialize.framework.Workflow import Workflow

class SACA(Component):
  defaults = 'scenarios/defaults/saca.yaml'
  workDir = 'CloudDirectInsertion'
  analysisPrefix = 'an'

  variablesWithDefaults = {
    # UTC times to run SACA and extended forecast from SACA analysis
    # formatted as comma-separated string, e.g., T00,T06,T12,T18
    # note: must be supplied in order to do single-state verification
    'meanTimes': [None, str],

    # whether to run saca or not, but copy the 6hr forecast from previous cycle
    'runSaca': [True, bool],

    # indicate to run saca before or after DA
    # OPTIONS: beforeDA, afterDA
    'runDASaca': ['afterDA', str, ['beforeDA', 'afterDA']],

    # whether to use MADWRF's cloud building algorithm
    'buildMADWRF': [True, bool],

    # whether to use GSD's cloud building algorithm
    'buildGSDCloud': [False, bool],

    # whether to saturate water vapor mixing ratio (Qv)
    'saturateQv': [False, bool],

    # whether to conserve Theta V
    'conserveThetaV': [True, bool],

    # cloud fraction value for cloud insertion
    'cldfraDef': [0.98, float],

    # limit the cloud building within 1200 [meters] above ground level
    'cldBluidHeigt': [1200.0, float],

    # whether to run saca diagnostics or not
    'runSacaDiag': [False, bool],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    mesh:Mesh,
    workflow:Workflow,
  ):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self.app = 'saca'
    self._set('AppName', self.app)
    self._set('appyaml', self.app+'.yaml')
    self.doMean = (self['meanTimes'] is not None)
    self.workflow = workflow

    # all csh variables above
    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################

    ## class-specific tasks
    # job settings
    attr = {
      'retry': {'typ': str},
      'seconds': {'typ': int},
      'nodes': {'def': 2, 'typ': int},
      'PEPerNode': {'def': 128, 'typ': int},
      'memory': {'def': '235GB', 'typ': str},
      'queue': {'def': hpc['NonCriticalQueue']},
      'account': {'def': hpc['NonCriticalAccount']},
      'email': {'def': True, 'typ': bool},
    }
    self.job = Resource(self._conf, attr, ('job', mesh.name))
    self.task = TaskLookup[hpc.system](self.job)

    # WorkDir is where SACA is executed
    self.workDir = self.workDir+'/{{thisCycleDate}}'

    self.ICFilePrefix = 'mpasin'
    if self.doMean:
      bgdirectory = 'ColdStartFC'
    else:
      if self['runDASaca'] == 'beforeDA':
        bgdirectory = 'CyclingFC'
      elif self['runDASaca']  == 'afterDA':
        bgdirectory = 'CyclingDA'

    #########
    # outputs
    #########
    self.outputs = {}
    self.outputs['state'] = {}
    self.outputs['state']['members'] = StateEnsemble(mesh)
    self.outputs['state']['members'].append({
      'directory': self.workDir+'/'+self.analysisPrefix,
      'prefix': self.ICFilePrefix,
    })
    self.outputs['doMean'] = {}
    self.outputs['doMean'] = self.doMean
    self.outputs['meanTimes'] = {}
    self.outputs['meanTimes'] = self['meanTimes']
    self.outputs['runDASaca'] = {}
    self.outputs['runDASaca'] = self['runDASaca']

    # execute
    args = [
      self.workDir,
      bgdirectory,
      self['runSaca'],
      self['runDASaca'],
    ]
    self.executeArgs = ' '.join(['"'+str(a)+'"' for a in args])

    self._tasks += ['''
  [['''+self.base+''']]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/'''+self.base+'''.csh '''+self.executeArgs+'''
'''+self.task.job()+self.task.directives()]

  def export(self, previousForecast:str):
    ###########################
    # update tasks/dependencies
    ###########################
    # open graph
    if self.doMean:
      recurrence = self['meanTimes']
    else:
      recurrence = self.workflow['AnalysisTimesSACA']

    self._dependencies += ['''
    '''+recurrence+''' = """''']

    # depends on previous Forecast
    self.tf.addDependencies([previousForecast])

    self._dependencies = self.tf.updateDependencies(self._dependencies)
    self._tasks = self.tf.updateTasks(self._tasks, self._dependencies)

    # close graph
    self._dependencies += ['''
      """''']

    super().export()
