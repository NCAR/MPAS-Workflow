#!/usr/bin/env python3

from collections import OrderedDict
from getpass import getuser
import os.path

from initialize.applications.Members import Members

from initialize.config.Component import Component
from initialize.config.Config import Config
from initialize.config.Resource import Resource
from initialize.config.Task import TaskLookup
from initialize.config.TaskFamily import CylcTaskFamily

from initialize.data.Model import Model
from initialize.data.Observations import benchmarkObservations

from initialize.framework.HPC import HPC
from initialize.framework.Workflow import Workflow

class EnKF(Component):
  defaults = 'scenarios/defaults/enkf.yaml'

  requiredVariables = {
    ## solver [Required Parameter]
    # see classes derived from oops/src/oops/assimilation/LocalEnsembleSolver.h for all options
    'solver': [str,
      ['LETKF', 'GETKF'],
    ],
  }

  variablesWithDefaults = {
    # horizontal observation localization
    'localization dimension': ['3D', str, ['2D', '3D']],
    'horizontal localization method': ['Horizontal Gaspari-Cohn', str],
    'horizontal localization lengthscale': [1.2e6, float],
    # vertical localization (GETKF: model spcace; LETKF: obs space)
    'vertical localization function': ['Gaspari Cohn', str],
    'vertical localization lengthscale': [6.e3, float],
    'vertical localization lengthscale units': ['height', str],
    'fraction of retained variance': [0.95, float],

    # Inflation
    'rtpp value': [0.5, float],
    'rtps value': [0.9, float],
    'mult value': [1.0, float],

    # Use Linear Operator
    'useLinearOperator': ['true', str, ['true', 'false']],

    # Calculate ensemble OMA
    'diagEnKFOMA': ['True', bool, ['True', 'False']],

    ## observers
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
    'observers': [benchmarkObservations, list],

    ## nObsIndent
    # number of spaces to precede members of the 'observers' list in the JEDI YAML
    'nObsIndent': [2, int],

    ## biasCorrection
    # whether to use bias correction coefficients from VarBC
    # OPTIONS: False (not enabled yet)
    'biasCorrection': [False, bool],

    # directories that stores varBC coefficients that are updated with variational DA
    # if coupledToVarDA == True the staticVarBcDir is automatically set to the coupled var DA directory
    'staticVarBcDir': ['/glade/campaign/mmm/parc/ivette/pandac/year7Exp/ivette_3dhybrid-allsky-60-60-iter_O30kmI60km_ensB-SE80+RTPP70_VarBC_v3.0.2_newBenchmark_allsky-amsua/CyclingDA', str],

    ## tropprsMethod
    # method for the tropopause pressure determination used in the
    # cloud detection filter for infrared observations
    # OPTIONS: thompson, wmo (currently the build code only works for thompson)
    'tropprsMethod': ['thompson', str, ['thompson', 'wmo']],

    ## maxIODAPoolSize
    # maximum number of IO pool members in IODA writer class
    # OPTIONS: 1 to NPE, default: 10
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

    ## concatenateObsFeedback
    # whether to concatenate the geovals and ydiag feedback files
    'concatenateObsFeedback': [False, bool],

    ## IR/VIS land surface coefficients classification
    # OPTIONS: USGS, IGBP, NPOESS
    'IRVISlandCoeff': ['IGBP', str],

    ## Coupling to an external variational DA run
    # When coupledToVarDA is true, this EnKF run can be recentered (recenterAnalyses == True) on the variational DA run and/or
    # it can use the variational bias correction coefficients (biasCorrection == True) of the variational DA run
    'coupledToVarDA': [False, bool],

    ## Recentering of analysis ensemble
    # When recenterAnalyses is true, the analysis ensemble of this EnKF is recentered on the analysis of a
    # concurrently running var DA run. Requires coupledToVarDA == True.
    # The recentering application is not implemented yet.
    'recenterAnalyses': [False, bool],
  }

  optionalVariables = {
    ## Coupling to an external variational DA run
    # Must be specified if coupledToVarDA == True, not used otherwise
    # Specify the full name of the workflow, constructed as:
    # Experiment['prefix'] + Experiment['name'] + Experiment['suffix'] + Experiment['suite identifier']
    # The default values are:
    # Experiment['prefix'] = "${USER}_"
    # Experiment['name']: see Cycle.py
    # Experiment['suffix'] = ""
    # Experiment['suite identifier'] = ""
    # It is best practice to specify the experiment prefix, name, and suffix in the coupled yaml files
    # to make sure the coupled workflow can be identified correctly.
    # Note: the workflow automatically prepends 'MPAS-Workflow' to workflowNameVarDA where needed
    # to make the identifier consistent with submit.csh
    'workflowNameVarDA': str,
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
    super().__init__(config)

    NN = members.n
    assert NN > 1, ('members.n must be greater than 1')

    self.tf = parent.tf
    self.workDir = parent.workDir

    ###################
    # derived variables
    ###################
    solver = self['solver']
    if solver == 'GETKF':
      assert self['localization dimension'] == '3D', ('only 3D localization is supported for GETKF')
    self._set('AppName', 'enkf')
    self._set('appyaml', 'enkf.yaml')

    self._set('MeshList', ['EnKF'])
    self._set('nCellsList', [meshes['Outer'].nCells])
    self._set('meshRatioList', [meshes['Outer'].meshRatio])
    self._set('StreamsFileList', [model['outerStreamsFile']])
    self._set('NamelistFileList', [model['outerNamelistFile']])
    self._set('localInvariantFieldsFileList', [model['localInvariantFieldsFileOuter']])

    self._set('TimeStepList', [model['TimeStepOuter'], model['TimeStepInner']])
    self._set('DiffusionLengthScaleList', [model['DiffusionLengthScaleOuter'], model['DiffusionLengthScaleInner']])
    self._set('RadiationLWIntervalList', [model['RadiationLWIntervalOuter'], model['RadiationLWIntervalInner']])
    self._set('RadiationSWIntervalList', [model['RadiationSWIntervalOuter'], model['RadiationSWIntervalInner']])
    self._set('PhysicsSuiteList', [model['PhysicsSuiteOuter'], model['PhysicsSuiteInner']])
    self._set('MicrophysicsList', [model['MicrophysicsOuter'], model['MicrophysicsInner']])
    self._set('ConvectionList', [model['ConvectionOuter'], model['ConvectionInner']])
    self._set('PBLList', [model['PBLOuter'], model['PBLInner']])
    self._set('GwdoList', [model['GwdoOuter'], model['GwdoInner']])
    self._set('RadiationCloudList', [model['RadiationCloudOuter'], model['RadiationCloudInner']])
    self._set('RadiationLWList', [model['RadiationLWOuter'], model['RadiationLWInner']])
    self._set('RadiationSWList', [model['RadiationSWOuter'], model['RadiationSWInner']])
    self._set('SfcLayerList', [model['SfcLayerOuter'], model['SfcLayerInner']])
    self._set('LSMList', [model['LSMOuter'], model['LSMInner']])

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

    # coupling to variational DA
    if self['coupledToVarDA']:
      # A coupled EnKF run should use some information from the variational DA.
      # Stop the run if no information is used in the current configuration to make sure
      # user can adjust settings.
      if not self['biasCorrection'] and not self['recenterAnalyses']:
        raise ValueError(("Coupled EnKF does not use any information from var DA."
                          "biasCorrectionEnKF and/or recenterAnalyses should be set to true."))
      # A coupled EnKF run requires the name of the variational DA workflow to
      # set the external dependency
      if self['workflowNameVarDA'] is None:
        raise ValueError("workflowNameVarDA has to be specified for a coupled EnKF")
      # Export the var DA run information to the csh file
      self._set('workflowNameVarDA', self['workflowNameVarDA'])
      workDirVarDA = os.path.join('/glade', 'derecho', 'scratch', getuser(),
                           'pandac', self['workflowNameVarDA'])
      self._set('workDirVarDA', workDirVarDA)
      # Overwrite the static var BC directory to make sure we are reading the satbias files from
      # the coupled var DA run
      self._set('staticVarBcDir', f'{os.path.join(workDirVarDA, "CyclingDA")}')
    else:
      # Recentering the analysis ensemble is not defined if the EnKF run is not coupled.
      if self['recenterAnalyses']:
        raise NotImplementedError("Recentering of the analyses ensemble is undefined if the EnKF run is not coupled.")

    self._cshVars = list(self._vtable.keys())

    ########################
    # tasks and dependencies
    ########################
    # job resource settings

    attr = {
      'retry': {'t': str},
      'baseSeconds': {'t': int},
      'secondsPerMember': {'t': int},
      'nodes': {'t': int},
      'PEPerNode': {'t': int},
      'memory': {'def': '45GB', 't': str},
      'queue': {'def': hpc['CriticalQueue']},
      'account': {'def': hpc['CriticalAccount']},
      'job_priority': {'def': hpc['CriticalPriority']},
      'email': {'def': True, 't': bool},
    }

    # EnKFObserver
    # r2observer = {{outerMesh}}.observer
    r2observer = meshes['Outer'].name
    r2observer += '.'+solver+'.observer'
    observerjob = Resource(self._conf, attr, ('job', r2observer))
    observerjob._set('seconds', observerjob['baseSeconds'] + observerjob['secondsPerMember'] * NN)
    observertask = TaskLookup[hpc.system](observerjob)

    # EnKFDiagOMA
    if self['diagEnKFOMA'] and self['retainObsFeedback']:
      # r2observer = {{outerMesh}}.observer
      r2diagoma = meshes['Outer'].name
      r2diagoma += '.'+solver+'.diagoma'
      diagomajob = Resource(self._conf, attr, ('job', r2observer))
      diagomajob._set('seconds', observerjob['baseSeconds'] + observerjob['secondsPerMember'] * NN)
      diagomatask = TaskLookup[hpc.system](diagomajob)

    # EnKF solver
    # r2solver = {{outerMesh}}.{{solver}}
    r2solver = meshes['Outer'].name
    r2solver += '.'+solver+'.solver'

    # add threads attribute
    attr['threads'] = {'def': 1, 't': int}

    solverjob = Resource(self._conf, attr, ('job', r2solver))
    solverjob._set('seconds', solverjob['baseSeconds'] + solverjob['secondsPerMember'] * NN)
    solvertask = TaskLookup[hpc.system](solverjob)

    self._set('solverThreads', solverjob.get('threads'))
    self._cshVars.append('solverThreads')

    args = [
      0,
      self.lower,
      self.workDir+'/{{thisCycleDate}}',
      workflow['CyclingWindowHR'],
      NN,
    ]
    initArgs = ' '.join(['"'+str(a)+'"' for a in args])

    if self['execute']:
      self._tasks += ['''
  ## enkf tasks
  [[InitEnKF]]
    inherit = '''+self.tf.init+''', SingleBatch
    script = $origin/bin/PrepJEDI.csh '''+initArgs+'''
    execution time limit = PT10M
    execution retry delays = '''+solverjob['retry']+'''

  [[EnKFObserver]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/EnKF.csh OMB
'''+observertask.job()+observertask.directives()+'''

  [[EnKFSolver]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/EnKF.csh Solver
'''+solvertask.job()+solvertask.directives()]
      
      if self['coupledToVarDA']:
        # The coupled EnKF run uses the analysis file and/or the variational bias correction files
        # from the variational DA run. This introduces a dependency between the EnKF and the
        # variational DA at the current cycle point. The following external trigger defines this dependency.
        # Note: submit.csh prepends 'MPAS-Workflow/' to the workflow name to generate the workflow ID
        workflowIdVarDA = os.path.join('MPAS-Workflow', self['workflowNameVarDA'])
        callIntervalInS = 30  # call interval for external trigger (default is 10)
        self._xtriggers +=[('\n'
                            '    var_da = workflow_state('
                            f'workflow="{workflowIdVarDA}", '
                            'task="DAFinished__", point="%(point)s")'
                            f':PT{callIntervalInS}S')]
        
        # Add the dependency on the var DA run to the graph
        self._dependencies += [('\n'
                                '        @var_da => ' + self.tf.pre)]
        if self['recenterAnalyses']:
          # Add the dependency: the EnKFDiagOMA task is optional. If the task is enabled, the recentering
          # task should run after it. If it is not enabled, the recentering task should run after the solver task.
          if self['diagEnKFOMA'] and self['retainObsFeedback']:
            self._dependencies += [('\n'
                                    '        EnKFDiagOMA => RecenterEnKF')]
          else:
            self._dependencies += [('\n'
                                    '        EnKFSolver => RecenterEnKF')]
          # Add the task
          keyListRecenter = {
            # Notes:
            # - the recenter application is currently small enough to run on develop
            # - the develop queue does not support a job_priority flag, so removed this for now
            'retry': {'t': str},
            'baseSeconds': {'t': int},
            'secondsPerMember': {'t': int},
            'nodes': {'t': int},
            'PEPerNode': {'t': int},
            'memory': {'t': str},
            'queue': {'def': hpc['SharedQueue']},
            'account': {'def': hpc['CriticalAccount']},
            'email': {'def': True, 't': bool},
          }
          resourceRecenter = meshes['Outer'].name + '.' + solver + '.recenter'
          recenterJob = Resource(self._conf, keyListRecenter, ('job', resourceRecenter))
          recenterJob._set('seconds', recenterJob['baseSeconds'] + recenterJob['secondsPerMember'] * NN)
          recenterTask = TaskLookup[hpc.system](recenterJob)
          self._tasks += [('\n'
                           '  [[RecenterEnKF]]'
                           '\n'
                           f'    inherit = {self.tf.execute}, BATCH'
                           '\n'
                           '    script = $origin/bin/RecenterAnalysisEnsemble.csh'
                           '\n'
                           f'{recenterTask.job() + recenterTask.directives()}'
                           '\n')]

      if self['diagEnKFOMA'] and self['retainObsFeedback']:
         self._tasks += ['''
  [[EnKFDiagOMA]]
    inherit = '''+self.tf.execute+''', BATCH
    script = $origin/bin/EnKF.csh OMA
'''+diagomatask.job()+diagomatask.directives()]
         self._dependencies += ['''
        EnKFSolver => EnKFDiagOMA => '''+self.tf.post]

      if self['concatenateObsFeedback']:
        concatattr = {
          'seconds': {'def': 300},
          'nodes': {'def': 1},
          'PEPerNode': {'def': 128},
          'memory': {'def': '235GB', 'typ': str},
          'queue': {'def': hpc['CriticalQueue']},
          'account': {'def': hpc['CriticalAccount']},
          'job_priority': {'def': hpc['CriticalPriority']},
        }
        concatjob = Resource(self._conf, concatattr, ('concat.job'))
        concattask = TaskLookup[hpc.system](concatjob)
        args = [
        self.lower,
        self.workDir+'/{{thisCycleDate}}',
        "",
        ]
        concatArgs = ' '.join(['"'+str(a)+'"' for a in args])
        self._tasks += ['''
  [[ConcatEnKF]]
    inherit = BATCH
    script = $origin/bin/ConcatenateObsFeedback.csh '''+concatArgs+'''
'''+concattask.job()+concattask.directives()]
        self._dependencies += ['''
        EnKFSolver => ConcatEnKF => '''+self.tf.post]

      self._dependencies += ['''

        # EnKF
        EnKFObserver => EnKFSolver''']
