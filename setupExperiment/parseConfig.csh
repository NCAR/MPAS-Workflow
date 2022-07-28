#!/bin/csh -f

setenv TMPDIR /glade/scratch/${USER}/temp
mkdir -p $TMPDIR

source config/auto/scenario.csh experiment

# ParentDirectory parts
$setLocal ParentDirectoryPrefix
$setLocal ParentDirectorySuffix

# ExperimentUserDir
setenv ExperimentUserDir "`$getLocalOrNone ExperimentUserDir`"
if ("$ExperimentUserDir" == None) then
  setenv ExperimentUserDir ${USER}
endif

# ExperimentUserPrefix
setenv ExperimentUserPrefix "`$getLocalOrNone ExperimentUserPrefix`"
if ("$ExperimentUserPrefix" == None) then
  setenv ExperimentUserPrefix ${USER}_
endif

# ExperimentName
setenv ExperimentName "`$getLocalOrNone ExperimentName`"

# ExpSuffix
$setLocal ExpSuffix

## ParentDirectory
# where this experiment is located
setenv ParentDirectory ${ParentDirectoryPrefix}/${ExperimentUserDir}/${ParentDirectorySuffix}
