#!/bin/csh -f

if ( $?config_benchmark ) exit 0
setenv config_benchmark 1

source config/auto/scenario.csh benchmark

# BenchmarkExperimentDirectory
setenv benchmark__ExperimentDirectory "`$getLocalOrNone ExperimentDirectory`"
