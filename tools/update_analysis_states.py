import argparse
import netCDF4 as nc
def update_variables(file1_path, file2_path):
    # Open the netCDF files
    nc1 = nc.Dataset(file1_path, 'r')
    nc2 = nc.Dataset(file2_path, 'a')
    # Get variables from both files
    vars_file1 = list(nc1.variables.keys())
    vars_file2 = list(nc2.variables.keys())
    # Loop through variables in the second file
    for var_name in vars_file2:
        # Check if the variable is present in the first file
        if var_name in vars_file1:
            print("processing variable:", var_name)
            # Get the variable object from both files
            var1 = nc1.variables[var_name]
            var2 = nc2.variables[var_name]
            # Update values of the variable in the second file
            var2[:] = var1[:]
    # Close the netCDF files
    nc1.close()
    nc2.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='update analysis variables in the background file from the analysis file', formatter_class=argparse.Argum
entDefaultsHelpFormatter)
    parser.add_argument('-i', '--filein', help='analysis file', type=str, required=True)
    parser.add_argument('-o', '--fileout', help='background file', type=str, required=True)
    args = parser.parse_args()
    update_variables(args.filein, args.fileout)
