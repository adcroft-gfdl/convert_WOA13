# convert_WOA13

This package is provided on an "as is" basis and the user assumes responsibility for its use.  This is **NOT** part of the NOAA-NODC World Ocean Atlas products.

## Purpose

1. Download all the [World Ocean Atlas (2013)](https://www.nodc.noaa.gov/OC5/woa13/) 1-degree climatological ocean data;
1. Calculate potential temperature for each time-period and analysis frequency;
1. Install the above data in a convenient format (e.g. monthly data in one file) in a local directory;
1. Document and record the above process for the purpose of reproducibility in the future.

## Usage

To install all the data in the directory *directory*, 
```bash
git clone https://github.com/adcroft-gfdl/convert_WOA13.git directory
```
and from that directory type `make` and wait.

Basic usage:
- `make`       - Install and do everything.
- `make check` - Run md5sum on raw and final files to confirm there are no download errors or corruptions.

If you get an error from `ncks`, check you are using a new version of NCO (see requisites below)

Make specific targets:
- `make woa13_1975-1984_ptemp_seasonal_01.nc` - will calculate potential-temperature each of the four climatological seasons for the 1975-1984 period in the WOA13 dataset, downloading any raw files as needed.

## What it does

1. For each target, say woa13_2005-2012_ptemp_seasonal_01.nc, all dependencies are stored in *work/* .
1. All netcdf files, other than the raw data, are in netcdf3 64-bit format so that they can be bitwise reproduced.
1. The 'time' axis in intermediate and final data is a record-dimension (WOA13 data uses a fixed dimension).
1. For each file in *work/*, any raw-data dependencies, e.g. woa13_A5B2_t14_01.nc, are downloaded to *raw/* .
1. When the python seawater package is needed, it downloads that in *work/* .
1. Potential temperature is calculated for the '_an' (objectively analyzed) and '_mn' (statistical mean) fields but the other statistics (.e.g '_sd', standard-deviation) are assumed to be equivalanet for temperature and potential-temperature and are simply copied.
1. We use the python `seawater` package which uses the EOS-80 equation of state, an old and derided equation of state. However, it works and seems to be accurate enough. Consider EOS-80 a place-holder.

After everything has been downloaded, calculated and installed, it is safe to remove the work directory.

## Requisites

- An internet connection
- python 2.7+, wget, nco 4.3+ (netcdf operators)
- 44Gb of space for the raw data, 100Gb for the work space and 59Gb for the final data. This would add up to over 200Gb of space BUT we use hard-links where possible so that the total footprint before cleanup is about 141Gb. After removing the *work/* directory the combined footprint of raw and final data is about 102Gb.
