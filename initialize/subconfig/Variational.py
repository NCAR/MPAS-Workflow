#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Variational(SubConfig):
  baseKey = 'variational'
  defaults = 'scenarios/defaults/variational.yaml'

  WorkDir = 'CyclingDA'

  requiredVariables = {
    ## DAType [Required Parameter]
    # OPTIONS: 3dvar, 3denvar, 3dhybrid
    'DAType': str,
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
    # OPTIONS: DRIPCG, DRPLanczos, DRPBlockLanczos
    # see classes derived from oops/src/oops/assimilation/Minimizer.h for all options
    # Notes about DRPBlockLanczos:
    # + still experimental, and not reliable for this experiment
    # + only available when EDASize > 1
    'MinimizerAlgorithm': ['DRIPCG', str],

    ## SelfExclusion, whether exclude own background from the ensemble B perturbations in EnVar during EDA cycling
    'SelfExclusion': [True, bool],

    ### EDA
    # an ensemble of variational data assimilations (EDA) will be carried out
    # whenever members.n > 1

    # One can modify EDASize such that members.n=(EDASize * nDAInstances)
    # members.n is also the number of forecasts used to represent the flow-dependent background
    # error covariance when DAType is 3denvar or 3dhybrid

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
    # OPTIONS: 8, 9, 10
    'ABEIChannel': [8, int],


    ## benchmarkObservations
    # base set of observation types assimilated in all experiments
    'benchmarkObservations': [[
      # anchor
      'aircraft',
      'gnssroref',
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
    ], list],

    ## experimentalObservations
    # observation types assimilated in variational application instances
    # in addition to the benchmarkObservations
    # Abbreviations:
    #   clr == clear-sky
    #   cld == cloudy-sky
    'experimentalObservations': [[
      # MW satellite-based
      #'amsua-cld_aqua',
      #'amsua-cld_metop-a',
      #'amsua-cld_metop-b',
      #'amsua-cld_n15',
      #'amsua-cld_n18',
      #'amsua-cld_n19',
      #'mhs_n19',
      #'mhs_n18',
      #'mhs_metop-a',
      #'mhs_metop-b',
      # IR satellite-based
      #'abi_g16',
      #'ahi_himawari8',
      #'abi-clr_g16',
      #'ahi-clr_himawari8',
      #'iasi_metop-a',
      #'iasi_metop-b',
      #'iasi_metop-c',
    ], list],

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
    'tropprsMethod': ['thompson', str],

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

  def __init__(self, config, meshes, model, members, workflow): #, forecast):
    super().__init__(config)

    cylc = []

    ###################
    # derived variables
    ###################
    DAType = self.get('DAType')
    self._set('AppName', DAType)
    self._set('appyaml', DAType+'.yaml')
    self._set('YAMLPrefix', DAType+'_')

    self._set('MeshList', ['Outer', 'Inner'])
    self._set('nCellsList', [meshes['Outer'].nCells, meshes['Inner'].nCells])
    self._set('StreamsFileList', [model.get('outerStreamsFile'), model.get('innerStreamsFile')])
    self._set('NamelistFileList', [model.get('outerNamelistFile'), model.get('innerNamelistFile')])
    self._set('localStaticFieldsFileList', [model.get('localStaticFieldsFileOuter'), model.get('localStaticFieldsFileInner')])

    # combine both sets of observations together
    self._set('observations', list(set(self.get('benchmarkObservations') + self.get('experimentalObservations'))))

    # nOuterIterations, automatically determined from length of nInnerIterations
    self._set('nOuterIterations', len(self.get('nInnerIterations')))

    # determine nDAInstances from members.n and EDASize
    NN = members.n
    EDASize = self.get('EDASize')
    assert NN > 0, ('members.n must be greater than 0')
    assert NN % EDASize == 0 and EDASize > 0, ('members.n must be divisible by EDASize')
    self._set('nDAInstances', NN // EDASize)

    BlockEDA = 'DRPBlockLanczos'
    self._set('BlockEDA', BlockEDA)
    if EDASize == 1 and self.get('MinimizerAlgorithm') == BlockEDA:
      print("WARNING: MinimizerAlgorithm cannot be $BlockEDA when EDASize is 1, re-setting to DRPLanczos")
      self._set('MinimizerAlgorithm', 'DRPLanczos')

    # ensemble
    if DAType == '3denvar' or DAType == '3dhybrid':
      # localization
      r1 = 'ensemble.localization'
      r2 = meshes['Ensemble'].name
      self._setOrDie('.'.join([r1, r2, 'bumpLocPrefix']), str, 'bumpLocPrefix')
      self._setOrDie('.'.join([r1, r2, 'bumpLocDir']), str, 'bumpLocDir')

      # forecasts
      if NN > 1:
        # EDA uses online ensemble updating
        self._set('ensPbMemPrefix', workflow.MemPrefix)
        self._set('ensPbMemNDigits', workflow.MemNDigits)
        self._set('ensPbFilePrefix', 'mpasout')
        self._set('ensPbDir0', '{{ExperimentDirectory}}/CyclingFC/{{prevDateTime}}')
        # TODO: replace two lines above with these when forecast includes these attributes
        #self._set('ensPbFilePrefix', forecast.outputFilePrefix)
        #self._set('ensPbDir0', '{{ExperimentDirectory}}/'+forecast.WorkDir+'/{{prevDateTime}}')
        self._set('ensPbDir1', None)

        ensPbNMembers = NN

        # TODO: this needs to be non-zero for EDA workflows that use IAU, get value from forecast
        self._set('ensPbOffsetHR', 0)

      else:
        resource = config.getOrDie('ensemble.forecasts.resource')
        r1 = 'ensemble.forecasts'
        r2 = '.'.join([resource, meshes['Ensemble'].name])

        memberPrefix = str(self.extractResourceOrDefault(r1, r2, 'memberPrefix', '')) # default is empty string
        memberNDigits = int(self.extractResourceOrDie(r1, r2, 'memberNDigits'))
        filePrefix = str(self.extractResourceOrDie(r1, r2, 'filePrefix'))
        directory0 = str(self.extractResourceOrDie(r1, r2, 'directory0'))
        directory1 = str(self.extractResource(r1, r2, 'directory1')) # can be empty
        maxMembers = int(self.extractResourceOrDie(r1, r2, 'maxMembers'))
        forecastDateOffsetHR = int(self.extractResourceOrDie(r1, r2, 'forecastDateOffsetHR'))

        self._set('ensPbMemPrefix', memberPrefix)
        self._set('ensPbMemNDigits', memberNDigits)
        self._set('ensPbFilePrefix', filePrefix)
        self._set('ensPbDir0', directory0)
        self._set('ensPbDir1', directory1)
        ensPbNMembers = maxMembers
        self._set('ensPbOffsetHR', forecastDateOffsetHR)

    else:
      ensPbNMembers = 0

    self._set('ensPbNMembers', ensPbNMembers)

    # covariance
    if DAType == '3dvar' or DAType == '3dhybrid':
      r = meshes['Inner'].name
      self._setOrDie('covariance.bumpCovControlVariables', list, 'bumpCovControlVariables')
      self._setOrDie('covariance.bumpCovPrefix', str, 'bumpCovPrefix')
      self._setOrDie('covariance.bumpCovVBalPrefix', str, 'bumpCovVBalPrefix')
      self._setOrDie('.'.join(['covariance', r, 'bumpCovDir']), str, 'bumpCovDir')
      self._setOrDie('.'.join(['covariance', r, 'bumpCovStdDevFile']), str, 'bumpCovStdDevFile')
      self._setOrDie('.'.join(['covariance', r, 'bumpCovVBalDir']), str, 'bumpCovVBalDir')

    # all csh variables above
    csh = list(self._vtable.keys())

    # job resource settings
    meshesKey = meshes['Outer'].name+'.'+meshes['Inner'].name

    retry = self.extractResourceOrDie('job', None, 'retry')
    baseSeconds = str(int(self.extractResourceOrDie('job', meshesKey, 'baseSeconds')))
    secondsPerEnVarMember = str(int(self.extractResourceOrDefault('job', meshesKey, 'secondsPerEnVarMember', 0)))
    nodes = str(int(self.extractResourceOrDie('job', meshesKey, 'nodes')))
    PEPerNode = str(int(self.extractResourceOrDie('job', meshesKey, 'PEPerNode')))
    memory = str(int(self.extractResourceOrDie('job', meshesKey, 'memory')))

    seconds = secondsPerEnVarMember * ensPbNMembers + baseSeconds

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(csh, cylc)

    tasks = [
'''
# variational
  [[InitDataAssim]]
    inherit = BATCH
    env-script = cd {{mainScriptDir}}; ./applications/PrepJEDIVariational.csh "1" "0" "DA" "variational"
    script = $origin/applications/PrepVariational.csh "1"
    [[[job]]]
      execution time limit = PT20M
      execution retry delays = '''+retry+'''

  [[DataAssim]]
    inherit = BATCH

  [[CleanVariational]]
    inherit = CleanBase
    script = $origin/applications/CleanVariational.csh''']

    if EDASize == 1: 
      # EDASize > 1 handled in EnsVariational class (maybe consider combining)
      # single instance or ensemble of Variational(s)
      for mm in range(1, NN+1, 1):
        tasks += ['''
  [[DAMember'''+str(mm)+''']]
    inherit = DataAssim
    script = $origin/applications/Variational.csh "'''+str(mm)+'''"
    [[[job]]]
      execution time limit = PT'''+seconds+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -m = ae
      -q = {{CPQueueName}}
      -A = {{CPAccountNumber}}
      -l = select=${nodes_}:ncpus=${PEPerNode_}:mpiprocs=${PEPerNode_}:mem=${memory_}GB
      -l = select='''+nodes+':ncpus='+PEPerNode+':mpiprocs='+PEPerNode+':mem='+memory+'''GB''']

    self.exportTasks(tasks)

    dependencies = ['#']
    if self.get('ABEInflation'):
      dependencies += ['''
        ForecastFinished[-PT{{FC2DAOffsetHR}}H] =>
        MeanBackground =>
        HofXEnsMeanBG =>
        GenerateABEInflation => PreDataAssim
        GenerateABEInflation => CleanHofXEnsMeanBG''']

    self.exportDependencies(dependencies)
