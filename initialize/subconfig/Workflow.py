#!/usr/bin/env python3

import datetime as dt
import tools.dateFormats as dtf

from initialize.SubConfig import SubConfig

class Workflow(SubConfig):
  defaults = 'scenarios/base/workflow.yaml'
  baseKey = 'workflow'
  baseVariables = [
    #dates
    'firstCyclePoint',
    'finalCyclePoint',
    # critical path selection
    'CriticalPathType',
    # verification
    'VerifyAgainstObservations',
    'VerifyAgainstExternalAnalyses',
    'VerifyDeterministicDA',
    'CompareDA2Benchmark',
    'VerifyExtendedMeanFC',
    'VerifyBGMembers',
    'CompareBG2Benchmark',
    'VerifyEnsMeanBG',
    'DiagnoseEnsSpreadBG',
    'VerifyANMembers',
    'VerifyExtendedEnsFC',
    # maximum active cycle points
    'maxActiveCyclePoints',
    # durations and intervals
    'CyclingWindowHR',
    'DAVFWindowHR',
    'FCVFWindowHR',
  ]
  def __init__(self, config):
    super().__init__(config)

    ##############
    # parse config
    ##############
    for v in self.baseVariables:
      self.setOrDie(v)

    # derived variables
    firstCyclePoint = self.get('firstCyclePoint')
    self.setOrDefault('initialCyclePoint', firstCyclePoint)


    ## FirstCycleDate in directory structure format
    date = dt.datetime.strptime(firstCyclePoint, dtf.abbrevISO8601Fmt)
    self.set('FirstCycleDate', date.strftime(dtf.cycleFmt))


    ## next date after first background is initialized
    CyclingWindowHR = self.get('CyclingWindowHR')
    step = dt.timedelta(hours=CyclingWindowHR)
    self.set('nextFirstCycleDate', (date+step).strftime(dtf.cycleFmt))
    self.set('nextFirstFileDate', (date+step).strftime(dtf.MPASFileFmt))


    ## DA2FCOffsetHR and FC2DAOffsetHR: control the offsets between DataAssim and Forecast
    # tasks in the critical path
    # TODO: set DA2FCOffsetHR and FC2DAOffsetHR based on IAU controls
    self.set('DA2FCOffsetHR', 0)
    self.set('FC2DAOffsetHR', CyclingWindowHR)


    # Differentiate between creating the workflow suite for the first time
    # and restarting (i.e., when initialCyclePoint > firstCyclePoint)
    if (self.get('initialCyclePoint') == firstCyclePoint):
      # The analysis will run every CyclingWindowHR hours, starting CyclingWindowHR hours after the
      # initialCyclePoint
      self.set('AnalysisTimes', '+PT'+str(CyclingWindowHR)+'H/PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting CyclingWindowHR+DA2FCOffsetHR hours
      # after the initialCyclePoint
      ColdFCOffset = CyclingWindowHR + self.get('DA2FCOffsetHR')
      self.set('ForecastTimes', '+PT'+str(ColdFCOffset)+'H/PT'+str(CyclingWindowHR)+'H')

    else:
      # The analysis will run every CyclingWindowHR hours, starting at the initialCyclePoint
      self.set('AnalysisTimes', '+PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting DA2FCOffsetHR hours after the
      # initialCyclePoint
      self.set('ForecastTimes', '+PT'+str(DA2FCOffsetHR)+'H/PT'+str(CyclingWindowHR)+'H')


    #################################
    # auto-generate shell config file
    #################################
    cshVariables = list(self._table.keys())
    cshStr = self.initCsh()
    for v in cshVariables:
      cshStr += self.varToCsh(v, self._table[v])

    self.write('config/workflow.csh', cshStr)

    ##################################
    # auto-generate cylc include files
    ##################################
    cylcVariables = list(self._table.keys())
    cylcStr = []
    for v in cylcVariables:
      cylcStr += self.varToCylc(v, self._table[v])

    self.write('include/variables/auto/workflow.rc', cylcStr)
