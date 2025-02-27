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
# To generate graphs, the provided workflow is graphed against
#  1. the baseline run.
#  2. the previous run
# After the provided job has been graphed its run file is moved to the "processed" directory.
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
  log "  run_cylc.sh -w <workflow_dir> -g <graphics_dir> -o <output_dir> [-m <mmm_webserver>] [-c <cylc_graph_dir>] [-l log_dir] [-h] "
  log "    -w <workflow_dir> the MPAS-Workflow location"
  log "    -g <graphics_dir> where the mpas-jedi graphics directory is"
  log "    -o <output_dir> where the comparison graphs should go"
  log "    -m <mmm_webserver> the mmm web server content machine, e.g. whitedwarf.mmm.ucar.edu"
  log "       if not provided the graphs won't get copied to the webserver"
  log "    -c <cylc_graph_dir> where the cylc output graphs go on the mmm webserver, e.g. /web/htdocs/<graph-dir-path>"
  log "       if not provided the graphs won't get copied to the webserver"
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
  local output_dir=$2 # where results go, to be sent to web server
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
    check_cylc_job $job_name $run_dir/$job $files_dir $output_dir
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
  local output_dir=$4 # directory to put results in, contents will get sent to the webserver
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
  if [ $retcode -eq 0 ]; then
    log "$job_name failed"
    local today=$(date +%F)
    mkdir -p $fail_dir || (log "failed to create $fail_dir" && return -3)
    mv $job_file $fail_dir
    cp $failed $fail_dir
    mkdir -p $output_dir/$today || (log "failed to create $output_dir/$today" && return -3)
    mv $failed $output_dir/$today
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

# wait for the provided job to either show in the queue ($2 is 1)
# or for the job to leave the queue ($2 is 0)
queue_wait()
{
  local job=$1
  local pcode=$2
  local secs=$3
  local dir="enter"
  if [ "$pcode" == 0 ]; then
    dir="leave"
  fi

  log "waiting for $job to $dir queue, checking every $secs seconds"

  qstat ${job} &> /dev/null
  local rc=$?
  while [ ${rc} == "${pcode}" ]; do
    sleep ${secs}
    qstat ${job} &> /dev/null
    rc=$?
  done
}

