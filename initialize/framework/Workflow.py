#!/usr/bin/env python3

import datetime as dt
import tools.dateFormats as dtf

from initialize.Component import Component
from initialize.Config import Config

class Workflow(Component):
  variablesWithDefaults = {
    #dates
    'first cycle point': ['20180414T18', str],
    'final cycle point': ['20180514T18', str],

    # interval between `da` analyses
    'CyclingWindowHR': [6, int, [6]],

    # window of observations included in AN/BG verification
    'DAVFWindowHR': [6, int, [6]],

    # window of observations included in forecast verification
    'FCVFWindowHR': [6, int, [6]],

    # maximum consecutive cycle points to be active at any time
    'max active cycle points': [4, int],

    ################
    # task selection
    ################
    ## CriticalPathType: controls dependencies between and chilrdren of
    #                   `da` and `forecast` mini-workflows for Cycle suite
    # OPTIONS:
    # + Normal - run both the `da` and `forecast` mini-workflows, each with a dependency on the
    #            previous instance of the other
    #          - run selected verification elements with dependence on the `da` and `forecast`
    #            mini-workflow sub-tasks
    # + Bypass - do not run either `da` or `forecast` mini-workflows
    #          - only run `verification` mini-workflows, including non-critical path forecasts, e.g.,
    #            VerifyExtendedMeanFC
    # + Reanalysis
    #   - run only the `da` mini-workflow in the critical path, and also verification
    #   - requires CyclingFC forecast files or links to already be present in ExperimentDirectory
    # + Reforecast
    #   - run only the `forecast` mini-workflow in the critical path, and also verification
    #   - requires CyclingDA analysis files or links to already be present in ExperimentDirectory
    # Users may choose whether to run the verification concurrently with and
    # dependent on the critical path tasks (`Normal`), or as an independent post-processing step
    # (`Bypass`). `Normal` and `Bypass` cover most use-cases for "continuous cycling" experiments.
    #
    # Setting `CriticalPathType` to either `Reanalysis` or `Reforecast` gives two variations of
    # "partial cycling", where each cycle is independent and does not depend on any of the previous
    # cycles. `Reanalysis` is used to perform the `da` task on each cycle without re-running
    # forecasts.  This requires the `forecast` output files to already be present in the experiment
    # directory.  If the user wishes to do this for independently-generated forecasts (i.e., from a
    # previous separate experiment or a set of forecasts generated outside `MPAS-Workflow`), they
    # must manually create an experiment directory, then either link or copy the forecast files into the
    # `CyclingFC` directory following the usual directory structure and file-naming conventions.
    # `Reforecast` is used to perform forecasts from an existing set of analysis states, which similarly
    # must be already stored or linked in the `CyclingDA` directory following normal directory structures
    # and file naming conventions.  It is recommended to run at least one `Normal` experiment to
    # demonstrate the correct directory structure before trying either of the `Reanalysis` or
    # `Reforecast` options.
    'CriticalPathType': ['Normal', str, ['Normal', 'Bypass', 'Reanalysis', 'Reforecast']],

    ## VerifyExtendedMeanFC: whether to run verification scripts across
    #    extended forecast states, first intialized at mean analysis
    'VerifyExtendedMeanFC': [False, bool],

    ## VerifyExtendedEnsBG: whether to run verification scripts across
    #    extended forecast states, first intialized at ensemble of analysis
    #    states.
    'VerifyExtendedEnsFC': [False, bool],
  }

  def __init__(self, config:Config):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    firstCyclePoint = self['first cycle point']
    CyclingWindowHR = self['CyclingWindowHR']

    ## restart cycle point (optional)
    # OPTIONS: >= FirstCycleDate (see config/experiment.csh)
    # Either:
    # + restartCyclePoint defaults to or is manually set equal to firstCyclePoint
    # OR:
    # + restartCyclePoint > FirstCyclePoint to automatically restart from a previously completed cycle.
    #   CyclingFC output must already be present from the cycle before restartCyclePoint.
    self._setOrDefault('restart cycle point', firstCyclePoint)

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
      self._set('AnalysisTimes', '+PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting DA2FCOffsetHR hours after the
      # restartCyclePoint
      self._set('ForecastTimes', '+PT'+str(DA2FCOffsetHR)+'H/PT'+str(CyclingWindowHR)+'H')

    self._cshVars = list(self._vtable.keys())

    # substitution variables to be passed directly to task scripts instead of parsed with Jinja2
    substitutionVars = [
      'thisValidDate',
      'thisCycleDate',
      'prevCycleDate',
    ]
    for v in substitutionVars:
      # create cylc variable named v, with value '{{'+v+'}}', overriding Jinja2
      self._set(v, '{{'+v+'}}')
    self._cylcVars = list(self._vtable.keys())
