#!/bin/bash -l

# script to run a cylc scenario or post process the scenario's data after it completes.
#   If a scenario doesn't need post processing (it hasn't been run, or it is still running,
#   or its data has already been processed) the script will do nothing.
# This script must be run on derecho or casper (not the cron server).
#
# Jobs which have been started are placed in a "running" directory.
# Jobs which have succeeded are placed in a "succeeded" directory.
# Jobs which have failed are placed in a "failed" directory.
# Jobs which have had graphs created for them are placed in a "processed" directory.
#
# When the script runs a cylc job it will put the name of the workflow into a "running" file.
# A subsequent call to create graphs from the workflow will check the jobs in the "running" files.
# The "running" jobs are checked to see if they are still running, have failed, or succeeded,
# jobs which have finished are moved to either the "succeeded" directory of the "failed" directory.
# See check_cylc for that logic.
#
# To generate graphs, the jobs in the "succeeded" and "processed" directories are examined to see if the same workflow
# has run at least twice.
# If so, the most recent two runs are graphed; the older run is the baseline.
# After jobs have been graphed they are moved to the "processed" directory.
# See make_graphs for details.

readonly CRON_SUFFIX="_cron"  # append to workflow name to ID workflows run by this script
readonly PASS_DIR="passed_workflows" # directory with workflows which passed
readonly FAIL_DIR="failed_workflows" # directory with workflows which failed
readonly RUN_DIR="running_workflows" # directory with workflows which are running
readonly GRAPHED_DIR="processed_workflows" # directory with workflows that have been graphed.
LOGDIR="${HOME}/my_cron_logs/cylc" # default base dir for PASS_DIR, FAIL_DIR, RUN_DIR, can be overwritten w/ -l

# create the logging file (including its directory) and
# create the directories to hold cylc processing files.
init_logs()
{
  local cron_logdir="$1"
  local suffix="$2"
  local date="$(date +%F-%H)"

  mkdir -p ${cron_logdir} || exit 1
  mkdir -p "${cron_logdir}/logs" || exit 1
  LOGFILE="${cron_logdir}/logs/run_cylc.${suffix}.${date}.log"
}

usage()
{
  echo""
  log "usage:"
  log "to run a cylc workflow"
  log "  run_cylc.sh -w <workflow_dir> [-d <bundle_dir> [-k <lock_file>]] -s <scenario> -x <suffix> [-l log_dir] [-h] "
  log "    -w <workflow_dir> the MPAS-Workflow location"
  log "    -d <bundle_dir> where the mpas-bundle repo has been built"
  log "        this will override the bundle set in the workflow's Build.py"
  log "    -k <lock_file> the name of the lock file which exists while mpas-bundle is being built"
  log "        if the mpas-bundle lock file exists, that will be logged and the workflow will not run"
  log "    -s <scenario> a scenario to run (relative to workflow_dir)"
  log "    -x <suffix> the suffix to append to the names of the workflows to run"
  log "    -l <log_dir> where logs and data should be written, default $LOGDIR"
  log "    -h prints help and exits"
  log "to generate graphs"
  log "  run_cylc.sh -w <workflow_dir> -g <graphics_dir> -o <output_dir> [-l log_dir] [-h] "
  log "    -w <workflow_dir> the MPAS-Workflow location"
  log "    -g <graphics_dir> where the mpas-jedi graphics directory is"
  log "    -o <output_dir> where the comparison graphs should go"
  log "    -l <log_dir> where logs and data should be written, default $LOGDIR"
  log "    -h prints help and exits"
  exit 1
}

log()
{
  echo -e "$1" | tee -a ${LOGFILE}
}

