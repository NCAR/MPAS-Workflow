#!/bin/csh -f

if ( $?config_job ) exit 0
setenv config_job 1

source config/scenario.csh

# setJob is a helper function that picks out a configuration node
# under the "job" key of scenarioConfig
setenv setJob "source $setConfig $baseConfig $scenarioConfig job"

$setJob CPAccountNumber
$setJob CPQueueName
$setJob NCPAccountNumber
$setJob NCPQueueName
$setJob SingleProcAccountNumber
$setJob SingleProcQueueName
$setJob EnsMeanBGQueueName
$setJob EnsMeanBGAccountNumber

$setJob InitializationRetry
$setJob VariationalRetry
$setJob EnsOfVariationalRetry
$setJob CyclingFCRetry
$setJob RTPPInflationRetry
$setJob HofXRetry
#$setJob VerifyObsRetry
#$setJob VerifyModelRetry
