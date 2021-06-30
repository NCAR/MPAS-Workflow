#!/bin/bash
#
# can modify
TestDir_name=mpas-jedi-autotest
sd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
b=$( basename $sd )    # sd: script dir
cycle_outdir="br_$b" # br=build_run

# keep as is
WorkflowRepo=MPAS-Workflow
WorkflowGit=NCAR
WorkflowBranch=feature/autotest
#WorkflowBranch=develop
#
TopDirectory=`pwd`
TestDir="${TopDirectory}/${TestDir_name}"
exedir="${TopDirectory}/${TestDir_name}/MPAS-Workflow/autotest-setup"


#(I) ck out repo
if [ -d $TestDir ]; then
 echo "Exit; dir exist TestDir=$TestDir"
 echo "Please delete TestDir yourself before complete rebuild and re-run"
 exit -1
else
 mkdir -p ${TestDir}
fi
cd ${TestDir}
git clone --branch ${WorkflowBranch} https://github.com/${WorkflowGit}/${WorkflowRepo}
cd $exedir && mv -f gen_autotest.sh bundle_p*.sh run.sh ${TestDir}/. && cd - 


#(II) Generate crontab file
cat > crontab.txt << EOF
15 01 * * 1,2,3,4,5,6,7  ${TestDir}/bundle_p1.sh ${cycle_outdir} &> ${TestDir}/log.cmake && /opt/pbs/bin/qsub ${TestDir}/job_make_ctest.scr
15 02 * * 1,2,7          ${TestDir}/gen_autotest.sh ${cycle_outdir}  &>  ${TestDir}/log.runda
#
## 15 01 * * 1,2,3,4,5,6  ${TestDir}/bundle_p1.sh ${cycle_outdir} &> ${TestDir}/log.b && /opt/pbs/bin/qsub ${TestDir}/job_make_ctest.scr && ${TestDir}/gen_autotest.sh ${cycle_outdir} &> ${TestDir}/log.t # may not work
EOF


cat > job_make_ctest.scr << EOF
#!/bin/bash
#PBS -A NMMM0015
#PBS -l walltime=00:49:00
#PBS -l select=1:ncpus=6:mpiprocs=6
#PBS -N make_ctest
#PBS -j oe
#PBS -q premium
#PBS -o p2.log 
#PBS -e p2.err
#
${TestDir}/bundle_p2.sh ${cycle_outdir} 2>&1 | tee >> ${TestDir}/log.makectest
EOF


#(III) Modify default cylc settings
cat > global.rc << EOF
[hosts]
    [[localhost]]
        work directory = /glade/scratch/${USER}/cylc-run
        run directory = /glade/scratch/${USER}/cylc-run
        [[[batch systems]]]
            [[[[pbs]]]]
                job name length maximum = 236
EOF
## copy global.rc to your ~/.cylc/ directory
mkdir -p ~/.cylc; cp -p global.rc  ~/.cylc/


#
#cat > job_run_da.scr << EOF
##!/bin/bash
##PBS -A NMMM0015
##PBS -l walltime=03:39:00
##PBS -l select=1:ncpus=1:mpiprocs=1
##PBS -N run_cycle
##PBS -j oe
##PBS -q regular
##PBS -o cycle.log 
##PBS -e cycle.err
##PBS -l inception=login
##
#${TestDir}/gen_autotest.sh ${cycle_outdir}  &> ${TestDir}/test.log
#EOF
#