# check if the provided file/directory exists.
# exit with usage message if file/dir doesn't exist.
check_exists()
{
  local name=$1 # file/directory to check for existence
  local msg=$2  # message to log if file/dir doesn't exist
  local type=$3 # type of object to check for (file or directory)

  if [ "$name" = "" ]; then
    log "$msg is required"
    usage
  fi
  if [ "$type" == "dir" ]; then
    if [ ! -d "${name}" ]; then
      log "$msg ${name} is not a directory"
      usage
    fi
  else
    if [ ! -f "${name}" ]; then
      log "$msg ${name} is not a file"
      usage
    fi
  fi
}

# run a cylc workflow.
# creates a file with the name of the running scenario.
run_cylc()
{
  log 'run_cylc'
  local work_dir=$1 # location of the MPAS-Workflow cloned repo
  local scenario=$2 # the workflow to run
  local suffix=".$3${CRON_SUFFIX}"   # a string to append to the workflow names to uniquely identify them
  local base_dir=$4 # base file directory
  local bundle_dir=$5 # location of a mpas-bundle build (should be single precision)
  local running_dir="$base_dir/$RUN_DIR"
  local date="$(date +%F-%H-%M)"
  

  cd $work_dir
  if [ "$bundle_dir" != "" ]; then
    log "./Run.py $scenario -b $bundle_dir  -x $suffix"
    $work_dir/Run.py $scenario -b $bundle_dir  -x $suffix  2>&1 | tee -a ${LOGFILE}
  else
    log "./Run.py $scenario -x $suffix"
    $work_dir/Run.py $scenario -x $suffix  2>&1 | tee -a ${LOGFILE}
  fi

  # save the names of the running workflows to check for success later
  mkdir -p $running_dir || (log "failed to create $running_dir" && exit 1)
  workflow_name=$(cylc scan -t name | grep  "${suffix}$" )
  workflow_file_name=$(echo $workflow_name | awk -F/ '{print $NF}')
  log "workflow_name=$workflow_name"
  log "echo $workflow_name > $running_dir/$workflow_file_name"
  echo $workflow_name > $running_dir/$workflow_file_name
}

# check to see if any cylc jobs started with this script have completed successfully.
# if a job which had been started by this script finished OK return 0.
# if no cylc job had been started but not post processed return -1.
# else return a code from the last job to be looked at, see check_cylc_job for specific codes.
check_cylc()
{
  local files_dir=$1
  local run_dir=$files_dir/$RUN_DIR
  local retcode=0

  if [ ! -d "${run_dir}" ]; then
    log "no $run_dir directory, nothing running"
    return -1
  fi

  running_jobs=$(ls $run_dir)
  if [ "$running_jobs" == "" ]; then
    log "no files in $run_dir, nothing running"
    return -1
  fi

  # check all the workflows which were started
  log "running_jobs=$running_jobs"
  for job in $running_jobs ; do
    job_name=$(cat $run_dir/$job)
    check_cylc_job $job_name $run_dir/$job $files_dir
    retcode=$?
    if [ $retcode -eq 0 ]; then
      echo "$job_name completed successfully"
      eval "$2=$job"
      return 0
    fi
  done

  return $retcode # status of the last processed job
}

