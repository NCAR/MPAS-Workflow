#!/bin/csh -f
#ncar_pylib  # setup it on command line before run this script!!!
#writediag_fc1 and writediag_fc2 use different cycle_period, 
#they cannot turn on at the same time in this script
setenv writediag_fc1   True 
setenv writediag_fc2   False 
setenv plotdiag_fc1    True  #usually, turn it off for controlexp# turn it on if you want 
setenv plotdiag_fc2    False  #usually, turn it off for controlexp# turn it on if you want
setenv Submit_OMF      False 
   setenv run_omf         False  #Choose it if Submit_OMF true
   setenv diag_stats      False  #Choose it if Submit_OMF true
setenv DADIAG          False 

if ($writediag_fc2 == True || $plotdiag_fc2 == True || $Submit_OMF == True) then
   setenv start_init     2018050100  #10day FC(FC2) begin time
else
   setenv start_init     start_initTEMPLATE #cycling run(DA,FC1) begin time
endif

# end_init is set in cycling_autotest.sh
setenv end_init       end_initTEMPLATE # Should be one less cycle than DA/FC?
setenv BIN_DIR        ${HOME}/bin
setenv DATAtime       ${start_init}
setenv currdir  `basename "$PWD"`
#
if ($writediag_fc1 == True || $DADIAG == True) then
   setenv CYCLE_PERIOD   6
else 
   setenv CYCLE_PERIOD   12
endif

while ( ${DATAtime} <= ${end_init} )

   #Submit_OMF
   if ($Submit_OMF == True) then
      #setenv CYCLE_PERIOD  12 
      set time_fc  = `${HOME}/bin/advance_cymdh ${DATAtime}  24`
      set time_endfc = `${HOME}/bin/advance_cymdh ${DATAtime} 240` # 48`
      @ it = 1 
      while ( $time_fc <= $time_endfc )
         setenv fc_num  $it
         echo "check fc_num" $fc_num 
         sed  -e '/^ setenv/s/DADATE/'${DATAtime}'/' \
              -e '/^#PBS/s/DADATE/'${DATAtime}'/' \
              -e '/^#PBS/s/timefc/'${time_fc}'/' \
              -e '/^ setenv/s/timefc/'${time_fc}'/' \
         omf.csh  > run_omf.csh_${DATAtime}_${time_fc}
         chmod 744 run_omf.csh_${DATAtime}_${time_fc}
         qsub run_omf.csh_${DATAtime}_${time_fc}
         sleep 1
         #mv run_omf.csh_${DATAtime}_${time_fc}  ./history/history_csh
         set time_fc  = `${BIN_DIR}/advance_cymdh ${time_fc} ${CYCLE_PERIOD}`
         @ it ++
      end
   endif

   #Submit DADIAG
   if ($DADIAG == True) then
      sed  -e '/^setenv/s/DATAtime/'${DATAtime}'/' \
           -e '/^#PBS/s/DATAtime/'${DATAtime}'/' \
       dadiag.csh  >  run_dadiag.csh_${DATAtime}
      chmod 744 run_dadiag.csh_${DATAtime}
      qsub run_dadiag.csh_${DATAtime}
   endif

   #Verify fc1(fc1.csh, 6hFC)
   if ($writediag_fc1 == True) then
      sed  -e '/^setenv/s/DATAtime/'${DATAtime}'/' \
           -e '/^#PBS/s/DATAtime/'${DATAtime}'/' \
      fc1diag.csh  >  run_fc1diag.csh_${DATAtime}
      chmod 744 run_fc1diag.csh_${DATAtime}
      #./run_fc1diag.csh_${DATAtime}
      qsub run_fc1diag.csh_${DATAtime} 
   endif

   #Verify fc2(fc2.csh, 10day FC)
   if ($writediag_fc2 == True) then
      #setenv CYCLE_PERIOD   24
      sed  -e '/^setenv/s/DATAtime/'${DATAtime}'/' \
           -e '/^#PBS/s/DATAtime/'${DATAtime}'/' \
      fc2diag_12.csh   >  run_fc2diag_12.csh_${DATAtime}
      chmod 744 run_fc2diag_12.csh_${DATAtime}
      qsub run_fc2diag_12.csh_${DATAtime}
   endif

   set DATAtime  = `${BIN_DIR}/advance_cymdh ${DATAtime} ${CYCLE_PERIOD}`
   #sleep 2 
   echo $DATAtime
end

# run plot fc1 seperately
if ($plotdiag_fc1 == True & $writediag_fc1 == False) then
   set DATAtime = $end_init
   echo $DATAtime  $end_init
   sed  -e '/^setenv/s/DATAtime/'${DATAtime}'/' \
        -e '/^#PBS/s/DATAtime/'${DATAtime}'/' \
   fc1diag.csh  >  run_fc1diag.csh_${DATAtime}
   chmod 744 run_fc1diag.csh_${DATAtime}
   qsub run_fc1diag.csh_${DATAtime}
endif
# run plot fc2 seperately
if ($plotdiag_fc2 == True & $writediag_fc2 == False) then
   set DATAtime = $end_init
   sed  -e '/^setenv/s/DATAtime/'${DATAtime}'/' \
        -e '/^#PBS/s/DATAtime/'${DATAtime}'/' \
   fc2diag_12.csh  >  run_fc2diag_12.csh_${DATAtime}
   chmod 744 run_fc2diag_12.csh_${DATAtime}
   qsub run_fc2diag_12.csh_${DATAtime}
endif

exit
