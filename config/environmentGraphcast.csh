#!/bin/csh -f

if ( $?config_environmentGraphcast ) exit 0
setenv config_environmentGraphcast 1

module --force purge
module load ncarenv/25.10
module load uv
set uvProject = "/glade/derecho/scratch/stoedtli/earth2studio-mpas-3.13/"
