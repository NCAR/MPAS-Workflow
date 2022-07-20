#!/bin/csh -f

if ( $?config_job ) exit 0
setenv config_job 1

source config/scenario.csh job

$setLocal CPAccountNumber
$setLocal CPQueueName
$setLocal NCPAccountNumber
$setLocal NCPQueueName
$setLocal SingleProcAccountNumber
$setLocal SingleProcQueueName
$setLocal EnsMeanBGQueueName
$setLocal EnsMeanBGAccountNumber


##################################
# auto-generate cylc include files
##################################

if ( ! -e include/variables/auto/job.rc ) then
cat >! include/variables/auto/job.rc << EOF
{% set CPQueueName = "${CPQueueName}" %}
{% set CPAccountNumber = "${CPAccountNumber}" %}
{% set NCPQueueName = "${NCPQueueName}" %}
{% set NCPAccountNumber = "${NCPAccountNumber}" %}
{% set SingleProcQueueName = "${SingleProcQueueName}" %}
{% set SingleProcAccountNumber = "${SingleProcAccountNumber}" %}
{% set EnsMeanBGQueueName = "${EnsMeanBGQueueName}" %}
{% set EnsMeanBGAccountNumber = "${EnsMeanBGAccountNumber}" %}
EOF

endif
