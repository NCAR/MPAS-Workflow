#!/bin/csh -f

if ( $?config_job ) exit 0
setenv config_job 1

source config/scenario.csh

# getJob and setJob are helper functions that pick out individual
# configuration elements from within the "job" key of the scenario configuration
setenv getJob "$getConfig $baseConfig $scenarioConfig job"
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
