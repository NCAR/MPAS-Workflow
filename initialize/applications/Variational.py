#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from collections import OrderedDict

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup

from initialize.data.Model import Model
from initialize.data.Observations import benchmarkObservations

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

class ABEI(Component):
  workDir = 'CyclingInflation/ABEI'

class Variational(Component):
  defaults = 'scenarios/defaults/variational.yaml'

  requiredVariables = {
    ## DAType [Required Parameter]
    'DAType': [str, ['3dvar', '3denvar', '3dhybrid', '3dhybrid-allsky', '4denvar']],
  }

  optionalVariables = {
    ##ensembleCovarianceWeight and staticCovarianceWeight
    # weights of ensemble and static components of the background errorcovariance
    # MUST be specified when DAType==3dhybrid in order to avoid an error
    'ensembleCovarianceWeight': float,
    'staticCovarianceWeight': float,

  }

  variablesWithDefaults = {
    ## nInnerIterations
    # list of inner iteration counts across all outer iterations
    'nInnerIterations': [[60], list],

    ## MinimizerAlgorithm
    # see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
    # Notes about DRPBlockLanczos:
    # + still experimental, and not reliable for this experiment
    # + only available when EDASize > 1
    'MinimizerAlgorithm': ['DRPCG', str,
      ['DRPCG','DRIPCG', 'DRPLanczos', 'DRPBlockLanczos']
    ],

    ## SelfExclusion, whether exclude own background from the ensemble B perturbations in EnVar during EDA cycling
    'SelfExclusion': [True, bool],

    ### EDA
    # an ensemble of variational data assimilations (EDA) will be carried out
    # whenever members.n > 1

    # One can modify EDASize such that members.n=(EDASize * nDAInstances)
    # members.n is also the number of forecasts used to represent the flow-dependent background
    # error covariance when DAType is 3denvar or 3dhybrid or 4denvar

    ## EDASize
    # ensemble size of each DA instance
    # DEFAULT: 1
    #   1: ensemble of nDAInstances independent Variational applications (members.n independent
    #      jobs), each with 1 background state member per DA job
    # > 1: ensemble of nDAInstances independent EnsembleOfVariational applications, each with EDASize
    #      background state members per DA job
    'EDASize': [1, int],

    ## ABEIInflation
    # whether to utilize adaptive background error inflation (ABEI) in cloud-affected scenes
    # as measured by ABI and AHI observations
    'ABEInflation': [False, bool],

    ## ABEIChannel
    # ABI and AHI channel used to determine the inflation factor
    'ABEIChannel': [8, int, [8, 9, 10]],

    ## observers
    # observation types assimilated in the variational application
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
    'observers': [benchmarkObservations, list],

    ## nObsIndent
    # number of spaces to precede members of the 'observers' list in the JEDI YAML
    'nObsIndent': [4, int],

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
    # OPTIONS: 1 to NPE, default: 1
    'maxIODAPoolSize': [1, int],

    ## radianceThinningDistance
    # distance (km) used for the Gaussian Thinning filter for all radiance-based observations
    'radianceThinningDistance': [145.0, float],

    ## retainObsFeedback
    # whether to retain the observation feedback files (obs, geovals, ydiag)
    'retainObsFeedback': [True, bool],

    ## post
    # list of tasks for Post
    'post': [['verifyobs'], list],

    ## 4denvar
    'subwindow': [1, int],
  }

  def __init__(self,
    config:Config,
    hpc:HPC,
    meshes:dict,
    model:Model,
    members:Members,
    workflow:Workflow,
    parent:Component,
  ):
    # note: all dependencies on obs are handled in DA.py or PrepJEDI.csh
    super().__init__(config)
    self.NN = members.n
    self.memFmt = members.memFmt

    #self.abei = ABEI()

    self.tf = parent.tf
    self.workDir = parent.workDir

    ###################
    # derived variables
    ###################
    DAType = self['DAType']
    self._set('AppName', DAType)
    self._set('appyaml', DAType+'.yaml')
    self._set('YAMLPrefix', DAType+'_')

    self._set('MeshList', ['Outer', 'Inner'])
    self._set('nCellsList', [meshes['Outer'].nCells, meshes['Inner'].nCells])
    self._set('StreamsFileList', [model['outerStreamsFile'], model['innerStreamsFile']])
    self._set('NamelistFileList', [model['outerNamelistFile'], model['innerNamelistFile']])
    self._set('localStaticFieldsFileList', [model['localStaticFieldsFileOuter'], model['localStaticFieldsFileInner']])

    # nOuterIterations, automatically determined from length of nInnerIterations
    self._set('nOuterIterations', len(self['nInnerIterations']))

    # determine nDAInstances from members.n and EDASize
    self.NN = members.n
    EDASize = self['EDASize']
    assert self.NN > 0, ('members.n must be greater than 0')
    assert self.NN % EDASize == 0 and EDASize > 0, ('members.n must be divisible by EDASize')
    nDAInstances = self.NN // EDASize
    self._set('nDAInstances', nDAInstances)

    BlockEDA = 'DRPBlockLanczos'
    self._set('BlockEDA', BlockEDA)
    if EDASize == 1 and self['MinimizerAlgorithm'] == BlockEDA:
      print("WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos")
      self._set('MinimizerAlgorithm', 'DRPLanczos')

    # ensemble
    if (DAType == '3denvar') or ('3dhybrid' in DAType) or (DAType == '4denvar'):
      # localization
      r1 = 'ensemble.localization'
      r2 = meshes['Ensemble'].name
      self._setOrDie('.'.join([r1, r2, 'bumpLocPrefix']), str, None, 'bumpLocPrefix')
      self._setOrDie('.'.join([r1, r2, 'bumpLocDir']), str, None, 'bumpLocDir')

      # forecasts
      if self.NN > 1:
        # EDA uses online ensemble updating
        self._set('ensPbMemPrefix', workflow.MemPrefix)
        self._set('ensPbMemNDigits', workflow.MemNDigits)
        self._set('ensPbFilePrefix', 'mpasout')
        #self._set('ensPbFilePrefix', workflow.memberPrefix)
        self._set('ensPbDir0', '{{ExperimentDirectory}}/CyclingFC/{{prevDateTime}}')
        # TODO: replace two lines above with these when forecast includes these attributes
        #self._set('ensPbFilePrefix', forecast.outputFilePrefix)
        #self._set('ensPbDir0', '{{ExperimentDirectory}}/'+forecast.WorkDir+'/{{prevDateTime}}')
        self._set('ensPbDir1', None)

        ensPbNMembers = self.NN

        # TODO: this needs to be non-zero for EDA workflows that use IAU, get value from forecast
        self._set('ensPbOffsetHR', 0)

      else:
        resource = self._conf.getOrDie('ensemble.forecasts.resource')
        r1 = 'ensemble.forecasts'
        r2 = '.'.join([resource, meshes['Ensemble'].name])

        memberPrefix = self.extractResourceOrDefault((r1, r2), 'memberPrefix', None, str) # if None, default downstream is empty string
        memberNDigits = self.extractResourceOrDie((r1, r2), 'memberNDigits', int)
        filePrefix = self.extractResourceOrDie((r1, r2), 'filePrefix', str)
        directory0 = self.extractResourceOrDie((r1, r2), 'directory0', str)
        directory1 = self.extractResource((r1, r2), 'directory1', str) # can be None
        maxMembers = self.extractResourceOrDie((r1, r2), 'maxMembers', int)
        forecastDateOffsetHR = self.extractResourceOrDie((r1, r2), 'forecastDateOffsetHR', int)

        self._set('ensPbMemPrefix', memberPrefix)
        self._set('ensPbMemNDigits', memberNDigits)
        self._set('ensPbFilePrefix', filePrefix)
        #self._set('ensPbFilePrefix', memberPrefix)
        self._set('ensPbDir0', directory0)
        self._set('ensPbDir1', directory1)
        ensPbNMembers = maxMembers
        self._set('ensPbOffsetHR', forecastDateOffsetHR)

    else:
      ensPbNMembers = 0

    self._set('ensPbNMembers', ensPbNMembers)

    # covariance
    if DAType == '3dvar' or '3dhybrid' in DAType:
      r = meshes['Inner'].name
      self._setOrDie('covariance.bumpCovControlVariables', list, None, 'bumpCovControlVariables')
      self._setOrDie('covariance.bumpCovPrefix', str, None, 'bumpCovPrefix')
      self._setOrDie('covariance.bumpCovVBalPrefix', str, None, 'bumpCovVBalPrefix')
      self._setOrDie('.'.join(['covariance', r, 'bumpCovDir']), str, None, 'bumpCovDir')
      self._setOrDie('.'.join(['covariance', r, 'bumpCovStdDevFile']), str, None, 'bumpCovStdDevFile')
      self._setOrDie('.'.join(['covariance', r, 'bumpCovVBalDir']), str, None, 'bumpCovVBalDir')
      self._setOrDie('.'.join(['covariance', r, 'hybridCoefficientsDir']), str, None, 'hybridCoefficientsDir')

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    # job resource settings

    # Variationals
    # r2 = {{outerMesh}}.{{innerMesh}}{{EDAStr}}.{{DAType}}
    r2 = meshes['Outer'].name+'.'+meshes['Inner'].name
    nodeCount = 'nodes'
    if EDASize > 1:
      r2 += '.ensemble'
      nodeCount = 'nodesPerMember'
    r2 += '.'+DAType

    attr = {
      'retry': {'typ': str},
      'baseSeconds': {'typ': int},
      'secondsPerEnVarMember': {'typ': int},
      nodeCount: {'typ': int},
      'PEPerNode': {'typ': int},
      'memory': {'def': '235GB', 'typ': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'email': {'def': True, 'typ': bool},
    }
    varjob = Resource(self._conf, attr, ('job', r2))
    varjob._set('seconds', varjob['baseSeconds'] + varjob['secondsPerEnVarMember'] * ensPbNMembers)
    if EDASize > 1:
      varjob._set('nodes', varjob['nodesPerMember'] * EDASize)
    vartask = TaskLookup[hpc.system](varjob)

    args = [
      0,
      self.lower,
      self.workDir+'/{{thisCycleDate}}',
      workflow['CyclingWindowHR'],
    ]
    initArgs = ' '.join(['"'+str(a)+'"' for a in args])

    # 2 init phases
    if self['initialize']:
      self._dependencies += ['''
        InitVariationals_0 => InitVariationals_1''']

      self._tasks += ['''
  ## variational tasks
  [[InitVariationals_0]]
    inherit = '''+self.tf.init+''', SingleBatch
    script = $origin/bin/PrepJEDI.csh '''+initArgs+'''
    execution time limit = PT10M
    execution retry delays = '''+varjob['retry']+'''

  [[InitVariationals_1]]
    inherit = '''+self.tf.init+''', SingleBatch
    script = $origin/bin/InitVariationals.csh "1"
    execution time limit = PT10M
    execution retry delays = '''+varjob['retry']]

    if self['execute']:
      self._tasks += ['''
  [[Variationals]]
    inherit = '''+self.tf.execute+'''
'''+vartask.job()+vartask.directives()]
 
      if EDASize == 1:
        # single instance or ensemble of Variational(s)
        for mm in range(1, self.NN+1, 1):
          self._tasks += ['''
  [['''+self.base+str(mm)+''']]
    inherit = Variationals, BATCH
    script = $origin/bin/'''+self.base+'''.csh "'''+str(mm)+'"']

      else:
        # single instance or ensemble of EnsembleOfVariational(s)
        for instance in range(1, nDAInstances+1, 1):
          self._tasks += ['''
  [[EDA'''+str(instance)+''']]
    inherit = Variationals, BATCH
    script = $origin/bin/EnsembleOfVariational.csh "'''+str(instance)+'"']

    # clean
    self._tasks += ['''
  [[CleanVariationals]]
    inherit = '''+self.tf.clean+'''
    script = $origin/bin/Clean'''+self.base+'''.csh''']

    # TODO: make ABEI consistent with external class design
    # GenerateABEInflation
    if self['ABEInflation']:
      attr = {
        'seconds': {'def': 1200},
        'nodes': {'def': 1},
        'PEPerNode': {'def': 36},
        'queue': {'def': hpc['CriticalQueue']},
        'account': {'def': hpc['CriticalAccount']},
      }
      abeijob = Resource(self._conf, attr, ('abei.job', meshes['Outer'].name))
      abeitask = TaskLookup[hpc.system](abeijob)

      self._tasks += ['''
  [[GenerateABEInflation]]
    inherit = '''+self.tf.group+''', BATCH
    script = $origin/bin/GenerateABEInflation.csh
'''+abeitask.job()+abeitask.directives()]

      self._dependencies += ['''
        # abei
        '''+self.tf.pre+''' =>
        MeanBackground => HofXBG
        HofXBG:succeed-all => GenerateABEInflation => '''+self.tf.init+'''
        GenerateABEInflation => CleanHofXBG''']
