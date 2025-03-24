#!/bin/bash
obsout_dir=YOUR_PATH
tlaps_dir=YOUR_PATH
instruments=""
da_or_hofx=hofx
# get all sat sensors
for fname in `ls $obsout_dir/2018041500/dbOut/obsout_${da_or_hofx}_*_*.h5` ;do 
  basename=`basename $fname`
  basename=`echo $basename | cut -d '.' -f1`
  sensor=`echo $basename |cut -d '_' -f3`
  sat=`echo $basename |cut -d '_' -f4`
  instrument=${sensor}_${sat}
  instruments=${instruments}" "${instrument}
done

# loop over sat sensor
for instrument in $instruments ;do
  echo $instrument
  tlapmean_input=$tlaps_dir/${instrument}_tlapmean.txt
  tlapmean_output=${instrument}_tlapmean_updated.txt
  for datetime in `ls $obsout_dir` ;do
    echo $datetime
    mkdir -p $datetime
    tlapmean_output=$datetime/${instrument}_tlapmean.txt
    obsout_fnames=`ls $obsout_dir/${datetime}/dbOut/obsout_${da_or_hofx}_${instrument}.h5`
    idate=${datetime:0:8}
    cyc=${datetime:8:10}
    idate_pre=`date -d "$idate $cyc -6 hour" +%Y%m%d`
    cyc_pre=`date -d "$idate $cyc -6 hour" +%H`
    echo $idate $cyc $idate_pre $cyc_pre
    if [ $datetime == '2018041500' ] ;then
      ln -sf NULL `pwd`/$datetime/satbias_${instrument}_input.h5
    else
      ln -sf `pwd`/${idate_pre}${cyc_pre}/satbias_${instrument}_output.h5   `pwd`/$datetime/satbias_${instrument}_input.h5
    fi	    
    satbias_input=$datetime/satbias_${instrument}_input.h5
    satbias_output=$datetime/satbias_${instrument}_output.h5
    python -u mpas_jedi_satbias_estimator.py  "$obsout_fnames" $tlapmean_input $tlapmean_output $satbias_input $satbias_output
  done
done
