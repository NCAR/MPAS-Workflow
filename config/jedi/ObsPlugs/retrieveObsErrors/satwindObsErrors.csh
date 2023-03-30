#!/bin/tcsh -f
set analysisDir = "$1"

set errortype = ObsError
set obsspace = satwind
set coord = P
set diagnostic = doadob

set wd = `pwd`
set outf = ${wd}/${obsspace}_ObsErrorAnchor.yaml
rm $outf

cd $analysisDir/${obsspace}_analyses/BinValAxisProfile/${errortype}/data

echo '  # satwind' > $outf
grep -m 1 "${diagnostic}.*ObsType.*_U" ${coord}_*-ObsType2*.yaml | sed 's@.*yaml:\ \+@@' | grep -v ObsType245 >> $outf
grep -m 1 "${diagnostic}.*ObsType.*_V" ${coord}_*-ObsType2*.yaml | sed 's@.*yaml:\ \+@@' | grep -v ObsType245 >> $outf

echo '  # satwnd' >> $outf
grep -m 1 "${diagnostic}.*ObsType.*_U" ../../../../satwnd_analyses/BinValAxisProfile/ObsError/data/${coord}_*-ObsType2*.yaml | sed 's@.*yaml:\ \+@@' | grep -v ObsType246 | sed 's@satwnd@satwind@' >> $outf
grep -m 1 "${diagnostic}.*ObsType.*_V" ../../../../satwnd_analyses/BinValAxisProfile/ObsError/data/${coord}_*-ObsType2*.yaml | sed 's@.*yaml:\ \+@@' | grep -v ObsType246 | sed 's@satwnd@satwind@' >> $outf

## adjust prefixes
ex -c ":%s@doadob\ satwind\(.*\):@\ \ \1:\ \&satwind\1Error@" +":wq" $outf

## format arrays
ex -c ":%s@\[999\.0,\ 999\.0,\ 999.0,\ 999\.0,@\[@" +":wq" $outf

## indent
ex -c ":%s@^@    @" +":wq" $outf
