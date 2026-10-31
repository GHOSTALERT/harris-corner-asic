#read timing libraries
create_library_set -name slow_lib \
-timing [list ../synthesis/slow.lib]

create_library_set -name typical_lib \
-timing [list ../synthesis/typical.lib]

create_library_set -name fast_lib \
-timing [list ../synthesis/fast.lib]

#constraint mode
create_constraint_mode -name func_mode \
-sdc_files [list ../synthesis/netlists/harris_top_slow.sdc]

#delay corners
create_delay_corner -name slow_corner \
-library_set slow_lib

create_delay_corner -name typical_corner \
-library_set typical_lib

create_delay_corner -name fast_corner \
-library_set fast_lib

#analysis view
create_analysis_view -name slow_view \
-constraint_mode func_mode \
-delay_corner slow_corner

create_analysis_view -name typical_view \
-constraint_mode func_mode \
-delay_corner typical_corner

create_analysis_view -name fast_view \
-constraint_mode func_mode \
-delay_corner fast_corner

#Set active views
set_analysis_view \
-setup {slow_view} \
-hold {fast_view}
