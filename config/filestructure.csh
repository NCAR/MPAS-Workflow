#!/bin/csh -f

source config/experiment.csh
source config/mpas/${MPASGridDescriptor}-mesh.csh

## controls the workflow file structure of all experiments

# While any variable may be changed, doing so may prevent restart or re-verification of previously
# executed experiments

# TODO: move TMPDIR creation to individul jobs or common cylc environment setup script, similar
# to how jediPrep.csh is used
setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

##########################
## run directory structure
##########################
## absolute experiment directory
setenv PackageBaseName MPAS-Workflow
set ExperimentUser = ${USER}
set TopExpDir = /glade/scratch/${ExperimentUser}/pandac
setenv ExperimentName ${ExperimentUser}
setenv ExperimentName ${ExperimentName}_${DAType}
setenv ExperimentName ${ExperimentName}${ExpObsName}
setenv ExperimentName ${ExperimentName}${EnsExpSuffix}
setenv ExperimentName ${ExperimentName}_${MPASGridDescriptor}
setenv ExperimentName ${ExperimentName}${ExpSuffix}

set ExpDir = ${TopExpDir}/${ExperimentName}

## immediate subdirectories
setenv CyclingDAWorkDir ${ExpDir}/CyclingDA
setenv CyclingFCWorkDir ${ExpDir}/CyclingFC
setenv CyclingInflationWorkDir ${ExpDir}/CyclingInflation
setenv RTPPInflationWorkDir ${CyclingInflationWorkDir}/RTPP
setenv ABEInflationWorkDir ${CyclingInflationWorkDir}/ABEI

setenv ExtendedFCWorkDir ${ExpDir}/ExtendedFC
setenv VerificationWorkDir ${ExpDir}/Verification

## directories copied from PackageBaseName
setenv mainScriptDir ${ExpDir}/${PackageBaseName}
setenv ConfigDir ${mainScriptDir}/config
set ModelConfigDir = ${ConfigDir}/mpas
setenv forecastModelConfigDir ${ModelConfigDir}/forecast
setenv hofxModelConfigDir ${ModelConfigDir}/hofx
if ($nEnsDAMembers > 1 && ${ABEInflation} == True) then
  setenv variationalModelConfigDir ${ModelConfigDir}/variational-bginflate
else
  setenv variationalModelConfigDir ${ModelConfigDir}/variational
endif
setenv rtppModelConfigDir ${ModelConfigDir}/rtpp

## directory string formatter for EDA members
# third argument to memberDir.py
setenv flowMemFmt "/mem{:03d}"

## appyaml: universal yaml file name for all jedi applications
setenv appyaml jedi.yaml


#############################################
## model state file and directory descriptors
#############################################
setenv RSTFilePrefix restart
setenv ICFilePrefix mpasin
setenv InitFilePrefixOuter x1.${MPASnCellsOuter}.init
setenv InitFilePrefixInner x1.${MPASnCellsInner}.init
setenv InitFilePrefixEnsemble x1.${MPASnCellsEnsemble}.init

setenv FCFilePrefix mpasout
setenv fcDir fc
setenv DIAGFilePrefix diag

setenv ANFilePrefix an
setenv anDir ${ANFilePrefix}
setenv BGFilePrefix bg
setenv bgDir ${BGFilePrefix}

setenv TemplateFilePrefix templateFields
setenv localStaticFieldsFileOuter static-${MPASnCellsOuter}.nc
setenv localStaticFieldsFileInner static-${MPASnCellsInner}.nc
setenv localStaticFieldsFileEnsemble static-${MPASnCellsEnsemble}.nc

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
