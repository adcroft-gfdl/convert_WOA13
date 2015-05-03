# Use nco/4.3.1
FINAL_DIR = .
RAW_DIR = raw
RAW_VERSION = 1.00
RESOLUTION = 01
WORK_DIR = work
ROOT_URL = http://data.nodc.noaa.gov/thredds/fileServer/woa/WOA13/DATA
MONTHS = 01 02 03 04 05 06 07 08 09 10 11 12
SEASONS = 13 14 15 16
FREQS = annual seasonal monthly
TPERIODS = 1955-1964 1965-1974 1975-1984 1985-1994 1995-2004 2005-2012 decav

SW = seawater-3.3.2
GSW = gsw-3.0.3
PYTHON_PACKAGES = $(WORK_DIR)/pkg

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
all: $(BGC) $(TS)

# NOTE: The following rules have no dependencies because of filename translations.
#       This means that a dependency will be created if missing but a target will
#       not get re-made if the dependency is updated.

# Rule to install files
$(FINAL_DIR)/%.nc:
	@mkdir -p $(@D)
	make $(call fn_final2work,$*)
	ln $(call fn_final2work,$*) $@
#
# Rule to create derived files (potential temperature)
$(WORK_DIR)/annual/woa13_%_ptemp_annual_$(RESOLUTION).nc $(WORK_DIR)/seasonal/woa13_%_ptemp_seasonal_$(RESOLUTION).nc $(WORK_DIR)/monthly/woa13_%_ptemp_monthly_$(RESOLUTION).nc: work/pkg/lib/seawater
	@mkdir -p $(@D)
	make $(@D)/$(call fn_combined_stem,$(call fn_raw_decade,$(@F)),t,$(call fn_final_freq,$(@F))) $(@D)/$(call fn_combined_stem,$(call fn_raw_decade,$(@F)),s,$(call fn_final_freq,$(@F)))
	export PYTHONPATH=$(PYTHON_PACKAGES)/lib ; ./temp2ptemp.py $(@D)/$(call fn_combined_stem,$(call fn_raw_decade,$(@F)),t,$(call fn_final_freq,$(@F))) $(@D)/$(call fn_combined_stem,$(call fn_raw_decade,$(@F)),s,$(call fn_final_freq,$(@F))) $@

# Rule to create annual files
$(WORK_DIR)/annual/woa13_%.nc:
	@mkdir -p $(@D)
	make $(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,woa13_$*),$(call fn_raw_vchar,woa13_$*),00)
	ln $(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,woa13_$*),$(call fn_raw_vchar,woa13_$*),00) $@

# Rule to create seasonal files
$(WORK_DIR)/seasonal/woa13_%.nc:
	@mkdir -p $(@D)
	make $(foreach mon,$(SEASONS),$(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,woa13_$*),$(call fn_raw_vchar,woa13_$*),$(mon)))
	ncrcat --history $(foreach mon,$(SEASONS),$(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,woa13_$*),$(call fn_raw_vchar,woa13_$*),$(mon))) $@

# Rule to create monthly files
$(WORK_DIR)/monthly/woa13_%.nc:
	@mkdir -p $(@D)
	make $(foreach mon,$(MONTHS),$(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,woa13_$*),$(call fn_raw_vchar,woa13_$*),$(mon)))
	ncrcat --history $(foreach mon,$(MONTHS),$(WORK_DIR)/netcdf3/$(call fn_raw_stem,$(call fn_raw_decade,woa13_$*),$(call fn_raw_vchar,woa13_$*),$(mon))) $@

# Rule to create netcdf3 64-bit version of corresponding raw file with tiem converted to a record dimension
$(WORK_DIR)/netcdf3/%.nc:
	@mkdir -p $(@D)
	make $(call fn_stem2raw_path,$*)
	ncks --64 --mk_rec_dmn time --history $(call fn_stem2raw_path,$*) $@

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

