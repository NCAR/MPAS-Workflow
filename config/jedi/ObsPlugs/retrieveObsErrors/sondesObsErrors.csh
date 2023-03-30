#!/bin/tcsh -f
set analysisDir = "$1"

set obsspace = sondes
set coord = P

set wd = `pwd`
set outf = ${wd}/${obsspace}_ObsErrorAnchor.yaml
rm $outf

set errortype = ObsError
set diagnostic = doadob
cd $analysisDir/${obsspace}_analyses/BinValAxisProfile/${errortype}/data
echo 'absolute doadob:' > $outf
grep -m 1 "${diagnostic}.*_T" ${coord}_*Tro*.yaml | sed 's@.*yaml:\ \+@@' >> $outf
grep -m 1 "${diagnostic}.*_U" ${coord}_*Tro*.yaml | sed 's@.*yaml:\ \+@@' >> $outf
grep -m 1 "${diagnostic}.*_V" ${coord}_*Tro*.yaml | sed 's@.*yaml:\ \+@@' >> $outf

set errortype = RelativeObsError
set diagnostic = rltv_doadob
echo 'relative doadob:' >> $outf
grep -m 1 "${diagnostic}.*_qv" ../../${errortype}/data/${coord}_*Tro*.yaml | sed 's@.*yaml:\ \+@@' >> $outf

## adjust prefixes
ex -c ":%s@.*${obsspace}\(.*\):@\ \ \1:\ \&${obsspace}\1Error@" +":wq" $outf

## selectively divide relative doadob by 100:
ex -c ':12,$s@\(\D\)\(\d\)\.\(\d\+\)@\10\.0\2\3@g' +":wq" $outf # values < 10%
ex -c ':12,$s@\(\d\d\)\.\(\d\+\)@\.\1\2@g' +":wq" $outf # values >= 10%
ex -c ":%s@\ \.@\ 0\.@g" +":wq" $outf # add leading zero where missing
ex -c ":%s@9\.990@999\.0@g" +":wq" $outf # return missing values to originals

## indent
ex -c ":%s@^@      @" +":wq" $outf
