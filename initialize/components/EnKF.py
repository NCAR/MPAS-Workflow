#!/usr/bin/env python3

from collections import OrderedDict

from initialize.Component import Component
from initialize.Resource import Resource
from initialize.util.Task import TaskFactory
from initialize.components.Observations import benchmarkObservations

class EnKF(Component):
  defaults = 'scenarios/defaults/enkf.yaml'
  workDir = 'CyclingDA'
  analysisPrefix = 'an'
  backgroundPrefix = 'bg'

  requiredVariables = {
    ## solver [Required Parameter]
    # see classes derived from oops/src/oops/assimilation/LocalEnsembleSolver.h for all options
    'solver': [str,
      ['LETKF'] #, 'GETKF']
    ],
  }

  variablesWithDefaults = {
    ## observation localization parameters
    'horizontal localization method': ['Horizontal Gaspari-Cohn', str],
    'horizontal localization lengthscale': [1.2e6, float],
    'vertical localization function': ['Gaspari Cohn', str],
    'vertical localization lengthscale': [6.e3, float],

    ## observations
    # observation types assimilated in the enkf application
    # Abbreviations:
    #   clr == clear-sky
    #   cld == cloudy-sky
    # OPTIONS besides benchmarkObservations
    ## MW satellite-based
    # amsua-cld_aqua 
    # amsua-cld_metop-a 
    # amsua-cld_metop-b 
    # amsua-cld_n15 
    # amsua-cld_n18 
    # amsua-cld_n19 
    # mhs_n19 
    # mhs_n18 
    # mhs_metop-a 
    # mhs_metop-b 
    ## IR satellite-based
    # abi_g16 
    # ahi_himawari8 
    # abi-clr_g16 
    # ahi-clr_himawari8 
    # iasi_metop-a 
    # iasi_metop-b 
    # iasi_metop-c 
    'observations': [benchmarkObservations, list],

    ## nObsIndent
    # number of spaces to precede members of the 'observers' list in the JEDI YAML
    'nObsIndent': [2, int],

    ## biasCorrection
    # whether to use bias correction coefficients from VarBC
    # OPTIONS: False (not enabled yet)
    'biasCorrection': [False, bool],

    ## tropprsMethod
    # method for the tropopause pressure determination used in the
    # cloud detection filter for infrared observations
    # OPTIONS: thompson, wmo (currently the build code only works for thompson)
    'tropprsMethod': ['thompson', str, ['thompson', 'wmo']],

    ## maxIODAPoolSize
    # maximum number of IO pool members in IODA writer class
    # OPTIONS: 1 to NPE, default: 10
    'maxIODAPoolSize': [10, int],

    ## radianceThinningDistance
    # distance (km) used for the Gaussian Thinning filter for all radiance-based observations
    'radianceThinningDistance': [145.0, float],

    ## retainObsFeedback
    # whether to retain the observation feedback files (obs, geovals, ydiag)
    'retainObsFeedback': [True, bool],
  }

  def __init__(self, config, hpc, meshes, model, members, workflow, da, build): #, forecast):
    super().__init__(config)

    NN = members.n
    assert NN > 1, ('members.n must be greater than 1')
    memFmt = '/mem{:03d}'

    ###################
    # derived variables
    ###################
    solver = self['solver']
    self._set('AppName', 'enkf')
    self._set('appyaml', 'enkf.yaml')
    self._set('EnKFEXE', build[solver+'EXE'])
    self._set('EnKFBuildDir', build[solver+'BuildDir'])

    self._set('MeshList', ['Outer'])
    self._set('nCellsList', [meshes['Outer'].nCells])
    self._set('StreamsFileList', [model['outerStreamsFile']])
    self._set('NamelistFileList', [model['outerNamelistFile']])
    self._set('localStaticFieldsFileList', [model['localStaticFieldsFileOuter']])

    # ensemble forecasts
    # EnKF uses online ensemble updating
    self._set('ensPbMemPrefix', workflow.MemPrefix)
    self._set('ensPbMemNDigits', workflow.MemNDigits)
    self._set('ensPbFilePrefix', 'mpasout')
    self._set('ensPbDir0', '{{ExperimentDirectory}}/CyclingFC/{{prevDateTime}}')
    # TODO: replace two lines above with these when forecast includes these attributes
    #self._set('ensPbFilePrefix', forecast.outputFilePrefix)
    #self._set('ensPbDir0', '{{ExperimentDirectory}}/'+forecast.WorkDir+'/{{prevDateTime}}')
    self._set('ensPbDir1', None)
    self._set('ensPbNMembers', NN)

    # TODO: this needs to be non-zero for EnKF workflows that use IAU, get value from forecast
    self._set('ensPbOffsetHR', 0)

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    # job resource settings

    # EnKFObserver
    # r2observer = {{outerMesh}}.observer
    r2observer = meshes['Outer'].name
    r2observer += '.observer'
    attr = {
      'retry': {'t': str},
      'baseSeconds': {'t': int},
      'secondsPerMember': {'t': int},
      'nodesPer5Members': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 't': bool},
    }
    observerjob = Resource(self._conf, attr, ('job', r2observer))
    observerjob._set('seconds', observerjob['baseSeconds'] + observerjob['secondsPerMember'] * NN)
    nodes = max([observerjob['nodesPer5Members'] * (NN//5), 1])
    observerjob._set('nodes', nodes)
    observertask = TaskFactory[hpc.system](observerjob)

    # EnKF solver
    # r2solver = {{outerMesh}}.{{solver}}
    r2solver = meshes['Outer'].name
    r2solver += '.'+solver
    attr = {
      'retry': {'t': str},
      'baseSeconds': {'t': int},
      'secondsPerMember': {'t': int},
      'nodesPer5Members': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 't': bool},
    }
    solverjob = Resource(self._conf, attr, ('job', r2solver))
    solverjob._set('seconds', solverjob['baseSeconds'] + solverjob['secondsPerMember'] * NN)
    nodes = max([solverjob['nodesPer5Members'] * (NN//5), 1])
    solverjob._set('nodes', nodes)
    solvertask = TaskFactory[hpc.system](solverjob)

    da._tasks += ['''
  ## enkf tasks
  [[Init'''+solver+''']]
    inherit = '''+da.init+''', SingleBatch
    env-script = cd {{mainScriptDir}}; ./applications/PrepJEDIEnKF.csh "1" "0" "DA" "'''+self.lower+'''"
    script = $origin/applications/PrepEnKF.csh
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+solverjob['retry']+'''

  # clean
  [[Clean'''+solver+''']]
    inherit = Clean, '''+da.clean+'''
    script = $origin/applications/CleanEnKF.csh

  [[EnKFObserver]]
    inherit = '''+da.execute+''', BATCH
    script = $origin/applications/EnKFObserver.csh
'''+observertask.job()+observertask.directives()+'''

  [['''+solver+''']]
    inherit = '''+da.execute+''', BATCH
    script = $origin/applications/EnKF.csh
'''+solvertask.job()+solvertask.directives()]

    da._dependencies += ['''

        # EnKF
        EnKFObserver => '''+solver]

    #########
    # outputs
    #########
    self.inputs = {}
    self.inputs['members'] = []
    self.outputs = {}
    self.outputs['members'] = []
    for mm in range(1, NN+1, 1):
      self.inputs['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+memFmt.format(mm),
        'prefix': self.backgroundPrefix,
      })
      self.outputs['members'].append({
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.analysisPrefix+memFmt.format(mm),
        'prefix': self.analysisPrefix,
      })

    self.inputs['mean'] = {
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.backgroundPrefix+'/mean',
        'prefix': self.backgroundPrefix,
    }
    self.outputs['mean'] = {
        'directory': self.workDir+'/{{thisCycleDate}}/'+self.analysisPrefix+'/mean',
        'prefix': self.analysisPrefix,
    }
