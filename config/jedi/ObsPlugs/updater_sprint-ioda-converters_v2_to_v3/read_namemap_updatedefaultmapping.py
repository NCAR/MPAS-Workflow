# Script kindly provided by Mike Cooke (Met Office)
# Some modifications by Anna Shlyaeva (JCSDA)

import csv
import sys
import os

def create_map(inmapfile):
    mappingFile = open(inmapfile, 'r')
    mapping = {}
    for line in mappingFile:
        strippedLine = line.rstrip()
        if "Variable:" in strippedLine:
            varslist = strippedLine.split(":")[1].replace('[', '').replace(']', '').replace('"', '').strip().split("#")[0]
            if ("," in varslist):
                csvarray = varslist.split(",")
                for aa in range(1,len(csvarray)):
                    mapping[csvarray[aa].strip()] = csvarray[0].strip()
    mappingFile.close()
    return mapping
  
def create_new_file(inputfile, outputfile, map):
    infile = open(inputfile, 'r')
    outfile = open(outputfile, 'w')
    # Known issues that might need correcting
    correctingmap = {"satelliteIdentifierentifier" : "satelliteIdentifier"}
    # Lines which contain any in this will be checked
    strings = ("name:", "simulated variables:", "derived variables:",
               "observed variables:", "MetaData", "filter variables:",
               "group variables:", "sort variable:")
    for line in infile:
        outline = line
        if "GeoVaLs" in outline:
            outfile.write(outline)
            continue
        if any(s in outline for s in strings):
            for key, value in map.items():
                if key in outline and '_jacobian_' not in outline and 'assuming_clear_sky' not in outline:
                    outline = outline.replace(key, value)
            for key, value in correctingmap.items():
                if key in outline and '_jacobian_' not in outline and 'assuming_clear_sky' not in outline:
                    outline = outline.replace(key, value)
        outfile.write(outline)
    outfile.close()
    infile.close()
    
def at_to_slash_new_file(infile, outfile):
    infile = open(infile, 'r')
    outfile = open(outfile, 'w')
    for line in infile:
        outline = line
        if ("name:" in line) and ("@" in line):
            linearray = line.split()
            for element in linearray:
                if "@" in element:
                    var, group = element.split("@")
                    oldname = element
                    newname = group + "/" + var
                    outline = line.replace(oldname.strip(), newname.strip())
        outfile.write(outline)
    outfile.close()
    infile.close()
    
def remap_odb_mapping(inputfile, outputfile, map):
    # Read in default odb file
    odbfile = open(inputfile, 'r')
    outfile = open(outputfile, 'w')
    original_stdout = sys.stdout
    sys.stdout = outfile
    for line in odbfile:
        if "name:" in line:
            strippedline = line.rstrip()
            varandgrp = strippedline.split('"')[1]
            if ("/" in varandgrp):
                var = varandgrp.split("/")[1]
            else:
                var = varandgrp
            # Remove trailing numbers from string (e.g. 1, 10, _10)
            if var[-1].isdigit():
                var = var[0:-1]
            if var[-1].isdigit():
                var = var[0:-1]
            if var[-1] == "_":
                var = var[0:-1]
            if var in map.keys():
                print(strippedline.replace(var, map[var]))
            else:
                print(strippedline)
        else:
            print(line.rstrip())
    outfile.close()
    odbfile.close()
    sys.stdout = original_stdout

def main(obsspaceyaml, inputfile, doODB=False):
    # Create mapping
    mapping = create_map(obsspaceyaml)

    # Create new odb mapping file
    if doODB:
        remap_odb_mapping(inputfile, inputfile + '.new', mapping)
    else:
        # Create new yaml file
        create_new_file(inputfile, "tmp.tmp", mapping)

        # Go through output file and switch all x@y to y/x
        at_to_slash_new_file("tmp.tmp", inputfile + '.new')

        # Remove tmp.tmp file
        os.remove("tmp.tmp")

if __name__ == "__main__":
    print(len(sys.argv))
    if len(sys.argv) == 3:
        obsSpaceYaml = sys.argv[1]
        odb_default = sys.argv[2]
        main(obsSpaceYaml, odb_default)
    else:
        obsSpaceYaml = sys.argv[1]
        odb_default = sys.argv[2]
        odb_flag = sys.argv[3]
        if odb_flag.strip() == "T":
            main(obsSpaceYaml, odb_default, doODB=True)
