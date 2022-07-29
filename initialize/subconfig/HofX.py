#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class HofX(SubConfig):
  baseKey = 'hofx'
  defaults = 'scenarios/defaults/hofx.yaml'

  variablesWithDefaults = {
  ## observations
  # observation types simulated in hofx application instances for verification
  # OPTIONS: see list below
  # Abbreviations:
  #   clr == clear-sky
  #   cld == cloudy-sky
    'observations': [[
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
      'amsua-cld_aqua',
      'amsua-cld_metop-a',
      'amsua-cld_metop-b',
      'amsua-cld_n15',
      'amsua-cld_n18',
      'amsua-cld_n19',
      'mhs_n19',
      'mhs_n18',
      'mhs_metop-a',
      'mhs_metop-b',
      # IR satellite-based
      'abi_g16',
      'ahi_himawari8',
      #'abi-clr_g16',
      #'ahi-clr_himawari8',
      #'iasi_metop-a',
      #'iasi_metop-b',
      #'iasi_metop-c',
    ], list],

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
  def __init__(self, config, meshes, model):
    super().__init__(config)

    cylc = []

    ###################
    # derived variables
    ###################
    self._set('AppName', 'hofx')
    self._set('appyaml', 'hofx.yaml')

    self._set('MeshList', ['HofX'])
    self._set('nCellsList', [meshes['Outer'].nCells])
    self._set('StreamsFileList', [model.get('outerStreamsFile')])
    self._set('NamelistFileList', [model.get('outerNamelistFile')])

    # all csh variables above
    csh = list(self._vtable.keys())

    retry = self.extractResourceOrDie('job', None, 'retry')
    seconds = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'seconds')))
    nodes = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'nodes')))
    PEPerNode = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'PEPerNode')))
    memory = str(int(self.extractResourceOrDie('job', meshes['Outer'].name, 'memory')))

    ###############################
    # export for use outside python
    ###############################
    self.exportVars(csh, cylc)

    tasks = [
'''
  [[HofXBase]]
    inherit = BATCH
    [[[job]]]
      execution time limit = PT'''+seconds+'''S
      execution retry delays = '''+retry+'''
    [[[directives]]]
      -q = {{NCPQueueName}}
      -A = {{NCPAccountNumber}}
      -l = select='''+nodes+':ncpus='+PEPerNode+':mpiprocs='+PEPerNode+':mem='+memory+'GB']

    self.exportTasks(tasks)
