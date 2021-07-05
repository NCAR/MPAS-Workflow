#!/bin/csh -f
#PBS -N DATAtimediag 
#PBS -l select=1:ncpus=1:mpiprocs=1
#PBS -l walltime=0:25:00
#PBS -q premium
#PBS -A NMMM0015
#PBS -j oe
#PBS -o fc1diag.DATAtime.out 
#PBS -e fc1diag.DATAtime.err

setenv DATE   DATAtime 

setenv end_init       end_initTEMPLATE
setenv writediag_fc1  $writediag_fc1
setenv OneD_plot      $plotdiag_fc1 
setenv TwoD_Plot      $plotdiag_fc1
#
#set environment:
# =============================================
source ./setup.csh
#ncar_pylib   # setup it on command line.
source /glade/u/apps/ch/opt/usr/bin/npl/ncar_pylib.csh

setenv fcHours  6      #0 : only plot ana  (test)
setenv intervalHours 6 
setenv fcNums   2     #2: fc1;  11:fc2

#for modelsp_utils.py
echo '$plotdiag_fc1', $plotdiag_fc1
if ($OneD_plot == True || $TwoD_Plot == True) then
   #                     control_exp    current_exp(or:target_exp)
   set expLongNamestemp = ( 'previousExpTEMPLATE' 'currentExpTEMPLATE' )
   setenv expLongNames  "$expLongNamestemp"
   set expNamestemp     =  ('previous' 'current')
   setenv expNames      "$expNamestemp"
endif

#
# output dir:
# ===============
echo mkdir -p ${FC1DIAG_WORK_DIR}/${DATE}
mkdir -p ${FC1DIAG_WORK_DIR}/${DATE}  
cd ${FC1DIAG_WORK_DIR}/${DATE}

#
# Copy/link files: analysis, background, obs data, feedback file
# ===============
#link all restart files:
ln -fs ${FC1_WORK_DIR}/${DATE}/mpasout.*.nc .   
ln -fs ${FC1_WORK_DIR}/${DATE}/mpasin.*.nc .  #include pressure
rename mpasout. restart. *.nc
rename mpasin.  analysis. *.nc

#mkdir graphics; cd graphics
mkdir diagnostic_stats; cd diagnostic_stats

#fc1,fc2:write diag for each time (for ana, 6hfc), this py script can be used in both fc1 and fc2
if ($writediag_fc1 == True ) then
   python $GRAPHICS_DIR/writediag_modelspace.py
endif

if ($DATE == $end_init) then 
   echo "Sleeping 10m for similar jobs to run..."
   sleep 10m

   #fc1: plot 2d time serial
   if ( $TwoD_Plot == True) then 
      python $GRAPHICS_DIR/plot_modelspace_ts_2d.py  # for pr 

      #rename and move dir 
      rename expmgfs_ ${ExpName}-expmgfs_  *.png
      rename day0. day0p *.png
      mkdir ts_fc1diag_2dim_ana ts_fc1diag_2dim_6hfc
      set dir = (Mean RMS)  # STD MS)
      foreach idir ($dir) 
         mkdir ts_fc1diag_2dim_ana/$idir  ts_fc1diag_2dim_6hfc/$idir
         mv *day0p0*_${idir}* ts_fc1diag_2dim_ana/$idir
         mv *day0p25*_${idir}* ts_fc1diag_2dim_6hfc/$idir
      end
      mv ts_fc1diag_2dim_ana  $TOP_DIR/${ExpName}/
      mv ts_fc1diag_2dim_6hfc $TOP_DIR/${ExpName}/
   endif

   if ($OneD_plot == True ) then
      python $GRAPHICS_DIR/plot_modelspace_ts_1d.py

      #rename and move dir
      rename expmgfs_ ${ExpName}-expmgfs_  *.png
      rename day0. day0p *.png
      mkdir ts_fc1diag_1dim_ana ts_fc1diag_1dim_6hfc
      set dir = (Mean RMS) # STD MS)
      foreach idir ($dir)
         mkdir ts_fc1diag_1dim_ana/$idir  ts_fc1diag_1dim_6hfc/$idir
         mv *day0p0*_${idir}* ts_fc1diag_1dim_ana/$idir
         mv *day0p25*_${idir}* ts_fc1diag_1dim_6hfc/$idir
      end
      mv ts_fc1diag_1dim_ana  $TOP_DIR/${ExpName}/
      mv ts_fc1diag_1dim_6hfc $TOP_DIR/${ExpName}/
   endif

endif
#cd ..

exit
