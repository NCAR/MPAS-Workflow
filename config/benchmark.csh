#!/bin/csh -f

if ( $?config_benchmark ) exit 0
setenv config_benchmark 1

source config/scenario.csh benchmark setNestedBenchmark

# BenchmarkExperimentDirectory
setenv benchmark__ExperimentDirectory "`$getLocalOrNone ExperimentDirectory`"
