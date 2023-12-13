#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

from copy import deepcopy

from initialize.config.Component import Component
from initialize.config.Config import Config

class Mesh():
  def __init__(self, name, nCells, attrib=None):
    self.name = str(name)
    self.nCells = int(nCells)
    self.attrib = attrib

  def __eq__(self, other):
    return all([
      isinstance(other, Mesh),
      other.name == self.name,
      other.nCells == self.nCells,
      (other.attrib is None and self.attrib is None) or (other.attrib == self.attrib),
    ])


class Model(Component):
  defaults = 'scenarios/defaults/model.yaml'
  # mesh descriptors, e.g.:
  # uniform spacing: 30km, 60km, 120km
  # variable spacing: ?

  requiredVariables = {
  }

  optionalVariables = {
    ## outerMesh [Required Parameter]
    # Variational outer loop, Forecast, HofX, verification
    'outerMesh': str,

    # TODO: specify these inner and ensemble meshes under da classes (variational, enkf, etc...)
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
    'GraphInfoDir': ['/glade/campaign/mmm/parc/liuz/pandac_common/static_from_duda', str],

    ## precision
    # floating-point precision of all application output
    # OPTIONS: single, double
    'precision': ['single', str],
  }

  def __init__(self, config:Config):
    super().__init__(config)

    ###################
    # derived variables
    ###################
    self._set('model__precision', self['precision'])

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

    self.__meshes = {}
    for meshTyp in ['outer', 'inner', 'ensemble']:
      m = meshTyp+'Mesh'
      Typ = meshTyp.capitalize()

      name = self[m]
      if name is not None:
        self._set('nCells'+Typ, self._conf.getOrDie('resources.'+name+'.nCells'))
        nCells = self['nCells'+Typ]

        self.__meshes[Typ] = Mesh(name, nCells)

        self._set('InitFilePrefix'+Typ, 'x1.'+str(nCells)+'.init')
        self._set(meshTyp+'StreamsFile', StreamsFile+'_'+name)
        self._set(meshTyp+'NamelistFile', NamelistFile+'_'+name)
        self._set('TemplateFieldsFile'+Typ, TemplateFieldsPrefix+'.'+str(nCells)+'.nc')
        self._set('localStaticFieldsFile'+Typ, localStaticFieldsPrefix+'.'+str(nCells)+'.nc')

        if Typ == 'Outer':
          self._set('TimeStep', self._conf.getOrDie('resources.'+name+'.TimeStep'))
          self._set('DiffusionLengthScale', self._conf.getOrDie('resources.'+name+'.DiffusionLengthScale'))

    self._cshVars = list(self._vtable.keys())

  def getMeshes(self):
    return deepcopy(self.__meshes)
