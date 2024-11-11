#!/bin/bash -l

# script to run a cylc scenario or post process the scenario's data after it completes.
#   If no scenarios need post processing (haven't finished successfully
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
# See check_running_jobs for that logic.
#
# To generate graphs, the jobs in the "succeeded" and "processed" directories are examined to see
# if the same workflow has run at least twice and at least one run hasn't been graphed.
# If so, comparison graphs are made for each pair of successive runs; the older run is the baseline.
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
# completed jobs will be moved to the "success" or "failed" directories.
check_running_jobs()
{
  local files_dir=$1
  local run_dir=$files_dir/$RUN_DIR
  local retcode=0

  if [ ! -d "${run_dir}" ]; then
    log "no $run_dir directory, nothing running"
    return
  fi

  running_jobs=$(ls $run_dir)
  if [ "$running_jobs" == "" ]; then
    log "no files in $run_dir, nothing running"
    return
  fi

  # check all the workflows which were started
  log "running_jobs=$running_jobs"
  for job in $running_jobs ; do
    job_name=$(cat $run_dir/$job)
    check_cylc_job $job_name $run_dir/$job $files_dir
    retcode=$?
    if [ $retcode -eq 0 ]; then
      echo "$job_name completed successfully"
    fi
  done
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

# create comparison graphs between the provided cylc experiment and the previous run
make_graphs()
{
  local readonly graphics_dir=$1 # where the mpas-bundle graphing code is
  local readonly output_dir=$2   # where to put the graphs
  local readonly files_dir=$3  # root directory where job files are
  local readonly success_file=$4 # the workflow file to process.

  # assume a name of <workflow>.<yy-mm-dd>*, use the <workflow> part to find all runs of the same workflow.
  local readonly file_base=${success_file%.*}
  local readonly file_suffix=${success_file#*.} # used to create run specific graph directories
  local readonly pass_dir=$files_dir/$PASS_DIR  # where the passed workflows are
  local readonly graph_dir=$files_dir/$GRAPHED_DIR # where the graphed workflows are
  local readonly date="$(date +%F)"
  local readonly model_graph_dir=$output_dir/$date/$file_suffix/model
  local readonly obs_graph_dir=$output_dir/$date/$file_suffix/obs
  local base_run="" # the job to be used as the baseline for the graph
  local new_run="" # the job to be compared against the base
  # PBS directives
  local readonly queue="-q develop"
  local readonly account="-a nmmm0043"
  local readonly memory="-m 12"
  # SpawnAnalyzeStats arguments
  local readonly an_model_spaces=" -d mpas -p model -t forecast"
  local readonly an_obs_spaces=" -d amsua_,sonde,airc,sfc,gnssrobndropp1d,satwind,mhs_as  -p obs -t omb/oma"

  if [ "$success_file" == "" ]; then
    log "no job file passed to make_graphs(), no graphs made"
    return
  fi

  # find the passed workflows, oldest first
  local readonly passed_files=($(ls ${pass_dir}/${file_base}*))
  local readonly npassed_files=${#passed_files[@]} 

  # find the most recent graphed workflow
  local readonly graphed_files=($(ls -r ${graph_dir}/${file_base}*))
  local readonly ngraphed_files=${#graphed_files[@]}
  log "passed nfiles: ${npassed_files} graphed nfiles: $ngraphed_files"

  if [ "${npassed_files}" -eq 0 ]; then
    log "there aren't any new jobs to graph"
    return
  fi
  if [ "${npassed_files}" -lt 2 ] && [ "${ngraphed_files}" -eq 0 ]; then
    log "there aren't two successful cylc runs to compare"
    return
  fi

  if [ "${#graphed_files[@]}" -gt 0 ]; then
    base_run=$(cat ${graphed_files[0]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
    new_run=$(cat ${passed_files[0]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  else
    base_run=$(cat ${passed_files[0]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
    new_run=$(cat ${passed_files[1]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  fi

  log "newest run: $new_run"
  log "previous run: $base_run"
  local readonly exp_names="previous:$base_run,current:$new_run"
  local readonly an_base_args=" -s $graphics_dir $queue $account -n 1 $memory -c previous -e $exp_names "
  log "an_base_args=$an_base_args"
  local readonly an_model_args=" $an_base_args $an_model_spaces"
  local readonly an_obs_args=" $an_base_args $an_obs_spaces"

  # make forecast comparison graphs
  mkdir -p $model_graph_dir || (log "failed to create $model_graph_dir" && exit 1)
  cd $model_graph_dir
  log "making graphs in $model_graph_dir"
  log "$graphics_dir/SpawnAnalyzeStats.py $an_model_args"
  $graphics_dir/SpawnAnalyzeStats.py $an_model_args

  # make omb/oma comparison graphs
  mkdir -p $obs_graph_dir || (log "failed to create $obs_graph_dir" && exit 1)
  cd $obs_graph_dir
  log "making graphs in $obs_graph_dir"
  log "$graphics_dir/SpawnAnalyzeStats.py $an_obs_args"
  $graphics_dir/SpawnAnalyzeStats.py $an_obs_args

  # move the graphed files to the "graphed" directory
  mkdir -p $graph_dir || (log "failed to create $graph_dir" && exit 1)
  log "mv ${passed_files[0]} $graph_dir"
  mv ${passed_files[0]} $graph_dir
  if [ "$ngraphed_files" -eq 0 ]; then
    log "mv ${passed_files[1]} $graph_dir"
    mv ${passed_files[1]} $graph_dir
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
  log ""
  log "`date`"
  log "commandline: $0 $*"

  if [ "$help" != "" ]; then
    usage
  fi

  if [ "$suffix" == "" ] && [ "$graphics_dir" == "" ]; then
    log "suffix (-x <suffix>) is required."
    usage
  fi

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
    check_exists "$output_dir" "output dir" "dir"
    check_exists "$graphics_dir" "graphics dir" "dir"
    check_exists "$graphics_dir/SpawnAnalyzeStats.py" "SpawnAnalyzeStats.py" "file"

    # see if any cron cylc workflowS have finished
    check_running_jobs $LOGDIR
    if [ "$?" -ne 0 ]; then
      log "there were no running jobs"
      #return 0
    fi

    # set up python environment for the graphics tools
    module reset 2> /dev/null
    module load conda/latest
    conda activate npl-2023a

    # process the files in the "succeeded" directory, from oldest to newest
    local passed_jobs=$(ls $LOGDIR/$PASS_DIR)
    for job in $passed_jobs ; do
      # make a graph comparing the 2 oldest workflows which passed
      log "make_graphs $graphics_dir $output_dir $LOGDIR $job"
      make_graphs $graphics_dir $output_dir $LOGDIR $job
    done
  fi
}

main "$@"

