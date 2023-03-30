#!/bin/csh -f


#############################
## config directory structure
#############################
setenv configDir config
setenv modelConfigDir config/mpas

setenv PackageBaseName 'MPAS-Workflow'

##########################
## run directory structure
##########################

# directory names that must be consistent across experiments in order to perform cross-experiment
# verification and/or comparison
set DataAssim = CyclingDA
set Forecast = CyclingFC
set Verification = Verification

## immediate subdirectories (prefixed with {{ExperimentDirectory}})
setenv obsWorkDir Observations

setenv dataAssimWorkDir $DataAssim

setenv forecastWorkDir $Forecast

setenv cyclingInflationWorkDir CyclingInflation
setenv rTPPWorkDir ${cyclingInflationWorkDir}/RTPP
setenv aBEInflationWorkDir ${cyclingInflationWorkDir}/ABEI

setenv extendedFCWorkDir ExtendedFC
setenv verificationWorkDir $Verification

setenv externalAnalysisWorkDir ExternalAnalyses

## sub-subdirectories
# InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

# verification and comparison
set ObsDiagnosticsDir = diagnostic_stats/obs
set ModelDiagnosticsDir = diagnostic_stats/model
set ObsCompareDir = Compare2Benchmark/obs
set ModelCompareDir = Compare2Benchmark/model


#####################################
## file names, prefixes, and suffixes
#####################################
## model-space
setenv RSTFilePrefix restart
setenv ICFilePrefix mpasin

setenv FCFilePrefix mpasout
setenv fcDir fc
setenv DIAGFilePrefix diag

setenv ANFilePrefix an
setenv anDir $ANFilePrefix
setenv BGFilePrefix bg
setenv bgDir $BGFilePrefix

setenv OrigFileSuffix _orig

## observation-space
# for obs, geovals, and hofx-diagnostics
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags

## VarBCAnalysis is the analysis variational bias correction coefficient file
# TODO: enable VarBC updating
# -----
setenv VarBCAnalysis ${OutDBDir}/satbias_crtm_ana


#########################
# member-related settings
#########################
# TODO: move these to a cross-application config/yaml combo


setenv flowMemPrefix "mem"
setenv flowMemNDigits 3
setenv flowMemFmt "/${flowMemPrefix}{:0${flowMemNDigits}d}"
setenv flowInstanceFmt "/instance{:0${flowMemNDigits}d}"
setenv flowMemFileFmt "_{:0${flowMemNDigits}d}"
