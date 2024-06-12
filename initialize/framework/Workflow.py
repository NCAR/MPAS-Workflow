#!/usr/bin/env python3

'''
 (C) Copyright 2023 UCAR

 This software is licensed under the terms of the Apache Licence Version 2.0
 which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
'''

import datetime as dt
import tools.dateFormats as dtf

from initialize.config.Component import Component
from initialize.config.Config import Config

class Workflow(Component):
  variablesWithDefaults = {
    #dates
    'first cycle point': ['20180414T18', str],
    'final cycle point': ['20180514T18', str],

    # interval between `da` analyses
    'CyclingWindowHR': [6, int, [6]],

    # maximum consecutive cycle points to be active at any time
    'max active cycle points': [4, int],

    # maximum concurrent placeholder tasks
    # constrains background placholder task count to avoid over-utilizing login node
    'max concurrent placeholder tasks': [20, int],

    # default submission timeout for all cylc tasks
    # note: overridden in come cylc tasks (e.g., under InitIC and ExternalAnalyses)
    'submission timeout': ['PT90M', str],

    ## 4denvar || 4dhybrid
    'subwindow': [1, int],

    # interval between `saca` analyses and forecast background
    'prevBgHR': [0, int, [0]],
  }
  optionalVariables = {
    # restart cycle point is used to restart an existing suite from a previously-generated
    # forecast at a date that is after 'first cycle point'
    'restart cycle point': str,
  }

  def __init__(self, config:Config):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    firstCyclePoint = self['first cycle point']
    CyclingWindowHR = self['CyclingWindowHR']
    subwindow = self['subwindow']

    ## restart cycle point (optional)
    # OPTIONS: >= FirstCycleDate (see config/experiment.csh)
    # Either:
    # + restartCyclePoint defaults to or is manually set equal to firstCyclePoint
    # OR:
    # + restartCyclePoint > FirstCyclePoint to automatically restart from a previously completed cycle.
    #   CyclingFC output must already be present from the cycle before restartCyclePoint.
    if self['restart cycle point'] is None:
      self._set('restart cycle point', firstCyclePoint)

    ## FirstCycleDate in directory structure format
    first = dt.datetime.strptime(firstCyclePoint, dtf.abbrevISO8601Fmt)
    self._set('FirstCycleDate', first.strftime(dtf.cycleFmt))

    ## next date after first background is initialized
    step = dt.timedelta(hours=CyclingWindowHR)
    self._set('nextFirstCycleDate', (first+step).strftime(dtf.cycleFmt))
    self._set('nextFirstFileDate', (first+step).strftime(dtf.MPASFileFmt))

    ## DA2FCOffsetHR and FC2DAOffsetHR: control the offsets between DA and Forecast
    # tasks in the critical path
    # TODO: set DA2FCOffsetHR and FC2DAOffsetHR based on IAU controls
    DA2FCOffsetHR = 0
    self._set('DA2FCOffsetHR', DA2FCOffsetHR)
    self._set('FC2DAOffsetHR', CyclingWindowHR)

    MemPrefix = 'mem'
    MemNDigits = 3
    self.MemPrefix = MemPrefix
    self.MemNDigits = MemNDigits
    self._set('flowMemFmt', '/'+MemPrefix+'{:0'+str(MemNDigits)+'d}')
    self._set('flowInstanceFmt', '/instance{:0'+str(MemNDigits)+'d}')
    self._set('flowMemFileFmt', '_{:0'+str(MemNDigits)+'d}')

    self._set('AnalysisTimesSACA', '+PT'+str(CyclingWindowHR)+'H/PT'+str(CyclingWindowHR)+'H')
    self._set('ForecastTimesSACA', '+PT'+str(CyclingWindowHR)+'H/PT'+str(CyclingWindowHR)+'H')

    # Differentiate between creating the workflow suite for the first time
    # and restarting (i.e., when restartCyclePoint > firstCyclePoint)
    if (self['restart cycle point'] == firstCyclePoint):
      # The analysis will run every CyclingWindowHR hours, starting CyclingWindowHR hours after the
      # restartCyclePoint
      self._set('AnalysisTimes', '+PT'+str(CyclingWindowHR)+'H/PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting CyclingWindowHR+DA2FCOffsetHR hours
      # after the restartCyclePoint
      ColdFCOffset = CyclingWindowHR + DA2FCOffsetHR
      self._set('ForecastTimes', '+PT'+str(ColdFCOffset)+'H/PT'+str(CyclingWindowHR)+'H')

    else:
      # The analysis will run every CyclingWindowHR hours, starting at the restartCyclePoint
      self._set('AnalysisTimes', 'PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting DA2FCOffsetHR hours after the
      # restartCyclePoint
      self._set('ForecastTimes', '+PT'+str(DA2FCOffsetHR)+'H/PT'+str(CyclingWindowHR)+'H')

    self._cshVars = list(self._vtable.keys())
