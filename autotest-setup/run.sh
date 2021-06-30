#!/bin/bash
#
# usage:   sh run.sh  1/2/3/-1  0/1 
#                      case     dry-run / real
#

[[ $# -ne 2 ]] && echo "\$# -ne 2, stop" && exit -1

## name_jedi_dir="mpasbundletest"
name_jedi_dir=`pwd | awk -F/ '{print $(NF-1)}'`
sd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # script dir
echo "name_jedi_dir = $name_jedi_dir" 
echo "sd = $sd"

case=$1
run=$2
module add ncarenv
echo "case=$1 ; run=$2"

if [ $case -eq 1 ] && [ $run -ge 0 ]; then
# case-1
# checkout mpasbunle, ecbuild --> CMakelists.txt
  echo "cmake"
  echo "dry: ./bundle_p1.sh br_$name_jedi_dir &>  log.b"
  if [ $run -eq 1 ]; then
    ./bundle_p1.sh  br_$name_jedi_dir &>  log.b
  fi
elif [ $case -eq 2 ] && [ $run -ge 0 ]; then
# case-1
# make -j 8;  schedule cron job for it
  echo "make; ctest"
  echo "dry: qsub job_make_ctest.scr"
  if [ $run -eq 1 ]; then
    qsub job_make_ctest.scr
  fi
elif [ $case -eq 3 ] && [ $run -ge 0 ]; then
# case-3
# run FC+DA cycle; gen_autotest scr 
  echo "run DA"
  echo "dry: ./gen_autotest.sh br_$name_jedi_dir &>  log.t"
  if [ $run -eq 1 ]; then
    ./gen_autotest.sh  br_$name_jedi_dir &>  log.t
  fi
fi

exit -1
 

# hr=$(date --date='$ds' '+%Y-%m-%d_%H.%M.%S')
 echo "$minhr  
# /opt/pbs/bin/qsub   $sd/job_make_ctest.scr" > F1

#   date '+%Y-%m-%d_%H.%M.%S' &&  date --date='10 second' '+%M %H %S'
ds="10 second"    # delta second
echo "ds = $ds"
minhr=`date --date='65 second' '+%M %H'`     # increase minhr by 61 s
echo $minhr
echo "$minhr * * 1,2,3,4,5,6,7 /opt/pbs/bin/qsub $sd/job_make_ctest.scr" > F2
##crontab $sd/F2