# create comparison graphs between the provided cylc experiment and
#   1. the baseline run
#   2. the previous run (if there is one)
make_graphs()
{
  local readonly graphics_dir=$1 # where the mpas-bundle graphing code is
  local readonly output_dir=$2   # where to put the graphs
  local readonly files_dir=$3  # root directory where job files are
  local readonly success_file=$4 # the workflow file to process.

  # assume a name of <workflow>.<yy-mm-dd>* for current runs, 
  # assume a name of <workflow>.baseline* for the baseline run,
  # use the <workflow> part to find baseline run of the same workflow.
  local readonly file_base=${success_file%.*}
  local readonly file_suffix=${success_file#*.} # used to create run specific graph directories
  local readonly pass_dir=$files_dir/$PASS_DIR  # where the passed workflows are
  local readonly graph_dir=$files_dir/$GRAPHED_DIR # where the graphed workflows are
  local date="$(date +%F)"
  # outut dirs for the graphs
  # extract yyyy-mm-dd from the current file name
  local readonly pattern='([0-9]{4}-[0-9]{2}-[0-9]{2})'
  if [[ $success_file =~ $pattern ]]; then
    date=${BASH_REMATCH[0]}
  fi
  local readonly model_out_dir=$output_dir/$date/$file_suffix/model
  local readonly obs_out_dir=$output_dir/$date/$file_suffix/obs
  local base_run="" # the job to be used as the baseline for the graph
  local new_run="" # the current job
  local prev_run="" # the job run prior to the current run
  # PBS directives
  local readonly queue="-q develop"
  local readonly account="-a nmmm0015"
  local readonly memory="-m 12"
  # SpawnAnalyzeStats arguments
  local readonly last_cycle="-l 20180421T18"
  local readonly model_spaces=" -d mpas -p model -t forecast"
  local readonly obs_spaces=" -d amsua_,sonde,airc,sfc,gnssrobndropp1d,satwind,mhs_as  -p obs -t omb/oma"

  if [ "$success_file" == "" ]; then
    log "no job file passed to make_graphs(), no graphs made"
    return
  fi

  # verify the provided job is in the "passed" directory
  ls ${pass_dir}/${success_file}
  if [ "$?" -ne 0 ]; then
    log "the run $success_file is not in $pass_dir, no graphs made"
    return
  fi

  # find the baseline job
  local readonly baseline_files=($(ls ${graph_dir}/${file_base}.base*))
  if [ "${#baseline_files[@]}" -eq 0 ]; then 
    log "the baseline run ${file_base}.baseline* isn't in $graph_dir, no graphs made"
    return
  fi

  # find the run prior to the current run,
  # find the most recent graphed workflow (omitting the baseline run)
  local readonly graphed_files=($(ls -r ${graph_dir}/${file_base}.2*))
  if [ "${#graphed_files[@]}" -gt 0 ]; then
    prev_run=$(cat ${graphed_files[0]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  else
    log "there is no previous run, only graphing against the baseline"
  fi

  base_run=$(cat ${baseline_files[0]} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  local base_label=${base_run#*.}
  base_label=${base_label//"_cron"/}
  new_run=$(cat ${pass_dir}/${success_file} | sed 's/MPAS-Workflow//' | sed 's/\///g')
  local new_label=${new_run#*.}
  new_label=${new_label//"_cron"/}
  local prev_label=${prev_run#*.}
  prev_label=${prev_label//"_cron"/}
  log "newest run: $new_run label ${new_label} in file:${pass_dir}/${success_file}"
  log "previous run: $prev_run label ${prev_label} in file ${graphed_files[0]} "
  log "base run: $base_run label ${base_label} in file ${baseline_files[0]}"

  local readonly base_args=" -s $graphics_dir $last_cycle $queue $account -n 1 $memory"
  local model_base_sync_job=""
  local model_prev_sync_job=""
  local obs_base_sync_job=""
  local obs_prev_sync_job=""

  # make model comparison graphs against the baseline
  gen_graphs $base_label $base_run $new_label $new_run $model_out_dir $graphics_dir "$base_args $model_spaces" model_base_sync_job
  log "make_graphs sync job:$model_base_sync_job"
  queue_wait ${model_base_sync_job} 1 5 # wait for the sync jobs to show up in the queue, check every 5 seconds

  # make omb/oma comparison graphs against the baseline
  gen_graphs $base_label $base_run $new_label $new_run $obs_out_dir $graphics_dir "$base_args $obs_spaces" obs_base_sync_job
  queue_wait ${obs_base_sync_job} 1 5 # wait for the sync jobs to show up in the queue, check every 5 seconds

  if [ "$prev_run" != "" ]; then
    # make forecast comparison graphs against the previous run
    gen_graphs $prev_label $prev_run $new_label $new_run $model_out_dir $graphics_dir "$base_args $model_spaces" model_prev_sync_job
    queue_wait ${model_prev_sync_job} 1 5 # wait for the sync jobs to show up in the queue, check every 5 seconds

    # make omb/oma comparison graphs against the previous run
    gen_graphs $prev_label $prev_run $new_label $new_run $obs_out_dir $graphics_dir "$base_args $obs_spaces" obs_prev_sync_job
    queue_wait ${obs_prev_sync_job} 1 5 # wait for the sync jobs to show up in the queue, check every 5 seconds
  fi

  # wait for the sync jobs to finish, check every 60 seconds
  queue_wait ${model_base_sync_job} 0 60
  queue_wait ${model_prev_sync_job} 0 60
  queue_wait ${obs_base_sync_job} 0 60
  queue_wait ${obs_prev_sync_job} 0 60

  # move the graphed file to the "graphed" directory
  mkdir -p $graph_dir || (log "failed to create $graph_dir" && exit 1)
  log "mv ${pass_dir}/${success_file} $graph_dir"
  mv ${pass_dir}/${success_file} $graph_dir
}

gen_graphs()
{
  local readonly base_name=$1
  local readonly base_run=$2
  local readonly new_name=$3
  local readonly new_run=$4
  local readonly out_dir=$5
  local readonly script_dir=$6
  local readonly script_args=$7

  script_args="$script_args -c $base_name -e $base_name:$base_run,$new_name:$new_run"
  mkdir -p $out_dir/$base_name || (log "failed to create $out_dir/$base_name" && exit 1)
  cd $out_dir/$base_name
  log "making graphs in $out_dir/$base_name"
  log "$script_dir/SpawnAnalyzeStats.py $script_args -w"
  { jobno=$($script_dir/SpawnAnalyzeStats.py $script_args -w 2>&1 >&3 3>&-); } 3>&1

  log "gen_graphs sync job is $jobno"
  eval $8=$jobno
}

copy_graphs()
{
  local readonly source_dir=$1
  local readonly webserver=$2
  local readonly web_graphs_dir=$3

  log "copy_graphs: derecho graphs dir: $source_dir web server:$webserver web graph dir:$web_graphs_dir"

  log "checking $source_dir" 
  for dir in $(/bin/ls $source_dir); do
    log "   dir to copy:$dir" 
    log "   cd $source_dir && tar --remove-files -czf $dir.tgz $dir" 
    cd $source_dir && tar --remove-files -czf $dir.tgz $dir
    log "   scp $source_dir/$dir.tgz $webserver:$web_graphs_dir/" 
    scp $source_dir/$dir.tgz $webserver:$web_graphs_dir/
    log "   ssh $webserver cd $web_graphs_dir/ && tar -xzf $dir.tgz" 
    ssh $webserver "cd $web_graphs_dir/ && tar -xzf $dir.tgz"
    mv $source_dir/$dir.tgz $source_dir/../copied
    log "   finished $dir" 
  done
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
  local webserver=""
  local web_graphs_dir=""
  local help=""
  local CYLC_ENV_SCRIPT="env-setup/machine.sh"

# get command line args
  while getopts w:d:k:g:o:s:x:l:m:c:h flag
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
      m) webserver=${OPTARG};;
      c) web_graphs_dir=${OPTARG};;
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
    check_running_jobs $LOGDIR $output_dir
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
    if [ "$webserver" != "" ] && [ "$web_graphs_dir" != "" ]; then
      copy_graphs $output_dir $webserver $web_graphs_dir
    fi
  fi
}

main "$@"

