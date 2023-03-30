#!/bin/tcsh -f
set analysisDir = "$1"
set obsspace = "$2"
set diagnostic = "$3"
set coord = "$4"
set errortype = "$5"

set wd = `pwd`
set outf = ${wd}/${obsspace}_ObsErrorAnchor.yaml
rm $outf

cd $analysisDir/${obsspace}_analyses/BinValAxisProfile/${errortype}/data

grep "${diagnostic}" ${coord}_*_BinValAxis_0-0min_${obsspace}_${errortype}_RMS.yaml | sed 's@.*yaml:\ \+@@' > $outf

## adjust prefixes
ex -c ":%s@.*${obsspace}\(.*\)\(_.*\):@\1\2:\ \&${obsspace}\1Errors@" +":wq" $outf
       
## use to divide relative omf by 100:
# values < 10%
ex -c ":%s@\(\D\)\(\d\)\.\(\d\+\)@\10\.0\2\3@g" +":wq" $outf

# values >= 10%
ex -c ":%s@\(\d\d\)\.\(\d\+\)@\.\1\2@g" +":wq" $outf

# add leading zero where missing
ex -c ":%s@\ \.@\ 0\.@g" +":wq" $outf

# return missing values to originals
ex -c ":%s@9\.990@999\.0@g" +":wq" $outf

## format arrays
ex -c ":%s@\ \[@\r\ \ \[@" +":wq" $outf
ex -c ":%s@\(,.\{-},.\{-},.\{-},.\{-},\)@\1\r\ @g" +":wq" $outf

## indent
ex -c ":%s@^@      @" +":wq" $outf
ex -c ":%s@^\(\ \+\d\)@\ \1@" +":wq" $outf
