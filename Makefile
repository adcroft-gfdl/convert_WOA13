# Use nco/4.3.1
FINAL_DIR = .
RAW_DIR = raw
RAW_VERSION = 1.00
RESOLUTION = 01
WORK_DIR = work
ROOT_URL = http://data.nodc.noaa.gov/thredds/fileServer/woa/WOA13/DATAv2
MONTHS = 01 02 03 04 05 06 07 08 09 10 11 12
SEASONS = 13 14 15 16
FREQS = annual seasonal monthly
TPERIODS = 1955-1964 1965-1974 1975-1984 1985-1994 1995-2004 2005-2012 decav

SW = seawater-3.3.2
GSW = gsw-3.0.3
PYTHON_PACKAGES = $(WORK_DIR)/pkg

# All original file names for the "all" period
RAW_ALL = $(foreach v,o O A i n p,$(foreach m,00 $(MONTHS) $(SEASONS),woa13_all_$(v)$(m)_01.nc))
# All original file names for the decadal averages
RAW_DECS = $(foreach d,$(TPERIODS),$(foreach v,t s,$(foreach m,00 $(MONTHS) $(SEASONS),woa13_$(call fn_years2code,$(d))_$(v)$(m)_01.nc)))
# All intermediate file names for the "all" period
INT_ALL = $(foreach v,o O A i n p,$(foreach m,$(FREQS),woa13_all_$(v)_$(m)_01.nc))
# All intermediate file names for the decadal averages
INT_DECS = $(foreach d,$(TPERIODS),$(foreach v,t s,$(foreach m,$(FREQS),woa13_$(call fn_years2code,$(d))_$(v)_$(m)_01.nc)))
# All annual ptemp file names for the decadal averages
INT_PTMP = $(foreach d,$(TPERIODS),$(foreach m,annual,woa13_$(call fn_years2code,$(d))_ptemp_$(m)_01.nc))
# Combined monthly (above 1500m) and seasonal (below 1500m) fields
MERGED_FIELDS = $(foreach tper,$(TPERIODS),$(foreach v,ptemp s,$(FINAL_DIR)/woa13_$(tper)_$(v)_monthly_fulldepth_01.nc))

# fn_variable_name(variable character)
fn_variable_name = $(if $(subst t,,$(1)),,temperature)$(if $(subst s,,$(1)),,salinity)$(if $(subst o,,$(1)),,oxygen)$(if $(subst O,,$(1)),,o2sat)$(if $(subst A,,$(1)),,AOU)$(if $(subst i,,$(1)),,silicate)$(if $(subst p,,$(1)),,phosphate)$(if $(subst n,,$(1)),,nitrate)
# fn_combined_stem(decade, variable, period)
#  Constructs annual file stem
fn_combined_stem = woa13_$(1)_$(2)_$(3)_$(RESOLUTION).nc
# fn_raw_stem(decade, variable, month num)
#  Constructs raw annual file stem
fn_raw_stem = woa13_$(1)_$(2)$(3)_$(RESOLUTION).nc
# fn_raw_path(decade, variable, month num)
#  Constructs path to downloaded raw data, e.g. raw/decav/1.00/woa13_decav_s00_01.nc
fn_raw_path = $(RAW_DIR)/$(1)/$(RAW_VERSION)/$(call fn_raw_stem,$(1),$(2),$(3))
# Returns decade string from raw file name
fn_raw_decade = $(word 2,$(subst _, ,$(1)))
# Returns 1-character variable id from raw file name
fn_raw_vchar = $(firstword $(subst 1, ,$(subst 0, ,$(word 3,$(subst _, ,$(1))))))
# Returns 2-digit month number from raw file name
fn_raw_month = $(subst $(call fn_raw_vchar,$(1)),,$(word 3,$(subst _, ,$(1))))
# Returns frequency from stem file name
fn_final_freq = $(word 4,$(subst _, ,$(1)))
# Converts raw stem into raw path
fn_stem2raw_path = $(call fn_raw_path,$(call fn_raw_decade,$(1)),$(call fn_raw_vchar,$(1)),$(call fn_raw_month,$(1)))
# Maps year range to WOA13 code, e.g. 1995-2004 becomes 95A4
fn_years2code = $(subst 19,,$(subst 200,A,$(subst 201,B,$(subst -,,$(1)))))
# fn_combined_stem(decade, variable, period)
# Constructs path to work file from final file stem
xfn_final2work = $(WORK_DIR)/$(call fn_final_freq,$(1))/$(call fn_combined_stem,$(call fn_raw_decade,$(1)),$(call fn_raw_vchar,$(1)),$(call fn_final_freq,$(1)))
fn_final2work = $(WORK_DIR)/$(call fn_final_freq,$(1))/$(call fn_combined_stem,$(call fn_years2code,$(call fn_raw_decade,$(1))),$(call fn_raw_vchar,$(1)),$(call fn_final_freq,$(1)))

