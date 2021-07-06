#!/bin/bash
# use: sh rsync.sh  dir         0:1
#                   $1          $2                            
#                   dir_rsync   0=dry run, 1=run
#
if [ $# -eq 2 ]; then
 dir=$1
 ix=$2      # if_execute
else
 echo "wrong input; $1=dir; $2=0:1 dry/real"
fi

c1="rsync -e \"ssh -vi /glade/u/home/${USER}/.ssh/koa-sync\" -nazv --exclude 'FC1DIAG' --exclude 'Verification'  ./\$dir/*  ${USER}@koa.mmm.ucar.edu:/exports/htdocs2/projects/DA_images/."
c2="rsync -e \"ssh -vi /glade/u/home/${USER}/.ssh/koa-sync\"  -azv --exclude 'FC1DIAG' --exclude 'Verification'  ./\$dir/*  ${USER}@koa.mmm.ucar.edu:/exports/htdocs2/projects/DA_images/."

if [ $ix -eq 0 ]; then
 echo $c1
 eval $c1
elif [ $ix -eq 1 ]; then
 echo $c2
 eval $c2
else
 echo "ix (if_execute) = $ix ; "
fi
