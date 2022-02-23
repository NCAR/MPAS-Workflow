#!/bin/csh -f

source config/experiment.csh

#
# static job submission settings
# =============================================

## *AccountNumber
# OPTIONS: NMMM0015, NMMM0043
setenv CheyenneAccountNumber NMMM0043
setenv CasperAccountNumber NMMM0015
#Note: NMMM0043 is not available on casper

## *QueueName
# Cheyenne Options: economy, regular, premium
# Casper Options: casper@casper-pbs

# CP*: used for all critical path jobs, single or multi-node, multi-processor only
setenv CPAccountNumber ${CheyenneAccountNumber}
setenv CPQueueName regular

# NCP*: used non-critical path jobs, single or multi-node, multi-processor only
setenv NCPAccountNumber ${CheyenneAccountNumber}
setenv NCPQueueName economy

# SingleProc*: used for single-processor jobs, both critical and non-critical paths
# IMPORTANT: must NOT be executed on login node to comply with CISL requirements
#setenv SingleProcAccountNumber ${CheyenneAccountNumber}
#setenv SingleProcQueueName share
setenv SingleProcAccountNumber ${CasperAccountNumber}
setenv SingleProcQueueName "casper@casper-pbs"


if ($ABEInflation == True) then
  setenv EnsMeanBGQueueName ${CPQueueName}
  setenv EnsMeanBGAccountNumber ${CPAccountNumber}
else
  setenv EnsMeanBGQueueName ${NCPQueueName}
  setenv EnsMeanBGAccountNumber ${NCPAccountNumber}
endif

setenv InitializationRetry '2*PT30S'
setenv GetNCEPftpRetry '40*PT30M'
setenv GetGFSanalysisRetry '40*PT10M'
setenv VariationalRetry '2*PT30S'
setenv EnsOfVariationalRetry '1*PT30S'
setenv CyclingFCRetry '2*PT30S'
setenv RTPPInflationRetry '2*PT30S'
setenv HofXRetry '2*PT30S'
#setenv VerifyObsRetry '1*PT30S'
#setenv VerifyModelRetry '1*PT30S'