BGC = $(foreach freq,$(FREQS),$(foreach var,o O A i p n,$(FINAL_DIR)/woa13_all_$(var)_$(freq)_$(RESOLUTION).nc))
TS = $(foreach tper,$(TPERIODS),$(foreach freq,$(FREQS),$(foreach var,t s ptemp,$(FINAL_DIR)/woa13_$(tper)_$(var)_$(freq)_$(RESOLUTION).nc)))
all: seawater $(BGC) $(TS) $(MERGED_FIELDS)

# Rule to build a fulldepth monthly file
%_monthly_fulldepth_$(RESOLUTION).nc: %_monthly_$(RESOLUTION).nc %_seasonal_$(RESOLUTION).nc
	export PYTHONPATH=$(PYTHON_PACKAGES)/lib ; ./merge_mon_seas.py -o $@ $(subst monthly_fulldepth,monthly,$@) $(subst monthly_fulldepth,seasonal,$@)

# Rule to install files
define install-final
$(FINAL_DIR)/$1: $(call fn_final2work,$1)
	echo $(call fn_final2work,$1)
	@mkdir -p $$(@D)
	ln -f $$^ $$@
endef
$(foreach f,$(BGC) $(TS),$(eval $(call install-final,$f)))

# Rule to create derived files (potential temperature)
define calc-ptemp
$(WORK_DIR)/annual/woa13_$1_ptemp_annual_$(RESOLUTION).nc:: $(foreach ts,t s,$(WORK_DIR)/annual/woa13_$1_$(ts)_annual_$(RESOLUTION).nc)
	export PYTHONPATH=$(PYTHON_PACKAGES)/lib ; ./temp2ptemp.py $$^ $$@
$(WORK_DIR)/seasonal/woa13_$1_ptemp_seasonal_$(RESOLUTION).nc:: $(foreach ts,t s,$(WORK_DIR)/seasonal/woa13_$1_$(ts)_seasonal_$(RESOLUTION).nc)
	export PYTHONPATH=$(PYTHON_PACKAGES)/lib ; ./temp2ptemp.py $$^ $$@
$(WORK_DIR)/monthly/woa13_$1_ptemp_monthly_$(RESOLUTION).nc:: $(foreach ts,t s,$(WORK_DIR)/monthly/woa13_$1_$(ts)_monthly_$(RESOLUTION).nc)
	export PYTHONPATH=$(PYTHON_PACKAGES)/lib ; ./temp2ptemp.py $$^ $$@
endef
$(foreach f,$(INT_PTMP),$(eval $(call calc-ptemp,$(call fn_raw_decade,$f))))

# Rule to create annual files
define link-annual
$(WORK_DIR)/annual/$1: $(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,$1),$(call fn_raw_vchar,$1),00)
	@mkdir -p $$(@D)
	ln -f $$^ $$@
