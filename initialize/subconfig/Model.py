#!/usr/bin/env python3

from initialize.SubConfig import SubConfig

class Mesh():
  def __init__(self, name, nCells, attrib=None):
    self.name = str(name)
    self.nCells = int(nCells)
    self.attrib = attrib

class Model(SubConfig):
  defaults = 'scenarios/base/model.yaml'
  baseKey = 'model'
  # mesh descriptors, e.g.:
  # uniform spacing: 30km, 60km, 120km
  # variable spacing: ?

  requiredVariables = {
  }

  optionalVariables = {
  ## outerMesh [Required Parameter]
  # variational outer loop, forecast, HofX, verification
    'outerMesh': str,

  ## innerMesh [Optional, used in Variational]
  # variational inner loop
    'innerMesh': str,

  ## ensembleMesh [Optional, used in Variational]
  # variational ensemble, rtpp
  # note: mpas-jedi requires innerMesh and ensembleMesh to be equal at this time
    'ensembleMesh': str,
  }

  variablesWithDefaults = {
    ## GraphInfoDir
    # directory containing x1.{{nCells}}.graph.info* files
    'GraphInfoDir': ['/glade/p/mmm/parc/liuz/pandac_common/static_from_duda', str],

    ## precision
    # floating-point precision of all application output
    # OPTIONS: single, double
    'precision': ['single', str],
  }

  def __init__(self, config):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._set('model__precision', self.get('precision'))

    TemplateFieldsPrefix = 'templateFields'
    self._set('TemplateFieldsPrefix', TemplateFieldsPrefix)

    localStaticFieldsPrefix = 'static'
    self._set('localStaticFieldsPrefix', localStaticFieldsPrefix)

    MPASCore = 'atmosphere'
    self._set('MPASCore', MPASCore)

    StreamsFile = 'streams.'+MPASCore
    self._set('StreamsFile', StreamsFile)

    NamelistFile = 'namelist.'+MPASCore
    self._set('NamelistFile', NamelistFile)

    self._set('StreamsFileInit', 'streams.init_'+MPASCore)
    self._set('NamelistFileInit', 'namelist.init_'+MPASCore)
    self._set('NamelistFileWPS', 'namelist.wps')

    self.meshes = {}
    for typ in ['outer', 'inner', 'ensemble']:
      m = typ+'Mesh'
      Typ = typ.capitalize()

      mesh = self.get(m)
      if mesh is not None:
        self._set('nCells'+Typ, config.getOrDie(mesh+'.nCells'))
        nCells = self.get('nCells'+Typ)

        self.meshes[Typ] = Mesh(mesh, nCells)

        self._set('InitFilePrefix'+Typ, 'x1.'+str(nCells)+'.init')
        self._set(typ+'StreamsFile', StreamsFile+'_'+mesh)
        self._set(typ+'NamelistFile', NamelistFile+'_'+mesh)
        self._set('TemplateFieldsFile'+Typ, TemplateFieldsPrefix+'.'+str(nCells)+'.nc')
        self._set('localStaticFieldsFile'+Typ, localStaticFieldsPrefix+'.'+str(nCells)+'.nc')

        if Typ == 'Outer':
          self._set('TimeStep', config.getOrDie(mesh+'.TimeStep'))
          self._set('DiffusionLengthScale', config.getOrDie(mesh+'.DiffusionLengthScale'))

    allMeshes = [mesh.name for mesh in self.meshes.values()]
    self.meshes['allMeshes'] = str(allMeshes)

    self._set('allMeshes', allMeshes)

    ###############################
    # export for use outside python
    ###############################
    csh = list(self._table.keys())
    cylc = ['allMeshes']
    self.exportVars(csh, cylc)
