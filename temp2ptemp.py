#!/usr/bin/env python

import argparse
import netCDF4
import numpy
import seawater

def parseCommandLine():
  """
  Parse the command line and invoke operations.
  """
  parser = argparse.ArgumentParser(description=
      '''
      Reads WOA13 netcdf t/s files and creates a corresponding ptemp file.
      ''',
      epilog='Written by A.Adcroft, 2014. No support offered.')
  parser.add_argument('tFile', type=str,
      metavar='TEMP_FILE',
      help='''netcdf file containing the 'temperature' variable.''')
  parser.add_argument('sFile', type=str,
      metavar='SALT_FILE',
      help='''netcdf file containing the 'salinity' variable.''')
  parser.add_argument('outFile', type=str,
      metavar='PTEMP_FILE',
      help='''netCDF file to construct containing potential temperature.''')
  cla = parser.parse_args()

  numpy.seterr(over='ignore',invalid='ignore')

  writeNetcdf(cla.tFile, cla.sFile, cla.outFile)

def writeNetcdf(tFile, sFile, outFile):
  """
  Creates ptemp netcdf files by copying WOA13 variables/meta-data or
  calculating potential temperature from related t/s data.
  """

  tf = netCDF4.Dataset(tFile, 'r')
  sf = netCDF4.Dataset(sFile, 'r')

  rg = netCDF4.Dataset(outFile, 'w', format='NETCDF3_64BIT')

  # Global attributes
  for a in tf.ncattrs():
    if a not in sf.ncattrs(): raise Exception('Attribute "'+a+'" not in both files!')
    val = getattr(tf,a)
    if a == 'title': val = val.replace('sea_water_temperature','sea_water_potential_temperature')
    elif a == 'summary': val = val.replace('temperature','potential temperature')
    elif a == 'references': val = val + '. ' + getattr(sf,a)
    rg.setncattr(a,val)
  rg.note = 'Potential temperature was calculated using the seawater package (EOS80)'

  # Dimensions
  for d in tf.dimensions:
    if d not in sf.dimensions: raise Exception('Dimension "'+d+'" not in both files!')
    if len(tf.dimensions[d]) != len(sf.dimensions[d]): raise Exception('Dimension "'+d+'" has different size in each file!')
    if d == 'time': rg.createDimension(d,None)
    else: rg.createDimension(d,len(tf.dimensions[d]))

  # Variables
  for v in tf.variables:
    if v in sf.variables: nv = v
    else:
      if v.replace('t_','s_') not in sf.variables: raise Exception('Corresponding s_ variable to "'+v+'" not found!')
      nv = v.replace('t_','ptemp_')
    h = rg.createVariable(nv,tf.variables[v].dtype,tf.variables[v].dimensions)
    for a in tf.variables[v].ncattrs():
      val = tf.variables[v].__getattr__(a)
      if isinstance(val,basestring): val = val.replace('sea_water_temperature','sea_water_potential_temperature')
      h.setncattr(a,val)

  # Static data
  for v in tf.variables:
    if 'time' not in tf.variables[v].dimensions:
      rg.variables[v][:] = tf.variables[v][:]

  depth = tf.variables['depth'][:]

  # Time-dependent data
  for n in range(len(tf.dimensions['time'])):
    for v in tf.variables:
      if 'time' in tf.variables[v].dimensions:
        pv = v.replace('t_','ptemp_')
        sv = v.replace('t_','s_')
        if v not in ['t_an','t_mn']:
          rg.variables[pv][n] = tf.variables[v][n]
        else:
          # Calculate potential temperature
          temp = tf.variables[v][n]
          saln = sf.variables[sv][n]
          ptemp = numpy.zeros(temp.shape)
          if ptemp.shape[0] != len(depth): raise Exception('Number of levels is inconsistent')
          for k in range(depth.shape[0]):
            T = temp[k]  # In-situ temperature (deg C)
            Sp = saln[k] # Practical salinity (psu)
            # Using depth in meters as pressure in dbars seems to be a common approximation
            ptemp[k] = seawater.eos80.ptmp(Sp, T, depth[k])
            # This is a test of sensitivity to the above approximation: rms differences
            # of order 1.8e-3 degC.
            # ptemp[k] = seawater.eos80.ptmp(Sp, T, depth[k]*9.81*1035./1.e4)
            # The following is the EOS80 way and has an rms difference with the ptmp(S,T,z)
            # approximation of 1.3e-3
            # p = seawater.eos80.pres( depth[k], lat )
            # ptemp[k] = seawater.eos80.ptmp(Sp, T, (p.T + 0.*Sp.T).T)
          rg.variables[pv][n] = ptemp

  rg.close()

# Invoke parseCommandLine(), the top-level prodedure
if __name__ == '__main__': parseCommandLine()