endef
$(foreach f,$(INT_ALL) $(INT_DECS),$(eval $(call link-annual,$f)))

# Rule to create seasonal files
define combine-seasonal
$(WORK_DIR)/seasonal/$1: $(foreach mon,$(SEASONS),$(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,$1),$(call fn_raw_vchar,$1),$(mon)))
	@mkdir -p $$(@D)
	ncrcat -O --history $$^ $$@
endef
$(foreach f,$(INT_ALL) $(INT_DECS),$(eval $(call combine-seasonal,$f)))

# Rule to create monthly files
define combine-monthly
$(WORK_DIR)/monthly/$1: $(foreach mon,$(MONTHS),$(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,$1),$(call fn_raw_vchar,$1),$(mon)))
	@mkdir -p $$(@D)
	ncrcat -O --history $$^ $$@
endef
$(foreach f,$(INT_ALL) $(INT_DECS),$(eval $(call combine-monthly,$f)))

# Rule to create netcdf3 64-bit version of corresponding raw file with time converted to a record dimension
define netcdf3
$(WORK_DIR)/netcdf3/$1: $(call fn_stem2raw_path,$1)
	@mkdir -p $$(@D)
	ncks -O --64 --mk_rec_dmn time --history $$^ $$@
endef
$(foreach f,$(RAW_ALL) $(RAW_DECS),$(eval $(call netcdf3,$f)))

# Map T/S v2 filename in raw to same filename used in v1 (i.e. without the v2 attached)
define map_TSv2
$(RAW_DIR)/$(call fn_raw_decade,$1)/$(RAW_VERSION)/$1: $(subst .nc,v2.nc,$(RAW_DIR)/$(call fn_raw_decade,$1)/$(RAW_VERSION)/$1)
	cd $$(@D); ln -sf $$(^F) $$(@F)
endef
$(foreach f,$(RAW_DECS),$(eval $(call map_TSv2,$f)))

# Rule to download raw netcdf file
$(RAW_DIR)/%.nc:
	@mkdir -p $(@D)
	cd $(@D); wget $(ROOT_URL)/$(call fn_variable_name,$(call fn_raw_vchar,$*))/netcdf/$(subst $(RAW_DIR)/,,$@); touch --date='2013-09-01' $(@F)

# Checksums
check: check.raw check.final
check.%:
	md5sum -c md5sums.$*
md5sums.raw:
	find $(RAW_DIR)/ -type f | sort | xargs md5sum > $@
md5sums.final:
	ls -1 $(FINAL_DIR)/woa13*.nc | sort | xargs md5sum > $@

# Non-WOA13 stuff

# Rule to obtain seawater python package (EOS-80)
seawater: $(PYTHON_PACKAGES)/lib/seawater
$(PYTHON_PACKAGES)/lib/seawater: $(PYTHON_PACKAGES)/$(SW)
	(cd $< ; python setup.py build -b ../)
$(PYTHON_PACKAGES)/seawater-%: $(PYTHON_PACKAGES)/seawater-%.tar.gz
	tar zvxf $< --directory $(@D)
$(PYTHON_PACKAGES)/seawater-%.tar.gz:
	@mkdir -p $(@D)
	cd $(@D); wget https://pypi.python.org/packages/source/s/seawater/$(@F)

# Rule to obtain Gibbs Sea Water python package (TEOS-10)
$(PYTHON_PACKAGES)/lib/gsw: $(PYTHON_PACKAGES)/$(GSW)
	(cd $< ; python setup.py build -b ../)
$(PYTHON_PACKAGES)/gsw-%: $(PYTHON_PACKAGES)/gsw-%.tar.gz
	(cd $(@D) ; tar zvxf $(<F))
$(PYTHON_PACKAGES)/gsw-%.tar.gz:
	@mkdir -p $(@D)
	cd $(@D); wget https://pypi.python.org/packages/source/g/gsw/$(@F)

