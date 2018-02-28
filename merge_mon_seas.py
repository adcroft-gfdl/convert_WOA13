#!/usr/bin/env python

import argparse
import netCDF4 as nc
import numpy as np
import os

def arguments():
    description = '''
      Creates full depth monthly mean files by merging
      monthly mean fields above 1500 m and seasonal mean 
      fields below 1500 m.
      '''
    parser = argparse.ArgumentParser(description=description, 
               formatter_class=argparse.RawTextHelpFormatter)
    #-- Output file
    parser.add_argument('-o', '--outfile', type=str, default=None,
                        help='Output file. Default is woa13_decav_+varname+_monthly_fulldepth.nc')
    parser.add_argument('-F','--force',action='store_true',default=False, 
                        help='Clobber existing output file if it exists.')
    parser.add_argument('-v','--varname', type=str, default=None, 
                        help='Variable name to process')
    parser.add_argument('monthlyfile', nargs=1, help='File containing 12 monthly averages')
    parser.add_argument('seasonalfile', nargs=1, help='File containing 4 seasonal averages')
    return parser.parse_args()

def merge_woa(args):
    # Open source data files
    f_mon = nc.Dataset(args.monthlyfile[0])
    f_seas = nc.Dataset(args.seasonalfile[0])
    if args.varname is None:
        varlist = []
        for v in f_mon.variables.keys():
            for s in ['_an','_ma','_mn','_oa','_sd','_se']:
                if v.endswith(s): varlist.append(v)
    else:
        varlist = [args.varname]

    # Initialize output netcdf file
    if args.outfile is None:
        outfile = 'woa13_decav_'+varlist[0].split('_')[0]+'_monthly_fulldepth.nc'
    else:
        outfile = args.outfile
    if os.path.exists(outfile):
        if args.force is True:
            os.remove(outfile)
        else:
            raise ValueError('FATAL: output file exits. Trying using the \'-F\' '+\
                             'option to force overwrite.')
    dataset = nc.Dataset(outfile,'w',format='NETCDF3_CLASSIC')
    # Copy all global attributes
    dataset.setncatts(f_seas.__dict__)
    # Define time axis
    time        = dataset.createDimension('time', None)
    times       = dataset.createVariable('time',  np.float64, ('time',))
    times.units = 'days since 0001-01-01 00:00:00'
    times.cartesian_axis = 'T' 
    times.calendar = 'noleap'
    times.modulo = ' '
    times[:] = np.array([15.5, 45.5, 75.5, 106, 136.5, 167, 197.5, 228.5, 259, \
                        289.5, 320, 350.5])
    # Create bounds dimension
    nbounds =  dataset.createDimension('nbounds', 2)
    # Copy required dimensions from source netcdf file
    field = f_seas[varlist[0]]
    for d in field.dimensions[1::]:
        dimension = f_seas[d]
        dim = dataset.createDimension(d, len(dimension))
        dims = dataset.createVariable(d, np.float64, (d,))
        atts = dimension.__dict__
        # Rename axis attribute to cartesian_axis 
        if 'axis' in atts.keys():
            atts['cartesian_axis'] = atts.pop('axis')
        # Copy bounds associated with the dimension
        if 'bounds' in atts.keys():
            bounds = dataset.createVariable(atts['bounds'], np.float64,\
                                            (d,'nbounds'))
            bounds_atts = f_seas[atts['bounds']].__dict__
            bounds.setncatts(bounds_atts)
            bounds[:] = f_seas[atts['bounds']][:]
        dims.setncatts(atts)
        dims[:] = dimension[:]
    # Write out merged field
    for var in varlist:
        mon = f_mon[var][:]
        seas = f_seas[var][:,57::]
        seas = np.ma.repeat(seas,3,axis=0)
        # Concatenate monthly average fields in the upper 1500 m
        # and seasonal average fields below 1500 m
        data = np.ma.concatenate((mon,seas),axis=1)
        # Grab source field for metadata purposes
        field = f_seas[var]
        outvar = dataset.createVariable(var, np.float32, field.dimensions)
        atts = field.__dict__
        outvar.setncatts(atts)
        outvar.long_name = outvar.long_name+' (seasonal field merged '+\
                       'with monthly field in the upper 1500 m)'
        outvar[:] = data[:]
    # Close dataset
    dataset.close()

if __name__ == '__main__':
    args = arguments()
    merge_woa(args)