# check to see if a cylc job started with this script has been started and not post processed.
# if a cylc job has been started check to see if it has finished.
#   if it hasn't finished return -2
# if a cylc job has finished, check for errors.
#   if there were errors move the running file to "failed" directory and return -3
#   if there were no errors move the running file to "passed" directory and return 0
check_cylc_job()
{
  local job_name=$1
  local job_file=$2 # file with the name of the running job (including absolute path)
  local files_dir=$3  # base directory for the running/passed/failed jobs directories
  local pass_dir=$files_dir/$PASS_DIR
  local fail_dir=$files_dir/$FAIL_DIR
  local retcode=0

  # see if workflow which was started is still running
  log "cylc ping ${job_name}"
  cylc ping ${job_name} > /dev/null
  retcode=$?
  if [ $retcode -eq 0 ]; then
    log "$job_name is running"
    return -2
  fi

  # check to see if the job name is valid, a zero return code indicates the job name is valid
  cylc workflow-state $job_name > /dev/null
  if [[ $? -ne 0 ]]; then
    log "$job_name cannot be found"
    # FIXME remove the file, since we cannot tell if the job ever ran
    mkdir -p $fail_dir || (log "failed to create $fail_dir" && exit 1)
    mv $job_file $fail_dir
    # if we got here the cycl workflow is unknown/deleted,
    return -3
  fi

  # check the states of the finished tasks
  # since the workflow is not running, if any step did not succeed the workflow failed.
  local failed="${job_file}.failed"
  cylc workflow-state $job_name | grep -v succeeded > $failed
  retcode=$?
  # FIXME put the failures from the failed file on the results website
  if [ $retcode -eq 0 ]; then
    log "$job_name failed"
    mkdir -p $fail_dir || (log "failed to create $fail_dir" && exit 1)
    mv $job_file $fail_dir
    mv $failed $fail_dir
    # if we got here a cycl workflow has finished with failures
    return -3
  fi

  # if we got here a cycl workflow has finished without failures,
  log "$job_name completed successfully"
  mkdir -p $pass_dir || (log "failed to create $pass_dir" && exit 1)
  log "mv $job_file $pass_dir"
  mv $job_file $pass_dir
  rm -f $failed
  return 0
}

