#!/bin/bash
#source /glade/work/jianglp/code/mpas_bundle_v3/code/env-setup/gnu-derecho.sh
# ===================================================
obsout_dir=OBSOUT_PATH
tlaps_dir=TLAPS_MEAN_PATH
first_datetime=2024091306
da_or_hofx=hofx
# ===================================================

instruments=""
# get all sat sensors
for fname in `ls $obsout_dir/$first_datetime/dbOut/obsout_${da_or_hofx}_*_*.h5` ;do 
  basename=`basename $fname`
  basename=`echo $basename | cut -d '.' -f1`
  sensor=`echo $basename |cut -d '_' -f3`
  sat=`echo $basename |cut -d '_' -f4`
  instrument=${sensor}_${sat}
  instruments=${instruments}" "${instrument}
done

mkdir -p satbias
# loop over sat sensor
for instrument in $instruments ;do
  echo $instrument
  tlapmean_input=$tlaps_dir/${instrument}_tlapmean.txt
  tlapmean_output=satbias/${instrument}_tlapmean_updated.txt
  obsout_fnames=`ls $obsout_dir/20????????/dbOut/obsout_${da_or_hofx}_${instrument}.h5`
  satbias_input=NULL
  satbias_output=satbias/satbias_${instrument}_updated_all.h5
  python -u mpas_jedi_satbias_estimator.py "$obsout_fnames" $tlapmean_input $tlapmean_output $satbias_input $satbias_output
done
