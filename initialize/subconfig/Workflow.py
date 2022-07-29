#!/usr/bin/env python3

import datetime as dt
import tools.dateFormats as dtf

from initialize.SubConfig import SubConfig

class Workflow(SubConfig):
  baseKey = 'workflow'
  variablesWithDefaults = {
    #dates
    'firstCyclePoint': ['20180414T18', str],
    'finalCyclePoint': ['20180514T18', str],

    ################
    # task selection
    ################
    ## CriticalPathType: controls dependencies between and chilrdren of
    #                   `da` and `forecast` mini-workflows
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
    # + GenerateExternalAnalyses
    #   - runs only the PrepareExternalAnalysis mini-workflow
    #   - no dependencies between cycles
    # + GenerateObs
    #   - runs only the PrepareObservations mini-workflow
    #   - no dependencies between cycles
    # + ForecastFromExternalAnalyses
    #   - runs PrepareExternalAnalysis mini-workflow and ExtendedFCFromExternalAnalysis
    #   - no dependencies between cycles
    #
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
    'CriticalPathType': ['Normal', str],

    ## VerifyAgainstObservations: whether to verify against observations using
    #    HofX applications evaluated at model forecasts or analysis states
    'VerifyAgainstObservations': [True, bool],

    ## VerifyAgainstExternalAnalyses: whether to verify against external model analysis states
    #    Note: only enabled for GFS analyses
    'VerifyAgainstExternalAnalyses': [True, bool],

    ## VerifyDeterministicDA: whether to run verification scripts for
    #    obs feedback files produced by DA.  Does not work for ensemble DA.
    #    Only works when CriticalPathType == Normal.
    'VerifyDeterministicDA': [True, bool],

    ## CompareDA2Benchmark: compare verification statistics files between two experiments
    #    after the DA verification completes
    'CompareDA2Benchmark': [False, bool],

    ## VerifyExtendedMeanFC: whether to run verification scripts across
    #    extended forecast states, first intialized at mean analysis
    'VerifyExtendedMeanFC': [False, bool],

    ## VerifyBGMembers: whether to run verification scripts for CyclingWindowHR
    #    forecast length. Runs HofXBG, VerifyObsBG, and VerifyModelBG on critical
    #    path forecasts that are initialized from ensemble member analyses.
    'VerifyBGMembers': [False, bool],

    ## CompareBG2Benchmark: compare verification statistics files between two experiments
    #    after the BGMembers verification completes
    'CompareBG2Benchmark': [False, bool],

    ## VerifyEnsMeanBG: whether to run verification scripts for ensemble mean
    #    background (members.n > 1) or deterministic background (members.n == 1)
    'VerifyEnsMeanBG': [True, bool],

    ## DiagnoseEnsSpreadBG: whether to diagnose the ensemble spread in observation
    #    space while VerifyEnsMeanBG is True.  Automatically triggers HofXBG
    #    for all ensemble members.
    'DiagnoseEnsSpreadBG': [True, bool],

    ## VerifyEnsMeanAN: whether to run verification scripts for ensemble
    #    mean analysis state.
    'VerifyANMembers': [False, bool],

    ## VerifyExtendedEnsBG: whether to run verification scripts across
    #    extended forecast states, first intialized at ensemble of analysis
    #    states.
    'VerifyExtendedEnsFC': [False, bool],

    # maximum consecutive cycle points to be active at any time
    'maxActiveCyclePoints': [4, int],

    ##################################
    ## analysis and forecast intervals
    ##################################
    # interval between `da` analyses
    'CyclingWindowHR': [6, int],

    # window of observations included in AN/BG verification
    'DAVFWindowHR': [6, int],

    # window of observations included in forecast verification
    'FCVFWindowHR': [6, int],
  }
  def __init__(self, config):
    super().__init__(config)

    ###################
    # derived variables
    ###################

    firstCyclePoint = self.get('firstCyclePoint')
    CyclingWindowHR = self.get('CyclingWindowHR')

    ## initialCyclePoint (optional)
    # OPTIONS: >= FirstCycleDate (see config/experiment.csh)
    # Either:
    # + initialCyclePoint defaults to or is manually set equal to firstCyclePoint
    # OR:
    # + initialCyclePoint > FirstCyclePoint to automatically restart from a previously completed cycle.
    #   CyclingFC output must already be present from the cycle before initialCyclePoint.
    self._setOrDefault('initialCyclePoint', firstCyclePoint)


    ## FirstCycleDate in directory structure format
    date = dt.datetime.strptime(firstCyclePoint, dtf.abbrevISO8601Fmt)
    self._set('FirstCycleDate', date.strftime(dtf.cycleFmt))


    ## next date after first background is initialized
    step = dt.timedelta(hours=CyclingWindowHR)
    self._set('nextFirstCycleDate', (date+step).strftime(dtf.cycleFmt))
    self._set('nextFirstFileDate', (date+step).strftime(dtf.MPASFileFmt))


    ## DA2FCOffsetHR and FC2DAOffsetHR: control the offsets between DataAssim and Forecast
    # tasks in the critical path
    # TODO: set DA2FCOffsetHR and FC2DAOffsetHR based on IAU controls
    self._set('DA2FCOffsetHR', 0)
    self._set('FC2DAOffsetHR', CyclingWindowHR)

    MemPrefix = 'mem'
    MemNDigits = 3
    self.MemPrefix = MemPrefix
    self.MemNDigits = MemNDigits
    self._set('flowMemFmt', '/'+MemPrefix+'{:0'+str(MemNDigits)+'d}')
    self._set('flowInstanceFmt', '/instance{:0'+str(MemNDigits)+'d}')
    self._set('flowMemFileFmt', '_{:0'+str(MemNDigits)+'d}')

    # Differentiate between creating the workflow suite for the first time
    # and restarting (i.e., when initialCyclePoint > firstCyclePoint)
    if (self.get('initialCyclePoint') == firstCyclePoint):
      # The analysis will run every CyclingWindowHR hours, starting CyclingWindowHR hours after the
      # initialCyclePoint
      self._set('AnalysisTimes', '+PT'+str(CyclingWindowHR)+'H/PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting CyclingWindowHR+DA2FCOffsetHR hours
      # after the initialCyclePoint
      ColdFCOffset = CyclingWindowHR + self.get('DA2FCOffsetHR')
      self._set('ForecastTimes', '+PT'+str(ColdFCOffset)+'H/PT'+str(CyclingWindowHR)+'H')

    else:
      # The analysis will run every CyclingWindowHR hours, starting at the initialCyclePoint
      self._set('AnalysisTimes', '+PT'+str(CyclingWindowHR)+'H')

      # The forecast will run every CyclingWindowHR hours, starting DA2FCOffsetHR hours after the
      # initialCyclePoint
      self._set('ForecastTimes', '+PT'+str(DA2FCOffsetHR)+'H/PT'+str(CyclingWindowHR)+'H')


    ###############################
    # export for use outside python
    ###############################
    csh = list(self._vtable.keys())
    cylc = list(self._vtable.keys())
    self.exportVars(csh, cylc)
