#!/usr/bin/env python

import argparse
import h5py
import numpy

#This script is contributed by Fabio Diniz at JCSDA.

def del_from(h5obj: h5py.Group, source: str):
    if source in h5obj:
        del h5obj[source]
    return


def move_to(h5obj: h5py.Group, source: str, target: str):
    if source in h5obj:
        if target in h5obj:
            del h5obj[target]
        return h5obj.move(source, target)


def main(fname, var):

    # open file
    with h5py.File(fname, 'r+') as dst:

        # check if var is present
        if var in dst.keys():

            # save float on the side
            move_to(h5obj=dst,
                    source=var,
                    target=f'{var}_float')

            # create integer based on the float
            data = numpy.ma.masked_values(dst[f'{var}_float'][:].astype('int32'), dst[f'{var}_float'].fillvalue)
            dst.create_dataset_like(var,
                                    dst[f'{var}_float'],
                                    dtype='int32',
                                    data=data)

            # copy attributes from float to int
            for key, val in dst[f'{var}_float'].attrs.items():
                if key == '_FillValue':
                    val = data.fill_value
                dst[var].attrs[key] = val

            # delete float
            del_from(h5obj=dst,
                    source=f'{var}_float')


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='convert variable from float to integer', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-i', '--input', help='ioda input file name', type=str, metavar='ioda_file', required=True)
    parser.add_argument('-v', '--variable', help='variable to convert', type=str, required=True)
    args = parser.parse_args()

    main(args.input, args.variable)



