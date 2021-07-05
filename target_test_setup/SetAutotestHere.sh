#!/bin/bash
#
# can modify
TestDir_name=mpas-jedi-autotest
sd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
b=$( basename $sd )    # sd: script dir
cycle_outdir="br_$b" # br=build_run

# continue modify
WorkflowRepo=MPAS-Workflow
WorkflowGit=NCAR
WorkflowBranch=feature/target_version_test
#WorkflowBranch=develop
#
TopDirectory=`pwd`
TestDir="${TopDirectory}/${TestDir_name}"
exedir="${TopDirectory}/${TestDir_name}/MPAS-Workflow/target_test_setup"


#(I) check out repo
if [ -d $TestDir ]; then
 echo "Exit; dir exist TestDir=$TestDir"
 echo "Please delete TestDir yourself before complete rebuild and re-run"
 exit -1
else
 mkdir -p ${TestDir}
fi
cd ${TestDir}
git clone -b  ${WorkflowBranch} https://github.com/${WorkflowGit}/${WorkflowRepo}
cd $exedir && mv -f gen_autotest.sh bundle_p*.sh run.sh ${TestDir}/. && cd - 



cat > job_make_ctest.scr << EOF
#!/bin/bash
#PBS -A NMMM0015
#PBS -l walltime=00:49:00
####PBS -l select=1:ncpus=6:mpiprocs=6
#PBS -l select=1:ncpus=6
#PBS -N make_ctest
#PBS -j oe
#PBS -q premium
#PBS -o p2.log 
#PBS -e p2.err
#
${TestDir}/bundle_p2.sh ${cycle_outdir} 2>&1 | tee > ${TestDir}/log.makectest
EOF



#(II) Modify default cylc settings
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



##cat > job_make_ctest.scr << EOF
###!/bin/bash
###PBS -A NMMM0015
###PBS -l walltime=00:15:00
######PBS -l select=1:ncpus=6:mpiprocs=6
###PBS -l select=1:ncpus=6
###PBS -N make_ctest
###PBS -j oe
###PBS -q premium
###PBS -o p2.1.log 
###PBS -e p2.1.err
###
##${TestDir}/bundle_p2.1.sh ${cycle_outdir} 2>&1 | tee > ${TestDir}/log.make
##EOF