# create comparison graphs between this cylc experiment and the previous run
make_graphs()
{
  local graphics_dir=$1 # where the mpas-bundle graphing code is
  local output_dir=$2   # where to put the graphs
  local files_dir=$3
  local success_file=$4 # the workflow to process. assume a name of <workflow>.<date>_cron

  local success_job=${success_file%.*}
  local pass_dir=$files_dir/$PASS_DIR  # where the passed workflow names are
  local graph_dir=$files_dir/$GRAPHED_DIR # where the graphed workflows are
  local date="$(date +%F)"
  local queue="develop"
  local account="nmmm0043"
  echo "success_job: $success_job"

  # find the two most recent passed workflows
  local passed_files=$(ls -r ${pass_dir}/${success_job}*)
  passed_files_array=($passed_files)
  local npassed_files=${#passed_files_array[@]} 
  log "passed nfiles: ${npassed_files}"
  if [ "${npassed_files}" -eq 0 ]; then
    log "there aren't any new jobs to graph"
    return
  fi

  # find the most recent graphed workflow
  local graphed_files=$(ls -r ${graph_dir}/${success_job}*)
  graphed_files_array=($graphed_files)
  log "graphed nfiles: ${#graphed_files_array[@]}"

  if [ "${npassed_files}" -lt 2 ] && [ "${#graphed_files_array[@]}" -eq 0 ]; then
    log "there aren't two successful cylc runs to compare"
    return
  fi

  # the contents of the workflow files are the names of the workflows
  # compare the newest run against the previous run
  local new_run=$(cat ${passed_files_array[0]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  if [ "${#passed_files_array[@]}" -gt 1 ]; then
    local base_run=$(cat ${passed_files_array[1]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  else
    local base_run=$(cat ${graphed_files_array[1]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  fi
  log "newest run: $new_run"
  log "previous run: $base_run"
  local exp_names="previous:$base_run,current:$new_run"

  # make forecast comparison graphs
  local target_dir=$output_dir/$date/model
  mkdir -p $target_dir || (log "failed to create $target_dir" && exit 1)
  cd $target_dir
  log "making graphs in $target_dir"
  local an_stats_args=" -s $graphics_dir -q $queue -a $account -n 1 -c previous -e $exp_names -d mpas -p model -t forecast"
  log "$graphics_dir/SpawnAnalyzeStats.py -s $an_stats_args"
  #$graphics_dir/SpawnAnalyzeStats.py $an_stats_args

  # make omb/oma comparison graphs
  local target_dir=$output_dir/$date/obs
  mkdir -p $target_dir || (log "failed to create $target_dir" && exit 1)
  cd $target_dir
  log "making graphs in $target_dir"
  local an_stats_args=" -s $graphics_dir -q $queue -a $account -n 1 -c previous -e $exp_names -d amsua_,sonde,airc,sfc,gnssrobndropp1d,satwind,mhs_as  -p obs -t omb/oma"
  log "$graphics_dir/SpawnAnalyzeStats.py $an_stats_args"
  #$graphics_dir/SpawnAnalyzeStats.py $an_stats_args

  # make sure the graphed files get moved to the "graphed" directory
  mkdir -p $graph_dir || (log "failed to create $graph_dir" && exit 1)
  log "mv ${passed_files_array[0]} $graph_dir"
  mv ${passed_files_array[0]} $graph_dir
  if [ "${#passed_files_array[@]}" -gt 1 ]; then
    log "mv ${passed_files_array[1]} $graph_dir"
    mv ${passed_files_array[1]} $graph_dir
  fi
}

main()
{
  local workflow_dir=""
  local bundle_dir=""
  local build_lock_file=""
  local graphics_dir=""
  local output_dir=""
  local scenario=""
  local suffix=""
  local help=""
  local CYLC_ENV_SCRIPT="env-setup/machine.sh"

# get comamnd line args
  while getopts w:d:k:g:o:s:x:l:h flag
  do
    case "${flag}" in
      w) workflow_dir="${OPTARG}";;
      d) bundle_dir="${OPTARG}";;
      k) build_lock_file="${OPTARG}";;
      g) graphics_dir="${OPTARG}";;
      o) output_dir="${OPTARG}";;
      s) scenario="${OPTARG}";;
      x) suffix="${OPTARG}";;
      l) LOGDIR=${OPTARG};;
      h) help="help";;
    esac
  done

  init_logs $LOGDIR "cron"
  log "commandline: $0 $*"

  if [ "$help" != "" ]; then
    usage
  fi

  if [ "$suffix" == "" ] && [ "$graphics_dir" == "" ]; then
    log "suffix (-x <suffix>) is required."
    usage
  fi
  # FIXME is this needed?
  #suffix=${suffix}

  check_exists "$workflow_dir" "workflow dir" "dir"
  # make sure Run.py is in the workflow directory
  check_exists "$workflow_dir/Run.py" "file"
  check_exists "$workflow_dir/$CYLC_ENV_SCRIPT" "file"

  cd $workflow_dir
  log "source $CYLC_ENV_SCRIPT"
  source $CYLC_ENV_SCRIPT &> /dev/null

  if [ "$graphics_dir" == "" ]; then
    if [ "$bundle_dir" != "" ]; then
      check_exists "$bundle_dir" "bundle dir" "dir"
    fi
    check_exists "$workflow_dir/$scenario" "scenario" "file"

    # see if the mpas-bundle build lockfile exists, if so mpas-bundle is still compiling
    if [ "$build_lock_file" != "" ]; then
      if [ -e "$build_lock_file" ]; then
        log "the mpas-bundle build is in progress, $build_lock_file exists"
        exit 1
      fi
    fi

    run_cylc $workflow_dir $scenario $suffix $LOGDIR $bundle_dir 
  else
    local success_file=""

    check_exists "$output_dir" "output dir" "dir"
    check_exists "$graphics_dir" "bundle dir" "dir"
    check_exists "$graphics_dir/SpawnAnalyzeStats.py" "SpawnAnalyzeStats.py" "file"

    # see if a cron cylc workflow needs post processing, success_file is returned if one does
    check_cylc $LOGDIR success_file
    if [ "$?" -ne 0 ]; then
      log "there were no running jobs"
      #return 0
    fi

    # set up python environment for the graphics tools
    module reset 2> /dev/null
    module load conda/latest
    conda activate npl-2023a

    # make a graph comparing the 2 most recent workflows which passed
    echo "make_graphs $graphics_dir $output_dir $LOGDIR $success_file"
    make_graphs $graphics_dir $output_dir $LOGDIR $success_file
  fi
}

main "$@"

