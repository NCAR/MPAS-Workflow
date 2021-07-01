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

if [ $case -eq 1 ]; then
# case-1
# checkout mpasbunle, ecbuild --> CMakelists.txt
  echo "git + ecbuild (cmake)"
  if [ $run -eq 0 ]; then
    echo "head -n 40 bundle_p1.sh"  
    head -n 40 bundle_p1.sh
    echo
    echo "dry: ./bundle_p1.sh br_$name_jedi_dir &>  log.b"
    echo 
  elif [ $run -eq 1 ]; then
    ./bundle_p1.sh  br_$name_jedi_dir &>  log.b
  fi
elif [ $case -eq 2 ]; then
# case-1
# make -j 8;  schedule cron job for it
  echo "make; ctest"
  if [ $run -eq 0 ]; then
    echo "head -n 60 bundle_p2.sh"  
    head -n 60 bundle_p2.sh
    echo
    echo "dry: qsub job_make_ctest.scr"
    echo 
  elif [ $run -eq 1 ]; then
    qsub job_make_ctest.scr
  fi
elif [ $case -eq 3 ]; then
# case-3
# run FC+DA cycle; gen_autotest scr 
  echo "run DA"
  if [ $run -eq 0 ]; then
    echo "head -n 80 gen_autotest.sh"
    head -n 80 gen_autotest.sh
    echo
    echo "dry: ./gen_autotest.sh br_$name_jedi_dir &>  log.t"
    echo 
  elif [ $run -eq 1 ]; then
    ./gen_autotest.sh  br_$name_jedi_dir &>  log.t
  fi
fi
