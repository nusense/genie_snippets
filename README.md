# genie_snippets

## some utility scripts that I use in regards to GENIE

* `dump_gsimple_file.C`    - dump entries from a "gsimple" flux file
* `dump_gsimple_file3.C`   - same for ROOT6 + R-3_X_Y
* `myfakefluxgen.C`        - create a gsimple flux file from whole cloth
* `myfakefluxgen3.C`
* `warp_gsimple.C`         - read in file, modify entries, write out new
* `warp_gsimple3.C`

## scripts to drive spline generation on the grid (experts only for now)

* `gen_genie_splines_v3.sh`  - GENIE v3, with offsite capabilities
* `gen_genie_splines_v2.sh`  - old script for GENIE v2

## using gen_genie_spline_v3.sh

Example workflow:
```bash
ssh geniegpvm01.fnal.gov
cd /exp/genie/app/users/rhatcher/GXSPLINE/ # or nova or dune

./gen_genie_splines_v3.sh \
  --top /pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3 \
  --version v3_06_00 \
  --qualifier MY2699i00000:k30:e15 \
  --init \
  --rewrite \
  --tune MY26_99i_00_000 \
  --fetch-tune-from ./MY26_99i \
  --fetch-isotopes $PWD/myisotopes.cfg \
  --genlist Default --knots 30 --emax 15 --split-nu-isotopes \
  --setup ups:genie+trycvmfs%v3_06_00%e26:prof \
  Messenger_production.xml

# creates:
# /pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3/GXSPLINES-v3_06_00-MY2699i00000-k30-e15

./gen_genie_splines_v3.sh \
  --top /pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3 \
  --version v3_06_00 \
  --qualifier MY2699i00000:k30:e15 \
  --finalize-cfg

# launch-dag no longer works due to python issues conflicting w/ jobsub
./gen_genie_splines_v3.sh \
  --top /pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3 \
  --version v3_06_00 \
  --qualifier MY2699i00000:k30:e15 \
  --launch-dag=genie

# failed, but gave the following command to run
 jobsub_submit --group genie --dag file:///pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3/GXSPLINES-v3_06_00-MY2699i00000-k30-e15/cfg/genie_splines.dag
# take note of cluster info, e.g. 30225521.0@jobsub04.fnal.gov

# check the status
./gen_genie_splines_v3.sh \
  --top /pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3 \
  --version v3_06_00 \
  --qualifier MY2699i00000:k30:15 \
  --status 

```
