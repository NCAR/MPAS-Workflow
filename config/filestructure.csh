#!/bin/csh -f

if ( $?config_filestructure ) exit 0
set config_filestructure = 1

source config/experiment.csh
source config/benchmark.csh

## controls the workflow file structure of all experiments

# While any variable may be changed, doing so may prevent restart or re-verification of previously
# executed experiments

# TODO: move TMPDIR creation to individul jobs or common cylc environment setup script, similar
# to how PrepJEDI.csh is used
setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

##########################
## run directory structure
##########################
setenv PackageBaseName MPAS-Workflow

## absolute experiment directory
setenv ExperimentDirectory ${ParentDirectory}/${ExperimentName}

## immediate subdirectories
setenv ObsWorkDir ${ExperimentDirectory}/Observations
setenv CyclingDAWorkDir ${ExperimentDirectory}/CyclingDA
setenv CyclingFCWorkDir ${ExperimentDirectory}/CyclingFC
setenv CyclingInflationWorkDir ${ExperimentDirectory}/CyclingInflation
setenv RTPPWorkDir ${CyclingInflationWorkDir}/RTPP
setenv ABEInflationWorkDir ${CyclingInflationWorkDir}/ABEI

setenv ExtendedFCWorkDir ${ExperimentDirectory}/ExtendedFC
setenv VerificationWorkDir ${ExperimentDirectory}/Verification

## benchmark experiment archive
setenv BenchmarkCyclingDAWorkDir ${BenchmarkExperimentDirectory}/CyclingDA
setenv BenchmarkVerificationWorkDir ${BenchmarkExperimentDirectory}/Verification

## directories copied from PackageBaseName
setenv mainScriptDir ${ExperimentDirectory}/${PackageBaseName}
setenv ConfigDir ${mainScriptDir}/config

## directory string formatter for EDA members
# third argument to memberDir.py
setenv flowMemPrefix "mem"
setenv flowMemNDigits 3
setenv flowMemFmt "/${flowMemPrefix}{:0${flowMemNDigits}d}"
setenv flowInstFmt "/instance{:0${flowMemNDigits}d}"
setenv flowMemFileFmt "_{:0${flowMemNDigits}d}"

## appyaml: universal yaml file name for all jedi applications
setenv appyaml jedi.yaml


#############################################
## model state file and directory descriptors
#############################################
setenv RSTFilePrefix restart
setenv ICFilePrefix mpasin

setenv FCFilePrefix mpasout
setenv fcDir fc
setenv DIAGFilePrefix diag

setenv ANFilePrefix an
setenv anDir ${ANFilePrefix}
setenv BGFilePrefix bg
setenv bgDir ${BGFilePrefix}

setenv OrigFileSuffix _orig


############################################
## instrument file and directory descriptors
############################################
## database file prefixes
#  for obs, geovals, and hofx-diagnostics
# Note: these are self-consistent across multiple applications
#       and can be changed to any non-empty string
setenv obsPrefix      obsout
setenv geoPrefix      geoval
setenv diagPrefix     ydiags

## InDBDir and OutDBDir control the names of the database directories
# on input and output from jedi applications
setenv InDBDir  dbIn
setenv OutDBDir dbOut

## VarBCAnalysis is the analysis variational bias correction coefficient file
# TODO: enable VarBC updating
# -----
setenv VarBCAnalysis ${OutDBDir}/satbias_crtm_ana
