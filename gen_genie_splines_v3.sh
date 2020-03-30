#! /usr/bin/env bash
export THISFILE="$0"
export b0=`basename $0`
export GEN_GENIE_SPLINE_VERSION=2019-11-26
echo -e "${OUTRED}GEN_GENIE_SPLINE_VERSION ${GEN_GENIE_SPLINE_VERSION} ${OUTNOCOL}"

export IFDHC_VERSION="" # "v2_3_9"  # usually "" default to v2_1_0 currently
#                              # v2_1_0 now setups up v2_3_6a ifdhc_config
#                              # ... in _some_ cases?
export IFDHC_CONFIG_VERSION="" # "v2_3_9" # force version ""=leave alone
#
# users need to modify the following products of this script:
#   'define_cfg.sh'        adjust parameters in defined function
#   'isotopes.cfg'         text file of which isotopes to use
#   'setup_genie.sh'       define function ( for special cases )
#
##############################################################################
function usage() {
cat >&2 <<EOF
Purpose:  Generate a full GENIE cross-section spline file and auxillary
          packaging appropriate for UPS distribution.

There are two primary steps.  The first initializes a working area and writes
preliminary configuration files.  These are then edited before jobs are
submitted to be run.  The second step finalizes the setup and makes the
necessary files for \"jobsub_client\" condor submission.

All instances need to include the flags:

  ${b0} --top /path/to/top \\
        --version <version> --qualifier <qualifier> \\
        [other flags and optargs]

     -T | --top                 Directory under which to create working area
     -V | --version             e.g. v2_8_6b (usually GENIE version)
                                 scisoft expects "vX_Y_Z[a:z]"
     --tune                     e.g. G00_00b  (historic Default+MEC)

     -Q | --qualifier = {tunex}:k{knots}:e{emax}
                                 no spaces or special characters
                                 echo ${TUNE} | tr -d '_' ( G00_00b_PP_xxx -> G0000bPPxxx )
                                 echo ${EMAX} | tr '.' 'p' | sed -e 's/p0*$//g'

Use --morehelp for further details.

EOF

# $ for v in 400 400. 400.0 400.00 400.1 ; do
#     v2=`echo $v | tr '.' 'p' | sed -e 's/p0*$//g'` ;
#     printf "%-7s  %-7s\n" "$v" "$v2" ;
#   done
# 400      400
# 400.     400
# 400.0    400
# 400.00   400
# 400.1    400p1

}

function extended_help() {
cat >&2 <<EOF
Initialization step uses the flags:

  ${b0} { -T -V -Q } --init [ --rewrite ] [ <import-file1.xml> ... ]


      --init                Create directory structures in output area;
                            Create default configuration files;
                            optionally import XML files (e.g. such as
                            UserPhysicsOptions.xml and/or
                            EventGeneratorListAssembler.xml)
      --fetch-tune-from <path>   look for, copy directory from this path

    optional:

      --rewrite             Allow init to overwrite existing config files

    the following initialize the files with some defaults ... but can
    be edited after the init stage, before starting any processing stages

      --setup    <setup-string>   [${INITSETUPSTR}]  how to setup genie
                 ups:<prd-area>%<genie-ver>%<genie-qual>
                 file:</path/script.sh>

      --knots    <# knots>    [${INITKNOTS}]     # of spline knots
      --emax     <Enu max>    [${INITEMAX}]      max energy of spline
      --tune     <tune-name>  [${INITTUNE}]      model config / tune eg. G00_00b or G18_10j_PP_xxx
      --genlist  <evgenlist>  [${INITGENLIST}]   a config name found in (e.g. "Default")
                                                 EventGeneratorListAssembler.xml
      --electron              [${DOELECTRON}]    do electron scattering instead of neutrinos

      --split-nu-isotopes     [${SPLITNUISOTOPES}]  when doing isotopes run single nu flavors

      --fetch-tune-from       [${FETCHTUNEFROM}]    fetch custom tune info from path

      --skip-stage3-check     DANGER: do NOT do this without very good cause
      --keep-scratch          don't do cleanup of fake_CONDOR_SCRATCH on non-worker node

The initialization procedure creates the actual working area under the
top directory such that:

   /output/path = /path/to/top/GXSPLINES-<version>-<qualifier>/

Once the output area has been initialized, then the user can modify the
files in </output/path>/cfg to define exactly what must be done:

   general_cfg.sh
   setup_genie.sh
   isotopes.cfg

The init

After which one can run:

  ${b0} { -T -V -Q } --finalize-cfg[=<group>]

which generates the files:

   </output/path>/cfg/gen_genie_splines.dag
   </output/path>/cfg/cfg.tar.gz  # collection of all other cfg files

if <group> isn't specified then it will be picked up from \$JOBSUB_GROUP
or \$GROUP.

which allows one to:

  ${b0} { -T -V -Q } --launch-dag[=<group>]

The current status of work products can be check with:

  ${b0} { -T -V -Q } --status

and individual substeps can be run by hand via:

  ${b0} { -T -V -Q } --run-stage <stage> [ -s <subproc-in-stage> ]

 The following stages:
   0:  simply check current progress  (equiv to --status)
   1:  generate individual single nu flavor off a single free nucleon
   2:  combine all sub-files from stage 1
   3:  generate all nu flavors of a single isotope
   4:  combine all sub-files from stage 3
        + create a reduced list of isotopes
        + create ROOT TGraph file
   5:  package into UPS format

 -r | --run-stage=STAGE       do processing for stage [$STAGE]
 -s | --subprocess=INSTANCE   do n-th subprocess for a stage [\$PROCESS]
                              (starting with 0)

      --status              equivalent to --stage 0

 -v | --verbose             increase verbosity
      --debug               used to debug this script
      --trace               enable trace

EOF

#      --ups      <expt>       setup from an experiment's UPS installation
#                                nova, larsoft, genie
#                              [ add +trycvmfs or +cvmfs ]
#                              (if not specified, best guess  [${INITUPS}])
#      --genie-v  <gversion>   [${INITGENIEV}]    UPS version for GENIE
#      --genie-q  <gqualfier>  [${INITGENIEQ}]    UPS qualifier for GENIE
#
}
##############################################################################
if [ -z "$PS1" ]; then
  # if $- contains "i" then interactive session
  export ESCCHAR="\x1B" # or \033 # Mac OS X bash doesn't support \e as esc?
  export OUTBLACK="${ESCCHAR}[0;30m"
  export OUTBLUE="${ESCCHAR}[0;34m"
  export OUTGREEN="${ESCCHAR}[0;32m"
  export OUTCYAN="${ESCCHAR}[0;36m"
  export OUTRED="${ESCCHAR}[0;31m"
  export OUTPURPLE="${ESCCHAR}[0;35m"
  export OUTORANGE="${ESCCHAR}[0;33m" # orange, more brownish?
  export OUTLTGRAY="${ESCCHAR}[0;37m"
  export OUTDKGRAY="${ESCCHAR}[1;30m"
  # labelled "light but appear in some cases to show as "bold"
  export OUTLTBLUE="${ESCCHAR}[1;34m"
  export OUTLTGREEN="${ESCCHAR}[1;32m"
  export OUTLTCYAN="${ESCCHAR}[1;36m"
  export OUTLTRED="${ESCCHAR}[1;31m"
  export OUTLTPURPLE="${ESCCHAR}[1;35m"
  export OUTYELLOW="${ESCCHAR}[1;33m"
  export OUTWHITE="${ESCCHAR}[1;37m"
  export OUTNOCOL="${ESCCHAR}[0m" # No Color
fi
# use as:   echo -e "${OUTRED} this is red ${OUTNOCOL}"
##############################################################################
#echo about to define create_define_cfg
function create_define_cfg()
{

if [ ${INITKNOTS} -lt 30 ]; then
  echo -e "${OUTRED}${b0}: ===========================================================${OUTNOCOL}"
  echo -e "${OUTRED}${b0}: choosing only ${INITKNOTS} knots (<30) probably isn't a good idea ${OUTNOCOL}"
  echo -e "${OUTRED}${b0}: ===========================================================${OUTNOCOL}"
fi

cat > define_cfg.sh <<EOF
##############################################################################
#
# USER MODIFIABLE part of the script is at the front
#   define the parameters of this run
#
##############################################################################
function define_cfg()
{
  # This configuration is for:
  #   GXSPLVERSION="$GXSPLVERSION"     # scisoft expects e.g. "v2_8_6a"
  #   GXSPLQUALIFIER="$GXSPLQUALIFIER"   # normally "default"
  #   OUTPUTDIR=${OUTPUTTOP}/${GXSPLVERSION}-${GXSPLQUALIFIER}
  #

  #
  # details of the actual splines
  #
  # if KNOTS=0, then use 15 knots per decade of energy range
  #             with a minimum of 30 knots totally.
  export KNOTS=${INITKNOTS}
  export EMIN=0.01    # (ignored by gxspl)
  export EMAX=${INITEMAX}

  export ELECTRONPROBE=${INITDOELECTRON}
  export SPLITNUISOTOPES=${SPLITNUISOTOPES}

  # collection of event generator process to calculate
  #   (see:  \$GENIE/config/${INITTUNECMC}/TuneGeneratorList.xml )
  #
  export TUNE="${INITTUNE}"                   # model config / tune name
  export TUNECMC="${INITTUNECMC}"             # comprehensive model config
  export EVENTGENERATORLIST="${INITGENLIST}"  # normally "Default"

  export CUSTOMTUNE=${CUSTOMTUNE}

  # scisoft tarball distribution expects files names of the form
  #   genie_xsec-2.9.0-noarch-default.tar.bz2
  export GXSPLVDOTS=`echo \${GXSPLVERSION} | sed -e 's/^v//' -e 's/_/\./g' `
  export UPSTARFILE="genie_xsec-\${GXSPLVDOTS}-noarch-\${GXSPLQUALIFIERDASHES}.tar.bz2"

  #
  # two spline files will be generated:
  # file names of the form:
  #    gxspl-\${GXSPLBASE}\${GXSPLFULLNAME}.xml
  #       complete set of all generated combinations of nu flavor & isotopes
  #    gxspl-\${GXSPLBASE}\${GXSPLREDUCEDNAME}.xml
  #       reduced set from the former containing only necessary combinations

  if [ \${ELECTRONPROBE} -eq 0 ]; then
    export GXSPLBASE="NU"
  else
    export GXSPLBASE="ELECTRON"
  fi
  export GXSPLFULLNAME="big"
  export GXSPLREDUCEDNAME="small"

  #
  # TGraph file   xsec_graphs.root
  export GXSECTGRAPH="xsec_graphs.root"

  #
  #  \${OUTPUTTOP}/
  #     GXSPLINES-\${GXSPLVERSION}-\${GXSPLQUALIFIERDASHES}/  <--- this is $OUTPUTDIR
  #        cfg/            # configuration files
  #           define_cfg.sh
  #           isotopes.cfg
  #           setup_genie.sh
  #           (optional GENIE XML files,
  #            or directory Gdd_mmv-PP_xxx w/ XML files)
  #        bin/
  #           gen_genie_splines_v3.sh  # copy of this script
  #        work-products/  # individual splines & work logs
  #           freenucs/
  #           isotopes/
  #        ups/             # top of area used for tarball creation
  #           genie_xsec/
  #              \${GXSPLVERSION}.version/
  #                 NULL_\${GXSPLQUALIFIERDASHES}
  #              \${GXSPLVERSION}/NULL/\${GXSPLQUALIFIERDASHES}/
  #                 ups/
  #                    genie_xsec.table
  #                 data/
  #                    README
  #                    gxspl-\${GXSPLBASE}\${GXSPLREDUCEDNAME}.xml
  #                    gxspl-\${GXSPLBASE}\${GXSPLFULLNAME}.xml.gz
  #                    gxspl-freenuc.xml.gz
  #                    \${GXSECTGRAPH} # e.g. xsec_graphs.root
  #                    reduce_gxspl.awk   # script used for reduction

  #
  # which neutrino flavors to include
  #  PROBELISTFULL    - all combinations to generate
  #  PROBELISTREDUCED - flavors to retain in reduced file
  #

  if [ \${ELECTRONPROBE} -eq 0 ]; then
    export PROBEARRAYFULL=( 12 -12 14 -14 16 -16 )
    export PROBEARRAYREDUCED=( 12 -12 14 -14 16 -16 )
  else
    export PROBEARRAYFULL=( 11 )
    export PROBEARRAYREDUCED=( 11 )
  fi

  ############################################################################
  # do not change the following lines
  #echo "=== call process_lists from define_cfg()"
  if [ "\$1" != "--no-lists" ]; then
    setup_ifdh_cp
    if [ \${VERBOSE} -gt 0 ]; then echo process_lists; fi
    process_lists
    #echo "=== done process_lists from define_cfg()"
  fi
}

##############################################################################
### users shouldn't change this next section of define_cfg.sh
##############################################################################
function process_lists()
{

  export FREENUCLIST="1000000010,1000010010"
  export FREENUCNAMES="freen,freep"

  #echo " ....  probes full: \${PROBEARRAYFULL[*]}   reduced: \${PROBEARRAYREDUCED[*]}"
  let NPROBE=0;
  for j in \${PROBEARRAYFULL[*]} ; do let NPROBE=\${NPROBE}+1; done
  export NPROBE
  export PROBELISTFULL=\`echo \${PROBEARRAYFULL[*]} | tr -s ' ' | tr ' ' ','\`
  export PROBELISTREDUCED=\`echo \${PROBEARRAYREDUCED[*]} | tr -s ' ' | tr ' ' ','\`

  #
  #echo "=== process_lists about to get_local_copy cfg/isotopes.cfg"
  get_local_copy cfg/isotopes.cfg 0
  #echo "=== process_lists about to listify_isotopes"
  listify_isotopes   isotopes.cfg

  export FREENUCFILES=""
  export FREENUCPAIRS=""
  export NFREENUCPAIRS=0
  for nth in 1 2 ; do
    set_nth_freenuc \$nth
    for pth in \`seq 1 \$NPROBE\` ; do
      set_pth_probe \$pth
      PRECHAR=""
      if [ -n "\${FREENUCFILES}" ]; then PRECHAR=","; fi
      thisname="\${NAMEP}-\${NAMEN}"
      thispair="\${PDGP}^\${PDGN}"
      # printf "%20s %20s\n" \${thisname}  \${thispair}
      export FREENUCFILES="\${FREENUCFILES}\${PRECHAR}\${thisname}"
      export FREENUCPAIRS="\${FREENUCPAIRS}\${PRECHAR}\${thispair}"
      let NFREENUCPAIRS=\${NFREENUCPAIRS}+1
    done
  done
  #echo "FREENUCFILES \${FREENUCFILES}"
  #echo "FREENUCPAIRS \${FREENUCPAIRS}"

  # name of output of stage2 (sum of all nu-nucleon pairs)
  export FREENUCSUM=gxspl-freenuc
  # name of output of stage4 (full sum of all isotopes)
  export FULLFNAME="gxspl-\${GXSPLBASE}\${GXSPLFULLNAME}"
  export REDUCEDFNAME="gxspl-\${GXSPLBASE}\${GXSPLREDUCEDNAME}"
}
function listify_isotopes()
{
  if [ -z \${ISOTOPESFILE} ]; then export ISOTOPESFILE=\$1; fi

  # remove comments and leading/trailing whitespace
  export ISOLINES=\`cut -d'#' -f1 \${ISOTOPESFILE} | sed -e 's/^ *//' -e 's/ *\$//' | egrep -v "^ *\$" | tr -s ' ' \`
  export NISOTOPES=\`echo "\$ISOLINES" | egrep -c '^100' \`
  # use "\$ISOLINES" to preserve \n, trim trailing ","
  export ISOLISTFULL=\`echo "\$ISOLINES"  | cut -d' ' -f1 | tr [:space:] ',' | sed -e 's/,\$//' \`
  export ISONAMESFULL=\`echo "\$ISOLINES" | cut -d' ' -f2 | tr [:space:] ',' | sed -e 's/,\$//' \`

  # used different selections for "reduced" isotope lists for electrons
  export REDUCEDKEY=reduced
  if [ \${ELECTRONPROBE} -eq 1 ]; then
      export REDUCEDKEY=electron
  fi
  export ISOLISTREDUCED=\`echo "\$ISOLINES" | grep "\$REDUCEDKEY" | cut -d' ' -f1 | tr [:space:] ',' | sed -e 's/,\$//' \`
  export ISONAMESREDUCED=\`echo "\$ISOLINES" | grep "\$REDUCEDKEY" | cut -d' ' -f2 | tr [:space:] ',' \`
  export NISOTOPESREDUCED=\`echo "\$ISOLINES" | grep "\$REDUCEDKEY" | egrep -c '^100' \`
  export ISOLISTTGRAPH=\`echo "\$ISOLINES" | egrep 'root|graph' | cut -d' ' -f1 | tr [:space:] ',' | sed -e 's/,\$//' \`
}

function set_ith_isotope()
{
  # pick 'ith' in list ... starting at 1
  export ITH=\$1
  export PDGI=\`echo \$ISOLISTFULL   | cut -d',' -f\${ITH} \`
  export NAMEI=\`echo \$ISONAMESFULL | cut -d',' -f\${ITH} \`
  export ISOFBASE="gxspl-\${NAMEI}"
}
function set_nth_freenuc()
{
  # pick 'nth' in list ... starting at 1
  export NTH=\$1
  export PDGN=\`echo \$FREENUCLIST   | cut -d',' -f\${NTH} \`
  export NAMEN=\`echo \$FREENUCNAMES | cut -d',' -f\${NTH} \`
}
function set_pth_probe()
{
  # pick 'pth' in list ... starting at 1
  export PTH=\$1
  export PDGP=\`echo \$PROBELISTFULL  | cut -d',' -f\${PTH} \`
  case "\$PDGP" in
     11 ) export NAMEP="electron" ;;
     12 ) export NAMEP="nue"      ;;
     14 ) export NAMEP="numu"     ;;
     16 ) export NAMEP="nutau"    ;;
    -11 ) export NAMEP="positron" ;;
    -12 ) export NAMEP="nuebar"   ;;
    -14 ) export NAMEP="numubar"  ;;
    -16 ) export NAMEP="nutaubar" ;;
  esac
}
function set_fth_freenucpair()
{
  # pick 'fth' in list ... starting at 1
  export FTH=\$1
  pairn=\`echo \${FREENUCFILES} | cut -d',' -f\${FTH} \`
  pairp=\`echo \${FREENUCPAIRS} | cut -d',' -f\${FTH} \`
  export FREENUC1FBASE="gxspl-\${pairn}"
  probe=\`echo \$pairp | cut -d'^' -f1 \`
  target=\`echo \$pairp | cut -d'^' -f2 \`
  export FREENUC1ARGS="\`printf -- "-p %3d -t %d" \$probe \$target\`"
}

function print_isotope_list()
{
    echo NISOTOPES=\$NISOTOPES
    echo ISOLISTFULL=\$ISOLISTFULL
    echo ISONAMESFULL=\$ISONAMESFULL
    echo ISOLISTREDUCED=\$ISOLISTREDUCED
    echo ISOLISTTGRAPH=\$ISOLISTTGRAPH
    if [ \${VERBOSE} -gt 2 ]; then
      for i in \`seq 1 \$NISOTOPES \`
      do
        set_ith_isotope \$i
        printf "%3d  %10d  %s\n" \$ITH \$PDGI \$NAMEI
      done
    fi
}

##############################################################################

export TRIED_GET_OUTPUTDIR_LS="no"

function get_outputdir_ls() {
  if [ "\${TRIED_GET_OUTPUTDIR_LS}" == "yes" ]; then return 0 ; fi

  # what files exist in our output area
  echo "\${b0}:get_outputdir_ls"
  if [ -d \${OUTPUTDIR}/cfg ]; then
    echo -e "\${b0}:\${OUTGREEN}simple find \${OUTPUTDIR}\${OUTNOCOL}"
    find \${OUTPUTDIR} > \${_CONDOR_SCRATCH_DIR}/outputdir.ls
  else
    if [ -z "\${GRID_USER}" ]; then
       # probably not on the grid, so this is just wrong
      echo -e "\${b0}:\${OUTRED} OUTPUTDIR doesn't look like it is configured:"
      echo -e "   \${OUTPUTDIR} \${OUTNOCOL}"
      exit 42
    else
      # probably on the grid, no direct access to pnfs
      # 99 is recursion depth
      ifdh ls --debug=2 \${OUTPUTDIR} 99 > \${_CONDOR_SCRATCH_DIR}/outputdir.ls 2> \${_CONDOR_SCRATCH_DIR}/outputdir.ls.err
      nfound=\`cat \${_CONDOR_SCRATCH_DIR}/outputdir.ls | wc -l \`
      echo -e "\${b0}:ifdh ls \${OUTPUTDIR} gave \${nfound} lines"
      # just check that the cfg directory is there ...
      ## this causes recursion (so don't do it):  have_file \${OUTPUTDIR}/cfg
      nfiles=\`grep -c \${OUTPUTDIR}/cfg/cfg.tar.gz \${_CONDOR_SCRATCH_DIR}/outputdir.ls\`
      if [ \${nfiles} -eq 1 ]; then
        # since cfg is a directory there might be more than one match
        echo -e "\${b0}:OUTPUTDIR/cfg/cfg.tar.gz found via 'ifdh ls' with \${nfiles} in cfg"
      else
        echo -e "\${b0}:\${OUTRED}\${OUTPUTDIR}/cfg/cfg.tar.gz NOT found via 'ifdh ls'"
        echo    "ifdh ls --debug=2 \${OUTPUTDIR} 99 > \${_CONDOR_SCRATCH_DIR}/outputdir.ls"
        ls -l \${_CONDOR_SCRATCH_DIR}/outputdir.ls
        echo   "\$nfiles=grep -c \${OUTPUTDIR}/cfg/cfg.tar.gz \${_CONDOR_SCRATCH_DIR}/outputdir.ls"
        echo    "cat \${_CONDOR_SCRATCH_DIR}/outputdir.ls"
        echo -e "\${OUTLTCYAN}==================================================="
        cat \${_CONDOR_SCRATCH_DIR}/outputdir.ls
        echo -e "===================================================\${OUTRED}"
        echo    "cat \${_CONDOR_SCRATCH_DIR}/outputdir.ls.err"
        echo -e "\${OUTLTCYAN}==================================================="
        cat \${_CONDOR_SCRATCH_DIR}/outputdir.ls.err
        echo -e "===================================================\${OUTRED}"
        echo IFDHC_DIR=\${IFDHC_DIR}
        echo IFDHC_CONFIG_DIR=\${IFDHC_CONFIG_DIR}
        echo -e "\${OUTNOCOL}"

      fi
    fi
  fi
  export TRIED_GET_OUTPUTDIR_LS=yes
  echo -e "\${b0}:\${OUTGREEN}completed get_outputdir_ls \${OUTPUTDIR}\${OUTNOCOL}"
}

function have_file () {
  filetocheck=\$1
  #echo "\${b0}:run have_file \${filetocheck}  \${TRIED_GET_OUTPUTDIRLS}"
  if [ "\${TRIED_GET_OUTPUTDIR_LS}" != "yes" ]; then
    get_outputdir_ls
  fi
  # NOTE: this is an _incomplete_ match ... it just a quick test for sanity
  #    looking for xyz.ext might match xyz.ext-other
  ncopies=\`grep -c \${filetocheck} \${_CONDOR_SCRATCH_DIR}/outputdir.ls\`
  return \${ncopies}
}

function get_local_copy () {
   leafpath=\$1
   failokay=0
   if [ \$# -gt 1 ]; then failokay=\$2 ; fi
   fullpath=\${OUTPUTDIR}/\${leafpath}
   localfile=\`basename \${fullpath}\`

   if [[ -n "\${VERBOSE}" && \${VERBOSE} -gt 0 ]]; then
     echo "get_local_copy pwd \`pwd\`"
     echo "get_local_copy MYCP=\"\${MYCP}\""
     echo "get_local_copy leafpath=\${leafpath}"
     echo "get_local_copy localfile=./\${localfile}"
   fi

   have_file \${fullpath}
   nfiles=\$?
   echo "get_local_copy have_file returned \${nfiles}"
   if [ \${nfiles} -ne 1 ]; then
     echo -e "\${b0}:\${OUTRED}get_local_copy of \${fullpath} not possible (\${nfiles} files)\${OUTNOCOL}" >&2
     if [ \${nfiles} -eq 0 -a \${failokay} -eq 1 ]; then
       status=127
       echo -e "\${b0}:\${OUTYELLOW}get_local_copy of \${leafpath} fail is allowed, return status=\${status}\${OUTNOCOL}" >&2
       return \${status}
     fi
     echo "\${_CONDOR_SCRATCH_DIR}/outputdir.ls:" >&2
     cat   \${_CONDOR_SCRATCH_DIR}/outputdir.ls >&2
     exit 142
   else
     echo "get_local_copy with: \${MYCP} \${fullpath} ./\${localfile}"
     \${MYCP} \${fullpath} ./\${localfile}
     status=\$?
     if [ \${status} -ne 0 ]; then
       echo -e "\${b0}:\${OUTRED}get_local_copy of \${leafpath} failed using \${MYCP} status=\${status}\${OUTNOCOL}" >&2
       if [ \${failokay} -eq 1 ]; then
         echo -e "\${b0}:\${OUTYELLOW}get_local_copy of \${leafpath} fail is allowed, return status=\${status}\${OUTNOCOL}" >&2
         return \${status}
       fi
       exit \${status}
     fi
     return 0
   fi
}
##############################################################################

EOF
} # end-of-function create_define_cfg
##############################################################################
#echo about to define create_isotopes_file
function create_isotopes_file()
{
## GENIE version isn't necessarily known at this point
#  gmajor=`echo ${GXSPLVDOTS} | cut -d. -f1`
#  gminor=`echo ${GXSPLVDOTS} | cut -d. -f2`

  cat > isotopes.cfg <<EOF
##############################################################################
#
# which isotopes to include
#
#   lines of the form: 100ZZZAAA0 isoName [%abundance] [ reduced [ root ] ]
#   comment out (leading '#') lines for undesired isotopes (& comments)
#   add 'reduced' to keep in 'small' file
#   add 'root' to include in TGraph file
#   %abundance isn't used, but there for reference
#      if %abundance < 0 then not found in nature but sometimes appears
#      in geometry specifications (often an average of others isotopes)
#
##############################################################################
#
### neutron
  1000000010    free-n  100.       reduced  root
#
### hydrogen
  1000010010    H1     99.9885    reduced         electron
  1000010020    H2      0.0115    reduced   root
#
### helium   # skip He3
  1000020030   He3      0.000137                  electron
  1000020040   He4     99.9999    reduced         electron
#
### lithium  # skip all
# 1000030060   Li6      7.59
# 1000030070   Li7     92.41
#
### beryllium
  1000040090   Be9    100.        reduced
#
### boron
  1000050100   B10     19.9
  1000050110   B11     80.1       reduced
#
### carbon
  1000060120   C12     98.93      reduced   root  electron
  1000060130   C13      1.07
#
### nitrogen
  1000070140   N14     99.632     reduced  root
  1000070150   N15      0.368
#
### oxygen
  1000080160   O16     99.757     reduced  root
  1000080170   O17      0.038
  1000080180   O18      0.205
#
### fluorine
  1000090190  F19     100.        reduced
#
### neon # skip all
# 1000100200  Ne20     90.48
# 1000100210  Ne21      0.27
# 1000100220  Ne22      9.25
#
### sodium
  1000110230  Na23    100.        reduced
#
### magnesium
  1000120240  Mg24     78.99      reduced
  1000120250  Mg25     10.0
  1000120260  Mg26     11.01
#
### aluminum
  1000130270  Al27    100.        reduced
#
### silicon
  1000140280  Si28     92.2297    reduced
  1000140290  Si29      4.6832
  1000140300  Si30      3.0872
#
### phosphorus
  1000150310  P31     100.        reduced
#
### sulfur  # skip 36
  1000160320   S32     94.93      reduced  root
  1000160330   S33      0.76
  1000160340   S34      4.29
# 1000160360   S36      0.02
#
### chlorine
  1000170350  Cl35     75.78      reduced  root
  1000170360  Cl36   -999.0       reduced
  1000170370  Cl37     24.22      reduced
#
### argon
  1000180360  Ar36      0.3365
  1000180380  Ar38      0.0632
  1000180390  Ar39   -999.0
  1000180400  Ar40     99.6003    reduced  root
#
### potassium
  1000190390   K39     93.2581    reduced
  1000190400   K40      0.0117
  1000190410   K41      6.7302
#
# calcium
  1000200400  Ca40     96.941     reduced        electron
  1000200410  Ca41   -999.0
  1000200420  Ca42      0.647
  1000200430  Ca43      0.135
  1000200440  Ca44      2.086
# 1000200460  Ca46      0.004
# 1000200480  Ca48      0.187
#
### scandium
#  1000210450  Sc45   100.
#
### titanium
  1000220460  Ti46      8.25
  1000220470  Ti47      7.44
  1000220480  Ti48     73.72      reduced  root  electron
  1000220490  Ti49      5.41
  1000220500  Ti50      5.18
#
### vanadium
  1000230500   V50      0.25
  1000230510   V51     99.75      reduced
#
### chromium
  1000240500  Cr50      4.345
  1000240510  Cr51   -999.0
  1000240520  Cr52     83.789     reduced
  1000240530  Cr53      9.501
  1000240540  Cr54      2.365
#
### manganese
  1000250550  Mn55    100.        reduced
#
### iron
  1000260540  Fe54      5.845     reduced
  1000260560  Fe56     91.754     reduced  root  electron
  1000260570  Fe57      2.119     reduced
  1000260580  Fe58      0.282     reduced
#
### cobalt
  1000270590  Co59    100.
#
### nickel
  1000280580  Ni58     68.0769    reduced
  1000280590  Ni59   -999.0       reduced
  1000280600  Ni60     26.2231    reduced
  1000280610  Ni61      1.1399
  1000280620  Ni62      3.6345
  1000280640  Ni64      0.9256
#
### copper
  1000290630  Cu63     69.17      reduced
  1000290640  Cu64   -999.0       reduced
  1000290650  Cu65     30.83      reduced
#
### zinc
  1000300640  Zn64     48.63      reduced
  1000300660  Zn66     27.9
  1000300670  Zn67      4.1
  1000300680  Zn68     18.75
  1000300700  Zn70      0.62
#
### gallium
# 1000310690  Ga69     60.108
# 1000310710  Ga71     39.892
#
### germanium
# 1000320700  Ge70     20.84
# 1000320720  Ge72     27.54
# 1000320730  Ge73      7.73
# 1000320740  Ge74     36.28
# 1000320760  Ge76      7.61
#
### arsenic
# 1000330750  As75    100.
#
### selenium
# 1000340740  Se74      0.89
# 1000340760  Se76      9.37
# 1000340770  Se77      7.63
# 1000340780  Se78     23.77
# 1000340800  Se80     49.61
# 1000340820  Se82      8.73
#
### bromine
  1000350790  Br79     50.69
  1000350800  Br80   -999.0       reduced
  1000350810  Br81     49.31
#
### krypton
# 1000360780  Kr78      0.35
# 1000360800  Kr80      2.28
# 1000360820  Kr82     11.58
# 1000360830  Kr83     11.49
# 1000360840  Kr84     57.0
# 1000360860  Kr86     17.3
#
### rubidium
# 1000370850  Rb85     72.17
# 1000370870  Rb87     27.83
#
### strontium
# 1000380840  Sr84      0.56
# 1000380860  Sr86      9.86
# 1000380870  Sr87      7.0
# 1000380880  Sr88     82.58
#
### yttrium
# 1000390890   Y89    100.
#
### zirconium
# 1000400900  Zr90     51.45
# 1000400910  Zr91     11.22
# 1000400920  Zr92     17.15
# 1000400940  Zr94     17.38
# 1000400960  Zr96      2.8
#
### niobium
# add this to reduced for ICARUS
  1000410930  Nb93    100.        reduced
#
### molybdenum
# 1000420920  Mo92     14.84
# 1000420940  Mo94      9.25
  1000420950  Mo95     15.92
# add this to reduced for ICARUS
  1000420960  Mo96     16.68      reduced
# 1000420970  Mo97      9.55
# 1000420980  Mo98     24.13
# 1000421000 Mo100      9.63
#
### technetium
# 1000430980  Tc98    100.
#
### ruthenium
# DUNE hptpcnd (high pressue TPC NearDet) might have:
#    (all isotopes ... average out to A=101)
#    <material name="TitaniumR56323" state="solid">
#      <T unit="K" value="293.15"/>
#      <MEE unit="eV" value="230.954724444742"/>
#      <D unit="g/cm3" value="4.48"/>
#      <fraction n="0.944" ref="Ti"/>
#      <fraction n="0.03" ref="Al"/>
#      <fraction n="0.025" ref="V"/>   <!-- vanadium -->
#      <fraction n="0.001" ref="Ru"/>  <!-- ruthenium -->
#    </material>
# 1000440960  Ru96      5.54
# 1000440980  Ru98      1.87
# 1000440990  Ru99     12.76
# 1000441000 Ru100      12.6
  1000441010 Ru101     17.06      reduced
# 1000441020 Ru102     31.55
# 1000441040 Ru104     18.62
#
### rhodium
# 1000451030 Rh103    100.
#
### palladium
# 1000461020 Pd102      1.02
# 1000461040 Pd104     11.14
# 1000461050 Pd105     22.33
# 1000461060 Pd106     27.33
# 1000461080 Pd108     26.46
# 1000461100 Pd110     11.72
#
### silver
# 1000471070 Ag107     51.839
# 1000471090 Ag109     48.161
#
### cadmium
# 1000481060 Cd106      1.25
# 1000481080 Cd108      0.89
# 1000481100 Cd110     12.49
# 1000481110 Cd111     12.8
# 1000481120 Cd112     24.13
# 1000481130 Cd113     12.22
# 1000481140 Cd114     28.73
# 1000481160 Cd116      7.49
#
### indium
# 1000491130 In113      4.29
# 1000491150 In115     95.71
#
### tin
# 1000501120 Sn112      0.97
# 1000501140 Sn114      0.66
# 1000501150 Sn115      0.34
  1000501160 Sn116     14.54
  1000501170 Sn117      7.68
  1000501180 Sn118     24.22
  1000501190 Sn119      8.59      reduced
  1000501200 Sn120     32.58
# 1000501220 Sn122      4.63
# 1000501240 Sn124      5.79
#
### antimony
  1000511210 Sb121     57.21
  1000511220 Sb122   -999.0       perhapsfuturered
  1000511230 Sb123     42.79
#
### tellurium
# 1000521200 Te120      0.09
# 1000521220 Te122      2.55
# 1000521230 Te123      0.89
# 1000521240 Te124      4.74
# 1000521250 Te125      7.07
# 1000521260 Te126     18.84
# 1000521280 Te128     31.74
# 1000521300 Te130     34.08
#
### iodine
# 1000531270  I127    100.
#
### xenon
## for 2.8.6 skip 124, 126 (no input isotope defined)
## for 2.8.6 skip 136 (no output I135 isotope)
# 1000541240 Xe124      0.09
# 1000541260 Xe126      0.09
  1000541280 Xe128      1.92
  1000541290 Xe129     26.44
  1000541300 Xe130      4.08
  1000541310 Xe131     21.18      reduced  root
  1000541320 Xe132     26.89
  1000541340 Xe134     10.44
  1000541360 Xe136      8.87
#
### cesium
  1000551330 Cs133    100.        perhapsfuturered
#
### barium
## for 2.8.6 skip 130, 132
# 1000561300 Ba130      0.106
# 1000561320 Ba132      0.101
  1000561340 Ba134      2.417
  1000561350 Ba135      6.592
  1000561360 Ba136      7.854
  1000561370 Ba137      7.854     reduced
  1000561380 Ba138     71.698
#
### lanthanum
# 1000571380 La138      0.09
# 1000571390 La139     99.91
#
### cerium
# 1000581360 Ce136      0.185
# 1000581380 Ce138      0.251
# 1000581400 Ce140     88.45
# 1000581420 Ce142     11.114
#
### praseodynium
# 1000591410 Pr141    100.
#
### neodymium
# 1000601420 Nd142     27.2
# 1000601430 Nd143     12.2
# 1000601440 Nd144     23.8
# 1000601450 Nd145      8.3
# 1000601460 Nd146     17.2
# 1000601480 Nd148      5.7
# 1000601500 Nd15       5.6
#
### promethium
# 1000611450 Pm145    100.
#
### samarium
# 1000621440 Sm144      3.07
# 1000621470 Sm147     14.99
# 1000621480 Sm148     11.24
# 1000621490 Sm149     13.82
# 1000621500 Sm150      7.38
# 1000621520 Sm152     26.75
# 1000621540 Sm154     22.75
#
### europium
# 1000631510 Eu151     47.81
# 1000631530 Eu153     52.19
#
### gadolinium
  1000641520 Gd152      0.2
  1000641540 Gd154      2.18
  1000641550 Gd155     14.8
  1000641560 Gd156     20.47
  1000641570 Gd157     15.65
  1000641580 Gd158     24.84      reduced
  1000641600 Gd160     21.86
#
### terbium
# 1000651590 Tb159    100.
#
### dysprosium
# 1000661560 Dy156      0.06
# 1000661580 Dy158      0.1
# 1000661600 Dy160      2.34
# 1000661610 Dy161     18.91
# 1000661620 Dy162     25.51
# 1000661630 Dy163      24.9
# 1000661640 Dy164     28.18
#
### holmium
# 1000671650 Ho165    100.
#
### erbium
# 1000681620 Er162      0.14
# 1000681640 Er164      1.61
# 1000681660 Er166     33.61
# 1000681670 Er167     22.93
# 1000681680 Er168     26.78
# 1000681700 Er170     14.93
#
### thulium
# 1000691690 Tm169    100.
#
### ytterbium
# 1000701680 Yb168      0.13
# 1000701700 Yb170      3.04
# 1000701710 Yb171     14.28
# 1000701720 Yb172     21.83
# 1000701730 Yb173     16.13
# 1000701740 Yb174     31.83
# 1000701760 Yb176     12.76
#
### lutetium
# 1000711750 Lu175     97.41
# 1000711760 Lu176      2.59
#
### hafnium
# 1000721740 Hf174      0.16
# 1000721760 Hf176      5.26
# 1000721770 Hf177      18.6
# 1000721780 Hf178     27.28
# 1000721790 Hf179     13.62
# 1000721800 Hf180     35.08
#
### tantaium
# 1000731800 Ta180      0.012
# 1000731810 Ta181     99.988
#
### tungsten
  1000741800  W180      0.12
  1000741820  W182     26.5
  1000741830  W183     14.31
  1000741840  W184     30.64     reduced
  1000741860  W186     28.43
#
### rhenium
# 1000751850 Re185     37.4
# 1000751870 Re187     62.6
#
### osmium
# 1000761840 Os184      0.02
# 1000761860 Os186      1.59
# 1000761870 Os187      1.96
# 1000761880 Os188     13.24
# 1000761890 Os189     16.15
# 1000761900 Os190     26.26
# 1000761920 Os192     40.78
#
### irdium
# 1000771910 Ir191      37.3
# 1000771930 Ir193      62.7
#
### platinum
# 1000781840 Pt184      0.014
# 1000781860 Pt186      0.782
# 1000781880 Pt188     32.967
# 1000781890 Pt189     33.832
# 1000781900 Pt190     25.242
# 1000781920 Pt192      7.163
#
### gold
  1000791970 Au197    100.       reduced
#
### mercury
# 1000801960 Hg196      0.15
# 1000801980 Hg198      9.97
# 1000801990 Hg199     16.87
# 1000802000 Hg200      23.1
# 1000802010 Hg201     13.18
# 1000802020 Hg202     29.86
# 1000802040 Hg204      6.87
#
### thallium
# 1000812030 Tl203     29.524
# 1000812050 Tl205     70.476
#
### lead
  1000822040 Pb204      1.4
  1000822060 Pb206     24.1
  1000822070 Pb207     22.1       reduced
  1000822080 Pb208     52.4                      electron
#
### bismuth
# 1000832090 Bi209    100.
#
### polonium
# 1000842090 Po209    100.
#
### astatine
# 1000852100 At210    100.
#
### radon
# 1000862220 Rn222    100.
#
### francium
# 1000872230 Fr223    100.
#
### radium
# 1000882260 Ra226    100.
#
### actinium
# 1000892270 Ac227    100.
#
### thorium
# 1000902320 Th232    100.
#
### protactinium
# 1000912310 Pa231    100.
#
### uranium
# 1000922340  U234      0.0055
# 1000922350  U235      0.72
# 1000922380  U238     99.2745
#
### neptunium
# 1000932370 Np237    100.
#
### plutonium
# 1000942440 Pu244    100.
#
### americium
# 1000952430 Am243    100.
#
### curium
# 1000962470 Cm247    100.
#
### berkelium
# 1000972470 Bk247    100.
#
### californium
# 1000982510 Cf251    100.
#
### einsteinium
# 1000992520 Es252    100.
#
### fermium
# 1001002570 Fm257    100.
#
### mendelevium
# 1001012580 Md258    100.
#
### nobelium
# 1001022590 No259    100.
#
### lawrencium
# 1001032620 Lr262    100.
#
#### end-of-isotope_table
EOF

} # end-of-function create_isotopes_file()
##############################################################################
#echo about to define create_setup_genie
function create_setup_genie()
{
# did we get passed a script file? ... grab it.
if [[ ${INITSETUPSTR} == file:* ]]; then
  fname=`echo ${INITSETUPSTR} | cut -c6-`
  cat $fname > setup_genie.sh
  return
fi

# otherwise should be ups:
if [[ ${INITSETUPSTR} == ups:* ]]; then
  xyzzy=`echo ${INITSETUPSTR} | cut -c5-`
  export INITUPS=`echo $xyzzy | cut -d"%" -f1`
  export INITGENIEV=`echo $xyzzy | cut -d"%" -f2`
  export INITGENIEQ=`echo $xyzzy | cut -d"%" -f3`
else
  echo -e "${OUTRED}${b0}: can't handle setup ${INITSETUPSTR}${OUTNOCOL}"
  exit 2
fi

cat > setup_genie.sh <<EOF
# this file is intended to be sourced by a bash shell
# initially created using GEN_GENIE_SPLINE_VERSION=${GEN_GENIE_SPLINE_VERSION}
if [ -z "\${VERBOSE}" ]; then export VERBOSE=1   ; fi
if [ -z "\${b0}" ]; then export b0=\`basename \${BASH_SOURCE}\` ; fi
# echo VERBOSE=\${VERBOSE} b0=\${b0}
##############################################################################
#
# This source-able (bash) shell script should define a function 'setup_genie'
# that sets up the GENIE environment sufficient for running gmkspl and gspladd
# executables.
#
##############################################################################
function setup_genie()
{
  INITSETPUSTR="${INITSETUPSTR}"
  exptups="${INITUPS}"
  version="${INITGENIEV}"
  qualifier="${INITGENIEQ}"
  if [ \$VERBOSE -gt 0 ]; then
    echo "setup_genie: trying \$exptups \$version \$qualifier"
  fi

  echo "setup_genie: bootstrap_ups \$exptups"
                     bootstrap_ups \$exptups

  bootups_status=\$?
  if [ \${bootups_status} -ne 0 ]; then
    echo -e "\${OUTRED}bootstrap_ups returned \${bootups_status}, setup failed \${OUTNOCOL}"
    return \${bootups_status}
  fi

  echo "setup_genie: setup genie \$version -q \$qualifier"
                     setup genie \$version -q \$qualifier

}
##############################################################################
# bootstrap_ups() is a function that will initialize UPS for many FNAL
# software installations and is used by default by initially created script
##############################################################################
function bootstrap_ups()
{
  exptups=\$1

  # hack, hack - look at me, I'm special...
  if [ "\$exptups" == "rhatcher-nova" ]; then
    source /nova/app/users/rhatcher/externals/setup.sh
    export PRODUCTS=\${PRODUCTS}:/grid/fermiapp/products/common/db
    return 0
  fi

  if [ "\$exptups" == "genie" ]; then
    source /grid/fermiapp/products/genie/bootstrap_genie_ups.sh
    return 0
  fi

  UPS_CVMFS_SETUP=""
  UPS_CVMFS_AUX=/cvmfs/fermilab.opensciencegrid.org/products/common/db
  UPS_DIRECT_AUX=/grid/fermiapp/products/common/db/

  case "\$exptups" in
    rhatcher* ) # my laptop
      UPS_CVMFS_SETUP=""
      UPS_DIRECT_SETUP=/Users/\${USER}/Work/externals/setup
      UPS_DIRECT_AUX=""
      ;;
    genie* ) # genie developer's work area installation
      UPS_CVMFS_SETUP=/cvmfs/fermilab.opensciencegrid.org/products/genie/externals/setup
      UPS_DIRECT_SETUP=/grid/fermiapp/products/genie/externals/setup

      #/grid/fermiapp/products/genie/externals
      #/grid/fermiapp/products/genie/local
      #/grid/fermiapp/products/common/db
      #/grid/fermiapp/products/larsoft
      #/grid/fermiapp/products/nova/externals

      UPS_CVMFS_AUX=/cvmfs/fermilab.opensciencegrid.org/products/genie/local:/cvmfs/fermilab.opensciencegrid.org/products/common/db:/cvmfs/larsoft.opensciencegrid.org/products/:/cvmfs/fermilab.opensciencegrid.org/products/larsoft:/cvmfs/nova.opensciencegrid.org/externals
      UPS_DIRECT_AUX=/grid/fermiapp/products/genie/local:/grid/fermiapp/products/common/db:/grid/fermiapp/products/larsoft:/grid/fermiapp/products/nova/externals

      ;;
    larsoft* | dune* | lbne* | uboone* )
      UPS_CVMFS_SETUP=/cvmfs/larsoft.opensciencegrid.org/products/
      UPS_CVMFS_AUX="/cvmfs/fermilab.opensciencegrid.org/products/larsoft"
      UPS_DIRECT_SETUP=/grid/fermiapp/products/larsoft/setup
      ;;
    nova* )
      UPS_CVMFS_SETUP=""
      UPS_DIRECT_SETUP=/grid/fermiapp/products/nova/externals/setup
      ;;
  esac

  # diskorder
  #    trycvmfs =  2 = try CVMFS first, fall back otherwise
  #    cvmfs    =  1 = only allow CVMFS
  #    -other-  =  0 = try only non-CVMFS location

  case "\$exptups" in
    *try*   ) diskorder="\${UPS_CVMFS_SETUP} \${UPS_DIRECT_SETUP}"
              order="CVMFS then direct"
              ;;
    *cvmfs* ) diskorder="\${UPS_CVMFS_SETUP}"
              order="CVMFS only"
              ;;
    *       ) diskorder="\${UPS_DIRECT_SETUP}"
              order="direct only"
              ;;
  esac

  if [ \${VERBOSE} -gt 0 ]; then
     echo -e "bootstrap_ups: exptups=\$exptups  order=\$order"
     echo -e "  locations:  \$diskorder"
  fi

  # bootstrap the requested version of UPS installation

  for setuploc in \$diskorder
  do

    iscvmfs=\`echo \$setuploc | cut -d/ -f2 | grep -c cvmfs\`
    if [ \$iscvmfs -eq 0 ]; then
      auxpath=\${UPS_DIRECT_AUX}
    else
      auxpath=\${UPS_CVMFS_AUX}
      # check that CVMFS is functional
      /cvmfs/grid.cern.ch/util/cvmfs-uptodate \${setuploc}
      uptodate_status=\$?
      if [ \${uptodate_status} -ne 0 ]; then
        echo -e "bootstrap_ups: \${OUTRED}no cvmfs available\${OUTNOCOL}"
        continue
      fi
    fi

    # can I see the file?
    if [ ! -f \${setuploc} ]; then
      echo -e "bootstrap_ups: \${OUTRED}can't see \${setuploc}\${OUTNOCOL}"
      continue
    fi

    report="source \${setuploc}"
            source \${setuploc}
    which ups > /dev/null 2>&1
    ups_status=\$?
    if [ \$VERBOSE -gt 0 ]; then
      echo -e "bootstrap_ups: ups_status=\${ups_status}"
    fi
    if [ \${ups_status} -ne 0 ]; then
      echo -e "bootstrap_ups: \${OUTRED}not successful using\${setuploc}\${OUTNOCOL}"
      continue
    fi

    if [ -n "\${auxpath}" ]; then
      export PRODUCTS=\${PRODUCTS}:\${auxpath}
      report="\${report}; export PRODUCTS=\\\${PRODUCTS}:\${auxpath}"
    fi
    echo -e "\${OUTGREEN}\${report}\${OUTNOCOL}"
    # we're done ...
    return 0

  done
  # tried all ...
  echo -e "bootstrap_ups: \${OUTRED}could not bootstrap UPS\${OUTNOCOL}"
  return 2
}
##############################################################################
function setup_ifdh_cp()
{
  export MYCP="none"

  VERBOSEIFDHSETUP=1

  if [ -z "\${GRID_USER}" ]; then
    # probably not on the grid
    # interactive nodes "ifdh cp" just doesn't work ...
    export MYCP="cp"
  else
    # is "ifdh" already in our path?
    which_ifdh=\`which ifdh 2>/dev/null \`
    if [ \${VERBOSEIFDHSETUP} -ne 0 ]; then
      echo "which_ifdh is \${which_ifdh}"
    fi
    if [ -n "\${which_ifdh}" ]; then
       export MYCP="ifdh cp "
    else
      # is "setup" /usr/bin/setup (redhat's config tool)?  or our ups command
      is_ups_setup=\`type setup 2>/dev/null | grep -c ups \`
      if [ \${VERBOSEIFDHSETUP} -ne 0 ]; then
        echo "is_ups_setup is \${is_ups_setup}"
        type setup
      fi
      if [ \${is_ups_setup} -gt 0 ]; then
        # setup "current" version if not explicitly set
        setup ifdhc ${IFDHC_VERSION}
        if [ -n "${IFDHC_CONFIG_VERSION}" ]; then
          echo "explicitly setting up ifdhc_config ${IFDHC_CONFIG_VERSION}"
          setup ifdhc_config ${IFDHC_CONFIG_VERSION}
        fi
        export IFDH_CP_MAXRETRIES=2 # because 7 is way too many attepts
        # is "ifdh" now in our path?
        which_ifdh=\`which ifdh 2>/dev/null \`
        if [ \${VERBOSEIFDHSETUP} -ne 0 ]; then
          echo "which_ifdh is \${which_ifdh}"
          echo IFDHC_CONFIG_DIR=\${IFDHC_CONFIG_DIR}
        fi
        if [ -n "\${which_ifdh}" ]; then
          export MYCP="ifdh cp "
        fi
      fi
   fi
 fi

  if [ "\${MYCP}" == "none" ]; then
    echo -e "\${OUTRED}\${b0}: ===========================================================\${OUTNOCOL}"
    echo -e "\${OUTRED}\${b0}: setup_ifdh_cp() ... UPS not bootstrapped \${OUTNOCOL}"
    echo -e "\${OUTRED}\${b0}: setup_ifdh_cp() ... fall back to 'cp' \${OUTNOCOL}"
    echo -e "\${OUTRED}\${b0}: ===========================================================\${OUTNOCOL}"
  fi

  #echo "=== finish setup_ifdh_cp() MYCP=\${MYCP}"

}

VERBOSE=1
if [ \${VERBOSE} -ne 0 ]; then echo "=== run setup_genie()" ; fi
setup_genie

if [ \${VERBOSE} -ne 0 ]; then echo "=== run setup_ifdh_cp()" ; fi
setup_ifdh_cp

if [ \${VERBOSE} -ne 0 ]; then echo "=== complete souce setup_genie.sh" ; fi

##############################################################################
# end-of-script
EOF
echo -e "${OUTBLUE}${b0}: in the future to setup the GENIE environment source do:${OUTNOCOL}"
echo -e "    ${OUTGREEN}source setup_genie.sh${OUTNOCOL}"
#  echo -e "    ${OUTGREEN}setup_genie${OUTNOCOL}"
} # end-of-function create_setup_genie()
##############################################################################
function create_reduce_awk_script()
{
export AWKFILE=reduce_gxspl.awk
cat > ${AWKFILE} <<EOF
#! /usr/bin/gawk -f
# Reduce the combinations of neutrino flavors and target isotopes in a
# GENIE gxspl XML spline file.
#    gawk -f reduce_gxspl.awk gxspl-big.xml > gxspl-small.xml
#
# This only limits what is allowed; if a combination isn't in the
# input file it won't magically appear in the output
#
BEGIN {
  doout=1; keep=1;
  nlines=0; maxlines=0; # set non-zero maxlines only for testing puroses
EOF
echo "  # whether to keep each species of neutrino" >> ${AWKFILE}
for p in `echo ${PROBELISTREDUCED} | tr ',' ' '`; do
  echo "  nukeep[${p}] = 1;   #" >> ${AWKFILE}
done
echo "  # whether to keep particular isotopes" >> ${AWKFILE}
let i=0
for t in `echo ${ISOLISTREDUCED} | tr ',' ' '`; do
  let i=${i}+1
  iname=`echo ${ISONAMESREDUCED} | cut -d, -f${i}`
  echo "  tgtkeep[${t}] = 1;   # ${iname}" >> ${AWKFILE}
done
cat >> ${AWKFILE} <<EOF
}
# decide whether to keep or reject a sub-process x-section based on the
# name string.  Note picking out "nu:XY" and "tgt:XYZ" is dependent on
# the exact naming formulation ... hopefully this won't change.
# example string:
#    <spline name="genie::AhrensNCELPXSec/Default/nu:-14;tgt:1000020040;N:2212;proc:Weak[NC],QES;" nknots="500">
#
/<spline/ {
  keep=0; doout=0;
  # check if we want this set, if yes set both keep & doout = 1
  split(\$0,array,";");
  split(array[2],tgtarray,":");
  tgtval=tgtarray[2];
  split(array[1],nuarray,"/");
  nuvaltmp=nuarray[3];
  split(nuvaltmp,nuarray,":");
  nuval=nuarray[2];
  #print "tgtarray[2] = ",tgtval," nuarray[2] = ",nuval;
  if ( tgtval in tgtkeep ) {
    #print "keep this tgt ",tgtval;
    if ( nuval in nukeep ) {
      keep=1; doout=1;
    } else {
      # print "reject this nu",nuval;
      keep=0; doout=0;
    }
  } else {
    #print "reject this tgt",tgtval;
    keep=0; doout=0;
  }
}
# close out a particular spline
/<\/spline/ {
  if ( doout == 1 ) { keep = 1 } else { keep = 0 }
  doout=1;
}
# regular lines depend on the current state
// {
  if ( keep  == 1 ) print \$0;
  if ( doout == 1 ) keep = 1;
  nlines++;
  if ( maxlines > 0 && nlines > maxlines ) exit
}
# end-of-script reduce_gxspl.awk
EOF

}


##############################################################################
function report_node_info()
{
  nodeA=`uname -n `
  node1=`uname -n | cut -d. -f1`
  krel=`uname -r`
  ksys=`uname -s`
  now=`date "+%Y-%m-%d %H:%M:%S" `
  if [ -f /etc/redhat-release ]; then
    redh=`cat /etc/redhat-release 2>/dev/null | \
         sed -e 's/Scientific Linux/SL/' -e 's/ Fermi/F/' -e 's/ release//' `
  fi
  echo -e "${b0}:${OUTBLUE} report_node_info at ${now} ${OUTNOCOL}"
  echo "   running on ${nodeA} "
  echo "   OS ${ksys} ${krel} ${redh}"
  echo "   user `id`"
  echo "   uname `uname -a`"
  echo "   PWD=`pwd`"
  echo " "
}
function report_setup()
{
  echo -e "${b0}:${OUTBLUE} report_setup ${OUTNOCOL}"
  echo "   using `which gmkspl`"
  echo "   using `which gspladd`"
  echo " "
}
function report_cfg()
{
  echo -e "${b0}:${OUTBLUE} report_cfg ${OUTNOCOL}"
  echo -e "   OUTPUTDIR: ${OUTRED} $OUTPUTDIR ${OUTNOCOL}"
  echo "   version ${GXSPLVERSION} qualifier ${GXSPLQUALIFIER}  (${GXSPLVDOTS})"
  echo "   ${KNOTS} knots  E_nu [${EMIN}:${EMAX}]"
  echo "   tune \"${TUNE}\" EventGeneratorList \"${EVENTGENERATORLIST}\""
  ## echo "   probes full: ${PROBELISTFULL}   reduced: ${PROBELISTREDUCED}"
  echo -n "   complete probe list (${NPROBE}): "
  for p in `echo ${PROBELISTFULL} | tr ',' ' '` ; do echo -n " $p" ; done
  echo " "
  echo -n "   reduced probe list:      "
  for p in `echo ${PROBELISTREDUCED} | tr ',' ' '` ; do echo -n " $p" ; done
  echo " "
  echo "   number of isotopes: $NISOTOPES  (reduced ${NISOTOPESREDUCED})"
  #  echo ISOLISTFULL=$ISOLISTFULL
  #  echo ISONAMESFULL=$ISONAMESFULL
  #  echo ISOLISTREDUCED=$ISOLISTREDUCED
  #  echo ISOLISTTGRAPH=$ISOLISTTGRAPH
  #  if [ ${VERBOSE} -gt 2 ]; then
  #    for i in `seq 1 $NISOTOPES`
  #    do
  #      set_ith_isotope $i
  #      printf "%3d  %10d  %s\n" $ITH $PDGI $NAMEI
  #    done
  #  fi
  echo " "
}
##############################################################################
function print_status()
{
  echo -e "${OUTBLUE}${b0}: print_status ${OUTNOCOL}"

  echo -e "${OUTBLUE}${b0}: stage1 generates ${NFREENUCPAIRS} files ${OUTNOCOL}"
  stage1_status=0
  xlist1=""
  for fth in `seq 1 $NFREENUCPAIRS`
  do
    set_fth_freenucpair $fth
    have_file work-products/freenucs/${FREENUC1FBASE}.xml
    if [ $? -ne 1 ]; then
      let stage1_status=${stage1_status}+1
      let fth0=${fth}-1
      xlist1="${xlist1} ${fth0}"
      xyzzy=`printf "   %3d => %25s %25s" $fth0 ${FREENUC1FBASE}.xml "${FREENUC1ARGS}" `
      echo -e "${OUTRED} ${xyzzy} ${OUTNOCOL}" >&2
    fi
  done
  if [ ${stage1_status} -ne 0 ]; then
    echo -e "${b0}:${OUTRED} stage1 incomplete, missing ${stage1_status} ${OUTNOCOL}"
    echo -e "${OUTRED}   suggest --run-stage 1 -s { $xlist1 } ${OUTNOCOL}"
    return 1
  else
    echo -e "${OUTBLUE}${b0}:${OUTGREEN} stage1 complete ${OUTNOCOL}"
  fi

  echo -e "${OUTBLUE}${b0}: stage2 generates ${FREENUCSUM}.xml ${OUTNOCOL}"
  have_file work-products/${FREENUCSUM}.xml
  if [ $? -ne 1 ]; then
    echo -e "${b0}:${OUTRED} stage2 missing ${FREENUCSUM}.xml ${OUTNOCOL}"
    return 2
  else
    echo -e "${OUTBLUE}${b0}:${OUTGREEN} stage2 complete: ${FREENUCSUM}.xml exists${OUTNOCOL}"
  fi

  if [ ${SPLITNUISOTOPES} -eq 0 ]; then
    echo -e "${OUTBLUE}${b0}: stage3 generates ${NISOTOPES} files ${OUTNOCOL}"
    stage3_status=0
    xlist3=""
    for ith in `seq 1 $NISOTOPES`
    do
      set_ith_isotope $ith
      have_file work-products/isotopes/gxspl-${NAMEI}.xml
      if [ $? -ne 1 ]; then
        let stage3_status=${stage3_status}+1
        let ith0=${ith}-1
        xlist3="${xlist3} ${ith0}"
        xyzzy=`printf "   %3d => %25s  -t %d" $ith0 gxspl-${NAMEI}.xml ${PDGI} `
        echo -e "${OUTRED} ${xyzzy} ${OUTNOCOL}"
      fi
    done
  else
    let NPROBEISOTOPEFILES=${NISOTOPES}*${NPROBE}
    echo -e "${OUTBLUE}${b0}: stage3 generates ${NISOTOPES} x ${NPROBE} = ${NPROBEISOTOPEFILES} files ${OUTNOCOL}"
    stage3_status=0
    xlist3=""
    ith0=-1
    for ith in `seq 1 $NISOTOPES`
    do
      set_ith_isotope $ith
      for pth in `seq 1 $NPROBE`
      do
        set_pth_probe $pth
        let ith0=${ith0}+1
        have_file work-products/isotopes/gxspl-${NAMEP}-${NAMEI}.xml
        if [ $? -ne 1 ]; then
          let stage3_status=${stage3_status}+1
          xlist3="${xlist3} ${ith0}"
          xyzzy=`printf "   %3d => %25s -p %3d -t %d" $ith0 gxspl-${NAMEP}-${NAMEI}.xml ${PDGP} ${PDGI} `
          echo -e "${OUTRED} ${xyzzy} ${OUTNOCOL}"
        fi
      done
    done
  fi
  if [ ${stage3_status} -ne 0 ]; then
    echo -e "${b0}:${OUTRED} stage3 incomplete, missing ${stage3_status} of ${NPROBEISOTOPEFILES} files${OUTNOCOL}"
    echo -e "${OUTRED}  suggest --run-stage 3 -s { $xlist3 } ${OUTNOCOL}"
    if [ ${SKIPSTAGE3CHECK} -eq 1 ]; then
      echo -e "${OUTYELLOW}==============================================================================================${OUTNOCOL}"
      echo -e "${OUTRED}  'Zowie' Batman, you're living dangerously with --skip-stage3-check"
      echo -e "${OUTYELLOW}==============================================================================================${OUTNOCOL}"
    else
      return 3
    fi
  else
    echo -e "${OUTBLUE}${b0}:${OUTGREEN} stage3 complete ${OUTNOCOL}"
  fi

  echo -e "${OUTBLUE}${b0}: stage4 generates ${FULLFNAME}.xml ${OUTNOCOL}"
  have_file work-products/${FULLFNAME}.xml
  if [ $? -ne 1 ]; then
    echo -e "${b0}:${OUTRED} missing ${FULLFNAME}.xml ${OUTNOCOL}"
    return 2
  else
    echo -e "${OUTBLUE}${b0}:${OUTGREEN} ${FULLFNAME}.xml exists ${OUTNOCOL}"
  fi
  echo -e "${OUTBLUE}${b0}: stage4 generates ${REDUCEDFNAME}.xml ${OUTNOCOL}"

  have_file work-products/${REDUCEDFNAME}.xml
  if [ $? -ne 1 ]; then
    echo -e "${b0}:${OUTRED} missing ${REDUCEDFNAME}.xml ${OUTNOCOL}"
    return 2
  else
    echo -e "${OUTBLUE}${b0}:${OUTGREEN} ${REDUCEDFNAME}.xml exists ${OUTNOCOL}"
  fi
  echo -e "${OUTBLUE}${b0}: stage5 generates ${UPSTARFILE} ${OUTNOCOL}"

  have_file ups/${UPSTARFILE}
  if [ $? -ne 1 ]; then
    echo -e "${b0}:${OUTRED} missing ${UPSTARFILE} ${OUTNOCOL}"
    return 2
  else
    echo -e "${OUTBLUE}${b0}:${OUTGREEN} ${UPSTARFILE} exists ${OUTNOCOL}"
  fi

}
##############################################################################
function init_output_area()
{
  if [ -d ${OUTPUTDIR} -a ${REWRITE} -eq 0 ]; then
    echo -e "${b0}: ${OUTRED}output directory already exists for:${OUTNOCOL}"
    echo -e "  ${OUTGREEN}${OUTPUTDIR}${OUTNOCOL}"
    echo -e "${OUTRED}to overwrite existing files use --rewrite${OUTNOCOL}"
    exit 1
  fi
  echo -e "${OUTBLUE}${b0}: create the working area:${OUTNOCOL}"
  echo -e "    ${OUTGREEN}${OUTPUTDIR}${OUTNOCOL}"

  # assumes writable ... don't use PNFS if not mounted NFS4.1
  mkdir -p ${OUTPUTDIR}/cfg
  mkdir -p ${OUTPUTDIR}/bin
  mkdir -p ${OUTPUTDIR}/work-products/freenucs
  mkdir -p ${OUTPUTDIR}/work-products/isotopes
  mkdir -p ${OUTPUTDIR}/ups
#  mkdir -p ${OUTPUTDIR}/ups/genie_xsec/${GXSPLVERSION}.version
#  mkdir -p ${OUTPUTDIR}/ups/genie_xsec/${GXSPLVERSION}/NULL/${GXSPLQUALIFIERDASHES}
#  mkdir -p ${OUTPUTDIR}/ups/genie_xsec/${GXSPLVERSION}/NULL/${GXSPLQUALIFIERDASHES}/ups
#  mkdir -p ${OUTPUTDIR}/ups/genie_xsec/${GXSPLVERSION}/NULL/${GXSPLQUALIFIERDASHES}/data
  # for the grid ...
  chmod -R g+w ${OUTPUTDIR}

  # now make the define_cfg.sh & isotopes.cfg files
  create_define_cfg
  create_isotopes_file
  create_setup_genie

  for f in define_cfg.sh isotopes.cfg setup_genie.sh
  do
    if [ $VERBOSE -gt 0 ]; then echo copy $f to $OUTPUTDIR/cfg; fi
    bname=`basename $f`
    cp $f ${OUTPUTDIR}/cfg/$bname
    rm -f $f
  done

  # these optional xml files (and script) might be full path
  # or relative to orignal location (currently working in scratch area)
  # also don't remove them -- make copies
  for f in $OPTARGS
  do
    if [ ! -f $f ]; then f=$ORIGINALDIR/$f; fi
    if [ $VERBOSE -gt 0 ]; then echo copy $f to $OUTPUTDIR/cfg; fi
    bname=`basename $f`
    cp $f ${OUTPUTDIR}/cfg/$bname
  done

  # copy any custom tune
  if [ ${CUSTOMTUNE} -ne 0 ]; then
    FIRSTCHAR=`echo ${FETCHTUNEFROM} | cut -c1`
    if [ "$FIRSTCHAR" == "." -o "$FIRSTCHAR" != "/" ]; then
      FETCHTUNEFROM="${ORIGINALDIR}/${FETCHTUNEFROM}"
    fi
    cp -va ${FETCHTUNEFROM}/${INITTUNECMC} ${OUTPUTDIR}/cfg/
  fi

  for f in $THISFILE
  do
    if [ ! -f $f ]; then f=$ORIGINALDIR/$f; fi
    if [ $VERBOSE -gt 0 ]; then echo copy $f to $OUTPUTDIR/bin; fi
    bname=`basename $f`
    cp $f ${OUTPUTDIR}/bin/$bname
  done


echo -e "${OUTBLUE}${b0}: output area initialized${OUTNOCOL}"
}
##############################################################################
function generate_freenucpair()
{
  echo -e "${OUTBLUE}${b0}: generate_freenucpair ${OUTNOCOL}"
  set_fth_freenucpair ${CURINSTANCE1}
  XML=${FREENUC1FBASE}.xml
  LOG=${FREENUC1FBASE}.log
  if [ -f $LOG ]; then rm $LOG; fi

  echo " "         >> $LOG
  report_node_info >> $LOG
  report_setup     >> $LOG
  report_cfg       >> $LOG
  echo " "         >> $LOG
  echo "current stage $CURSTAGE subprocess $CURINSTANCE" >> $LOG
  echo " "         >> $LOG

  tbegin=`date "+%Y-%m-%d %H:%M:%S" `
  tbegins=`date "+%s" `
  echo "begin gmkspl at ${tbegin} generate_freenucpair"
  echo "begin gmkspl at ${tbegin} generate_freenucpair" >> ${LOG}

  echo time gmkspl ${GMKSPLARGS} ${FREENUC1ARGS} -o ${XML}
  echo time gmkspl ${GMKSPLARGS} ${FREENUC1ARGS} -o ${XML} >> ${LOG}
       time gmkspl ${GMKSPLARGS} ${FREENUC1ARGS} -o ${XML} 2>&1 \
         | egrep -v 'GSLError|Asked to scale to a nucleus' >> ${LOG} 2>&1
  gmkspl_status=$?

  tcomplete=`date "+%Y-%m-%d %H:%M:%S" `
  tcompletes=`date "+%s" `
  let ds=${tcompletes}-${tbegins}
  echo "complete gmkspl at ${tcomplete}; wall time ${ds} seconds"
  echo "complete gmkspl at ${tcomplete}; wall time ${ds} seconds" >> ${LOG}

  # NaN or inf in the XML file?? ... hack, hack
  nnan=`egrep -c -i 'nan|inf' ${XML} | cut -d':' -f2`
  if [ ${nnan} -gt 0 ]; then
    mv ${XML} ${XML}-NAN
    cat ${XML}-NAN | \
         sed -e 's/ [ -][nN][aA][nN] / 0.0 /g' \
             -e 's/ [ -][iI][nN][fF] / 0.0 /g' > ${XML}
    ${MYCP}   ${XML}-NAN $OUTPUTDIR/work-products/freenucs/${XML}-NAN
  fi

  ${MYCP} ${XML} $OUTPUTDIR/work-products/freenucs/${XML}
  ${MYCP} ${LOG} $OUTPUTDIR/work-products/freenucs/${LOG}

  sleep 5s

  if [ ${gmkspl_status} -ne 0 ]; then
    echo -e "${OUTRED}${b0}: generate_freenucpair failed ${OUTNOCOL}"
    cat ${LOG}
    exit ${gmkspl_status}
  fi

}
function combine_stage1()
{
  echo -e "${OUTBLUE}${b0}: combine_stage1 create ${FREENUCSUM}.xml ${OUTNOCOL}"
  XML=${FREENUCSUM}.xml
  LOG=${FREENUCSUM}.log
  if [ -f $LOG ]; then rm $LOG; fi

  echo " "         >> $LOG
  report_node_info >> $LOG
  report_setup     >> $LOG
  report_cfg       >> $LOG
  echo " "         >> $LOG
  echo "current stage $CURSTAGE (combine_stage1)" >> $LOG
  echo " "         >> $LOG

  # need a copy of *.xml
  FLIST=""
  for fth in `seq 1 $NFREENUCPAIRS`
  do
    set_fth_freenucpair $fth
    get_local_copy work-products/freenucs/${FREENUC1FBASE}.xml 0
    if [ -n "$FLIST" ]; then FLIST="${FLIST}," ; fi
    FLIST="${FLIST}./${FREENUC1FBASE}.xml"
  done

  echo time gspladd -f ${FLIST} -o ${XML}
  echo time gspladd -f ${FLIST} -o ${XML} >> ${LOG}
       time gspladd -f ${FLIST} -o ${XML} >> ${LOG} 2>&1
  gspladd_status=$?

  ${MYCP} ${XML} $OUTPUTDIR/work-products/${XML}
  ${MYCP} ${LOG} $OUTPUTDIR/work-products/${LOG}

  sleep 5s

  if [ ${gspladd_status} -ne 0 ]; then
    echo -e "${OUTRED}${b0}: combine_stage1 failed ${OUTNOCOL}"
    cat ${LOG}
    exit ${gspladd_status}
  fi

}
function generate_isotope()
{
  echo -e "${OUTBLUE}${b0}: generate_isotope ${OUTNOCOL}"
  set_ith_isotope ${CURINSTANCE1}
  ISOARGS="-t ${PDGI} -p ${PROBELISTFULL}"
  XML=${ISOFBASE}.xml
  LOG=${ISOFBASE}.log
  if [ -f $LOG ]; then rm $LOG; fi

  get_local_copy work-products/${FREENUCSUM}.xml 0
  ${MYCP} ${OUTPUTDIR}/work-products/${FREENUCSUM}.xml ./${FREENUCSUM}.xml
  INXSEC="--input-cross-sections ${FREENUCSUM}.xml"

  echo " "         >> $LOG
  report_node_info >> $LOG
  report_setup     >> $LOG
  report_cfg       >> $LOG
  echo " "         >> $LOG
  echo "current stage $CURSTAGE subprocess $CURINSTANCE" >> $LOG
  echo " "         >> $LOG

  # need a copy of *.xml

  tbegin=`date "+%Y-%m-%d %H:%M:%S" `
  tbegins=`date "+%s" `
  echo "begin gmkspl at ${tbegin} generate_isotope"
  echo "begin gmkspl at ${tbegin} generate_isotope" >> ${LOG}

  echo time gmkspl ${GMKSPLARGS} ${ISOARGS} ${INXSEC} -o ${XML}
  echo time gmkspl ${GMKSPLARGS} ${ISOARGS} ${INXSEC} -o ${XML} >> ${LOG}
       time gmkspl ${GMKSPLARGS} ${ISOARGS} ${INXSEC} -o ${XML} 2>&1 \
         | egrep -v 'GSLError|Asked to scale to a nucleus' >> ${LOG} 2>&1
  gmkspl_status=$?

  tcomplete=`date "+%Y-%m-%d %H:%M:%S" `
  tcompletes=`date "+%s" `
  let ds=${tcompletes}-${tbegins}
  echo "complete gmkspl at ${tcomplete}; wall time ${ds} seconds"
  echo "complete gmkspl at ${tcomplete}; wall time ${ds} seconds" >> ${LOG}

  # NaN or inf in the XML file?? ... hack, hack
  nnan=`egrep -c -i 'nan|inf' ${XML} | cut -d':' -f2`
  if [ ${nnan} -gt 0 ]; then
    mv ${XML} ${XML}-NAN
    cat ${XML}-NAN | \
         sed -e 's/ [ -][nN][aA][nN] / 0.0 /g' \
             -e 's/ [ -][iI][nN][fF] / 0.0 /g' > ${XML}
    ${MYCP}   ${XML}-NAN $OUTPUTDIR/work-products/isotopes/${XML}-NAN
  fi

  # push our work products back
  ${MYCP} ${XML} ${OUTPUTDIR}/work-products/isotopes/${XML}
  ${MYCP} ${LOG} ${OUTPUTDIR}/work-products/isotopes/${LOG}

  sleep 5s

  if [ ${gmkspl_status} -ne 0 ]; then
    echo -e "${OUTRED}${b0}: generate_isotope failed ${OUTNOCOL}"
    cat ${LOG}
    exit ${gmkspl_status}
  fi

}
function generate_isotope_split_nu()
{
  echo -e "${OUTBLUE}${b0}: generate_isotope_split_nu ${OUTNOCOL}"
  let ITHISOTOPE=(${CURINSTANCE}/${NPROBE})+1
  let PTHNU=(${CURINSTANCE}%${NPROBE})+1
#  set_ith_isotope ${CURINSTANCE1}
  set_ith_isotope ${ITHISOTOPE}
  set_pth_probe   ${PTHNU}
  ISOARGS="-t ${PDGI} -p ${PDGP}"
  XML=gxspl-${NAMEP}-${NAMEI}.xml
  LOG=gxspl-${NAMEP}-${NAMEI}.log
  # LOG=${ISOFBASE}.log
  if [ -f $LOG ]; then rm $LOG; fi

  get_local_copy work-products/${FREENUCSUM}.xml 0
  INXSEC="--input-cross-sections ${FREENUCSUM}.xml"

  echo " "         >> $LOG
  report_node_info >> $LOG
  report_setup     >> $LOG
  report_cfg       >> $LOG
  echo " "         >> $LOG
  echo "current stage $CURSTAGE subprocess $CURINSTANCE" >> $LOG
  echo " "         >> $LOG

  # need a copy of *.xml

  tbegin=`date "+%Y-%m-%d %H:%M:%S" `
  tbegins=`date "+%s" `
  echo "begin gmkspl at ${tbegin} generate_isotope_split_nu"
  echo "begin gmkspl at ${tbegin} generate_isotope_split_nu" >> ${LOG}

  echo time gmkspl ${GMKSPLARGS} ${ISOARGS} ${INXSEC} -o ${XML}
  echo time gmkspl ${GMKSPLARGS} ${ISOARGS} ${INXSEC} -o ${XML} >> ${LOG}
       time gmkspl ${GMKSPLARGS} ${ISOARGS} ${INXSEC} -o ${XML} >> ${LOG} 2>&1
  gmkspl_status=$?

  tcomplete=`date "+%Y-%m-%d %H:%M:%S" `
  tcompletes=`date "+%s" `
  let ds=${tcompletes}-${tbegins}
  echo "complete gmkspl at ${tcomplete}; wall time ${ds} seconds"
  echo "complete gmkspl at ${tcomplete}; wall time ${ds} seconds" >> ${LOG}

  ${MYCP} ${XML} $OUTPUTDIR/work-products/isotopes/${XML}
  ${MYCP} ${LOG} $OUTPUTDIR/work-products/isotopes/${LOG}

  sleep 5s

  if [ ${gmkspl_status} -ne 0 ]; then
    echo -e "${OUTRED}${b0}: generate_isotope_split_nu failed ${OUTNOCOL}"
    cat ${LOG}
    exit ${gmkspl_status}
  fi

}
function combine_stage3()
{
  echo PROBELISTFULL=${PROBELISTFULL}
  echo PROBELISTREDUCED=${PROBELISTREDUCED}
  echo ISOLISTFULL=${ISOLISTFULL}
  echo ISOLISTREDUCED=${ISOLISTREDUCED}
  echo ISOLISTTGRAPH=${ISOLISTTGRAPH}
#  return 1

  echo -e "${OUTBLUE}${b0}: combine_stage3 create ${FULLFNAME}.xml ${OUTNOCOL}"
  XML=${FULLFNAME}.xml
  LOG=${FULLFNAME}.log
  if [ -f $LOG ]; then rm $LOG; fi

  echo " "         >> $LOG
  report_node_info >> $LOG
  report_setup     >> $LOG
  report_cfg       >> $LOG
  echo " "         >> $LOG
  echo "current stage $CURSTAGE (combine_stage3)" >> $LOG
  echo " "         >> $LOG

  # need a local copy of *.xml
  FLIST=""
  MISSING=0
  if [ ${SPLITNUISOTOPES} -eq 0 ]; then
    for ith in `seq 1 $NISOTOPES`
    do
      set_ith_isotope $ith
      get_local_copy work-products/isotopes/${ISOFBASE}.xml 0
      if [ -n "$FLIST" ]; then FLIST="${FLIST}," ; fi
      FLIST="${FLIST}${ISOFBASE}.xml"
    done
  else
    HERE=`pwd`
    ISVARTMP=`echo ${HERE} | grep -c /var/tmp`
    for ith in `seq 1 $NISOTOPES`
    do
      set_ith_isotope $ith
      THISFNAMENUSUM=gxspl-${NAMEI}.xml
      if [ -n "$FLIST" ]; then FLIST="${FLIST}," ; fi
      # skip "./" as .gz makes arg char count 2179 (buffer 2048)
      FLIST="${FLIST}${THISFNAMENUSUM}.gz"   # note .gz
      FLISTISO=""
      for pth in `seq 1 $NPROBE`
      do
        set_pth_probe $pth
        THISFNAME=gxspl-${NAMEP}-${NAMEI}.xml
        if [ ${VERBOSE} -gt 0 ]; then echo ${THISFNAME} ; fi
        get_local_copy work-products/isotopes/${THISFNAME} ${SKIPSTAGE3CHECK}
        get_local_copy_status=$?
        if [ ${get_local_copy_status} -ne 0 ]; then
          if [ ${SKIPSTAGE3CHECK} -eq 1 ]; then
            echo -e "${OUTYELLOW}${b0}: create a fake ${THISFNAME}${OUTNOCOL}"
            # create a fake
            echo '<?xml version="1.0" encoding="ISO-8859-1"?>'         > ${THISFNAME}
            echo '<genie_xsec_spline_list version="3.00" uselog="1">' >> ${THISFNAME}
            echo "<genie_tune name=\"${TUNE}\">"                      >> ${THISFNAME}
            echo '</genie_tune>'                                      >> ${THISFNAME}
            echo '</genie_xsec_spline_list>'                          >> ${THISFNAME}
          fi
        fi
        # add "," if necessary
        if [ -n "$FLISTISO" ]; then FLISTISO="${FLISTISO}," ; fi
        # save char no "./"
        FLISTISO="${FLISTISO}${THISFNAME}"
      done

      # do partial sums over probes ...
      echo time gspladd -f ${FLISTISO} -o ${THISFNAMENUSUM}
      echo time gspladd -f ${FLISTISO} -o ${THISFNAMENUSUM} >> ${LOG}
           time gspladd -f ${FLISTISO} -o ${THISFNAMENUSUM} >> ${LOG} 2>&1
      gspladd_status=$?
      if [ ${gspladd_status} -ne 0 ]; then
        echo -e "${OUTRED}${b0}: combine_stage3 failed ${THISFNAMENUSUM}${OUTNOCOL}"
        #cat ${LOG}
        ## exit ${gspladd_status}
      else
        # clean up a bit to keep staging area size down
        FLISTISO1=`echo $FLISTISO | tr , " "`
        echo rm ${FLISTISO1}
             rm ${FLISTISO1}
        gzip -9 ${THISFNAMENUSUM}
      fi
    done
  fi
  if [ ${MISSING} -gt 0 ]; then
    echo -e "${OUTRED}missing ${MISSING} input files ... quit ${OUTNOCOL}"
    return 42
  fi

  # too long arg length ... still 2184 char if "./" .. [sigh]
  echo time gspladd -f ${FLIST} -o ${XML}
  echo time gspladd -f ${FLIST} -o ${XML} >> ${LOG}
       time gspladd -f ${FLIST} -o ${XML} >> ${LOG} 2>&1
  gspladd_status=$?

  ${MYCP} ${XML} $OUTPUTDIR/work-products/${XML}
  ${MYCP} ${LOG} $OUTPUTDIR/work-products/${LOG}

  if [ ${gspladd_status} -ne 0 ]; then
    echo -e "${OUTRED}${b0}: combine_stage3 failed ${OUTNOCOL}"
    cat ${LOG}
    exit ${gspladd_status}
  fi

  echo -e "${OUTBLUE}${b0}: combine_stage3 create ${REDUCEDFNAME}.xml ${OUTNOCOL}"
  XML=${REDUCEDFNAME}.xml
  LOG=${REDUCEDFNAME}.log
  if [ -f $LOG ]; then rm $LOG; fi

  # create reduction script at this point once it's all configured
  create_reduce_awk_script
  chmod +x reduce_gxspl.awk
  ${MYCP} reduce_gxspl.awk $OUTPUTDIR/work-products/reduce_gxspl.awk

  echo "time gawk -f reduce_gxspl.awk ${FULLFNAME}.xml > ${XML}"
  echo "time gawk -f reduce_gxspl.awk ${FULLFNAME}.xml > ${XML}" >> ${LOG}
        time gawk -f reduce_gxspl.awk ${FULLFNAME}.xml > ${XML}  2>> ${LOG}

  ${MYCP} ${XML} $OUTPUTDIR/work-products/${XML}
  ${MYCP} ${LOG} $OUTPUTDIR/work-products/${LOG}

  echo -e "${OUTBLUE}${b0}: combine_stage3 create root file ${GXSECTGRAPH} ${OUTNOCOL}"

  # gspl2root won't re-do entries that already exist, so just start fresh
  if [ -f ${GXSECTGRAPH} ]; then rm ${GXSECTGRAPH} ; fi
  LOG=${GXSECTGRAPH}.log

  export EMAXTGRAPH=125
  EMAXUSR=`echo ${EMAX} | cut -d. -f1`
  let EMAXUSR=${EMAXUSR}+1
  if [ ${EMAXUSR} -lt ${EMAXTGRAPH} ]; then EMAXTGRAPH=${EMAXUSR} ; fi

  export GSPL2ROOTARGS="--tune ${TUNE} -f ${XML} -p ${PROBELISTREDUCED} -t ${ISOLISTTGRAPH}"
  export GSPL2ROOTARGS="${GSPL2ROOTARGS} -e ${EMAXTGRAPH} -o ${GXSECTGRAPH}"
  if [ "${EVENTGENERATORLIST}" != "Default" ]; then
    export GSPL2ROOTARGS="${GSPL2ROOTARGS} --event-generator-list ${EVENTGENERATORLIST}"
  fi

  echo time gspl2root ${GSPL2ROOTARGS}
  echo time gspl2root ${GSPL2ROOTARGS} >> ${LOG}
       time gspl2root ${GSPL2ROOTARGS} >> ${LOG} 2>&1
  gspl2root_status=$?

  ${MYCP} ${GXSECTGRAPH} $OUTPUTDIR/work-products/${GXSECTGRAPH}
  ${MYCP} ${LOG} $OUTPUTDIR/work-products/${LOG}

  sleep 5s

  if [ ${gspl2root_status} -ne 0 ]; then
    echo -e "${OUTRED}${b0}: gspl2root failed ${OUTNOCOL}"
    cat ${LOG}
    exit ${gspl2root_status}
  fi

}

#############################################################################
function write_base_dag_file()
{
echo -e "${OUTBLUE}${b0}: write_base_dag_file ${OUTNOCOL}"

export DAG=genie_splines.dag
echo "# DAG for ${GXSPLVERSION} {$GXSPLQUALIFIER}" > $DAG
echo "# ${KNOTS} knots Enu [${EMIN}:${EMAX}] ${EVENTGENERATORLIST}" >> $DAG
echo "# ${NPROBE} probes on ${NISOTOPES} isotopes" >> $DAG
echo "# Split nu on isotopes = ${SPLITNUISOTOPES}" >> $DAG
echo "# default JOUBSUB_GROUP=${JOBSUB_GROUP_ARG}" >> $DAG
echo "#" >> $DAG

echo "<parallel>" >> $DAG
# --expected-lifetime 3h,8h  85200s(=23.666hr)
# -n is REQUIRED apparently (creates but doesn't submit job)
jsdcmd="  jobsub_submit -n -g --group ${JOBSUB_GROUP_ARG} "
jsdcmd="${jsdcmd} --OS=SL6 --resource-provides=usage_model=DEDICATED,OPPORTUNISTIC" # ,OFFSITE "
#jsdcmd="${jsdcmd} --resource-provides=usage_model=OFFSITE "
jsdcmd="${jsdcmd} --append_condor_requirements='(TARGET.HAS_CVMFS_dune_opensciencegrid_org==true)' "
bigmem=" --memory=4095MB "
shortt=" --expected-lifetime 3h"
mediumt=" --expected-lifetime 8h"
longt=" --expected-lifetime 85200s"
superlongt=" --expected-lifetime 170400s"  # ~2 days
basic=" file://${OUTPUTDIR}/bin/gen_genie_splines_v3.sh --top ${OUTPUTTOP} --version ${GXSPLVERSION} --qualifier ${GXSPLQUALIFIER}"


for fth in `seq 1 $NFREENUCPAIRS`; do
  let fth0=${fth}-1
  echo "  ${jsdcmd} ${longt} ${basic} --run-stage 1 --subprocess $fth0" >> $DAG
done
echo "</parallel>" >> $DAG

echo "<serial>" >> $DAG
echo "  ${jsdcmd} ${shortt} ${basic} --run-stage 2" >> $DAG
echo "</serial>" >> $DAG

echo "<parallel>" >> $DAG
NSTAGE3=${NISOTOPES}
if [ ${SPLITNUISOTOPES} -ne 0 ]; then
  let NSTAGE3=${NPROBE}*${NISOTOPES}
fi
for ith in `seq 1 $NSTAGE3`; do
  let ith0=${ith}-1
  echo "  ${jsdcmd} ${superlongt} ${basic} --run-stage 3 --subprocess $ith0" >> $DAG
done
echo "</parallel>" >> $DAG

echo "<serial>" >> $DAG
echo "  ${jsdcmd} ${bigmem} ${shortt} ${basic} --run-stage 4" >> $DAG
echo "  ${jsdcmd} ${bigmem} ${shortt} ${basic} --run-stage 5" >> $DAG
echo "</serial>" >> $DAG

cp ${DAG} $OUTPUTDIR/cfg/${DAG}
}
function make_cfg_tar()
{
echo -e "${OUTBLUE}${b0}: make_cfg_tar ${OUTNOCOL}"
HERE=`pwd`
cd ${OUTPUTDIR}/cfg
echo -e  "${OUTYELLOW} RWH --- HERE is set to ${HERE} ${OUTNOCOL}"
echo -e  "${OUTYELLOW} RWH --- pwd is  `pwd` ${OUTNOCOL}"
export GZIP="-9"
xmllist=`ls *.xml 2>/dev/null `
# pull in custom CMC directory if present
echo -e  "${OUTYELLOW} RWH --- FETCHTUNEFROM=${FETCHTUNEFROM} ${CUSTOMTUNE} ${INITTUNECMC} ${OUTNOCOL}"
if [ -d ${INITTUNECMC} ]; then
  echo -e  "${OUTYELLOW} RWH --- add INITTUNECMC ${OUTNOCOL}"
  xmllist="$xmllist ${INITTUNECMC}"
else
  echo -e  "${OUTYELLOW} RWH --- no INITTUNECMC ${INITTUNECMC} in `pwd` ${OUTNOCOL}"
fi
echo -e "${OUTYELLOW} RWH tar cfz ${HERE}/cfg.tar.gz *.sh *.cfg $xmllist ${OUTNOCOL}"
tar cfz ${HERE}/cfg.tar.gz *.sh *.cfg $xmllist
cd ${HERE}
cp cfg.tar.gz ${OUTPUTDIR}/cfg/cfg.tar.gz
}

##############################################################################
function create_ups()
{
echo -e "${OUTBLUE}${b0}: create_ups ${OUTNOCOL}"
export HERE=`pwd`
rm -rf ups_tmp
mkdir  ups_tmp
cd     ups_tmp

mkdir -p genie_xsec/${GXSPLVERSION}.version
export GXSPLVPATH=genie_xsec/${GXSPLVERSION}/NULL/${GXSPLQUALIFIERDASHES}
mkdir -p ${GXSPLVPATH}/ups
mkdir -p ${GXSPLVPATH}/data

for f in gxspl-freenuc.xml ${FULLFNAME}.xml ${REDUCEDFNAME}.xml \
         reduce_gxspl.awk xsec_graphs.root
do
  ${MYCP} ${OUTPUTDIR}/work-products/$f ${GXSPLVPATH}/data/$f
done
${MYCP} ${OUTPUTDIR}/cfg/isotopes.cfg  ${GXSPLVPATH}/data/isotopes.cfg

# this won't work on /pnfs ?? ...

# copy XMLs being used; should be already unpacked into working directory
for xml in ${_CONDOR_SCRATCH_DIR}/*.xml
do
  if [ "$xml" == "${_CONDOR_SCRATCH_DIR}/*.xml" ]; then break; fi  # no XML files
  xmlbase=`basename ${xml}`
  echo -e "${OUTBLUE}${b0}: copy config ${xml} ${OUTNOCOL}"
  ${MYCP} ${xml} ${GXSPLVPATH}/data/${xmlbase}
done
# copy directory if it matches CMC name
if [ -d "${_CONDOR_SCRATCH_DIR}/${TUNECMC}" ]; then
  cp -va ${_CONDOR_SCRATCH_DIR}/${TUNECMC} ${GXSPLVPATH}/data
fi

# this won't work on /pnfs ??
echo -e "${OUTBLUE}${b0}: create_ups compress gxspl-freenuc.xml ${OUTNOCOL}"
gzip -9 ${GXSPLVPATH}/data/gxspl-freenuc.xml

echo -e "${OUTBLUE}${b0}: create_ups compress ${FULLFNAME}.xml ${OUTNOCOL}"
gzip -9 ${GXSPLVPATH}/data/${FULLFNAME}.xml
HEREUPS=`pwd`
cd ${GXSPLVPATH}/data
   # make symlinks to old names
   ln -s ${FULLFNAME}.xml.gz gxspl-FNALbig.xml.gz
   ln -s ${REDUCEDFNAME}.xml gxspl-FNALsmall.xml
cd ${HEREUPS}

tableFile=${GXSPLVPATH}/ups/genie_xsec.table
versionFile=genie_xsec/${GXSPLVERSION}.version/NULL_${GXSPLQUALIFIERDASHES}

#
# create the table file
#
cat > ${tableFile} <<EOF
File=Table
Product=genie_xsec
#*************************************************
# Starting Group definition

Group:

Flavor=NULL
Qualifiers="${GXSPLQUALIFIER}"

Common:
   Action=setup
      proddir()
      setupenv()
      envSet(GENIEXSECPATH, \${UPS_PROD_DIR}/data)
      # GSPLOAD should find it in GXMLPATH for newer versions of GENIE
      # but specify full path just in case
      envSet(GENIEXSECFILE, \${UPS_PROD_DIR}/data/${REDUCEDFNAME}.xml)
      pathPrepend(GXMLPATH, \${UPS_PROD_DIR}/data)
      envSet(GENIE_XSEC_TUNE,"${TUNE}")
      envSet(GENIE_XSEC_GENLIST,"${EVENTGENERATORLIST}")
      envSet(GENIE_XSEC_KNOTS,"${KNOTS}")
      envSet(GENIE_XSEC_EMAX,"${EMAX}")

End:
# End Group definition
#*************************************************
EOF


#
# create the version file
#
cat > ${versionFile} <<EOF
FILE = version
PRODUCT = genie_xsec
VERSION = ${GXSPLVERSION}

#*************************************************
EOF

iam=`whoami`
if [ "$iam" == "nusoft" ]; then
  altiam=`klist | grep "Default principal" | cut -d':' -f2 | cut -d'@' -f1 | tr -d ' ' `
  if [ -n "$altiam" ]; then
    iam=${altiam}
    echo "i am \"${iam}\""
  fi
fi
nowGMT=`date -u "+%Y-%m-%d %H:%M:%S"`

nf=`grep QUALIFIERS ${versionFile} | grep -c \"${GXSPLQUALIFIER}\"`
if [ $nf -ne 0 ]; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "${versionFile} already has an entry for \"${GXSPLQUALIFIER}\""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
else
#
# add this version to the version file
#
cat >> ${versionFile} <<EOF
#
FLAVOR = NULL
QUALIFIERS   = "${GXSPLQUALIFIER}"
  DECLARER   = ${iam}
  DECLARED   = ${nowGMT} GMT
  MODIFIER   = ${iam}
  MODIFIED   = ${nowGMT} GMT
  PROD_DIR   = genie_xsec/${GXSPLVERSION}/NULL/${GXSPLQUALIFIERDASHES}
  UPS_DIR    = ups
  TABLE_FILE = genie_xsec.table
#
#*************************************************
EOF
fi

#
# create the README file
#
export README=${GXSPLVPATH}/data/README
echo `pwd`
echo "README=${README}"

cat > ${README} <<EOF
GENIE XML Cross Section Spline files for
   version ${GXSPLVERSION} qualifier ${GXSPLQUALIFIER}
   using the "${TUNE}" tune, and "${EVENTGENERATORLIST}" TuneGeneratorList
   neutrino energies ${EMIN} GeV to ${EMAX} GeV, with ${NPROBE} nu flavors
   ${KNOTS} knots, spaced logarithmically

Files:

  README                - this file

  gxspl-freenuc.xml.gz         - splines for all nu flavors on {proton,neutron}
  ${FULLFNAME}.xml.gz    -   + very large set of isotopes
  ${REDUCEDFNAME}.xml    -   + reduced set of isotopes

  xsec_graphs.root  - TGraph evaluations of some splines

  reduce_gxspl.awk      - script for creating XML spline files with
                          particular nu flavors and target isotopes removed

Creating new spline files from the "big" file:

 * edit the reduce_gxspl.awk file to change the list of flavor/isotopes
 * run the command:

     nohup zcat ${FULLFNAME}.xml 2>/dev/null | \\
      gawk -f reduce_gxspl.awk > gxspl-ALTsmall.xml 2>/dev/null &


${FULLFNAME}.xml contains cross sections on the following neutrino flavors:
EOF
for pth in `seq 1 ${NPROBE}`; do
  set_pth_probe $pth
  printf "   %3d  %-10s\n" $PDGP "$NAMEP"  >> ${README}
done
cat >> ${README} <<EOF

and ${NISOTOPES} isotopes:
EOF

NAMEILAST=""
for NAMEI in `echo $ISONAMESFULL | tr ',' ' ' ` ; do
  NAMEIBASE=`echo $NAMEI | tr -d [0-9]`
  if [ "${NAMEIBASE}" == "${NAMEILAST}" ]; then
    printf "  %-5s" ${NAMEI}  >> ${README}
  else
    echo ""                   >> ${README}
    printf "   %-5s" ${NAMEI} >> ${README}
  fi
  NAMEILAST=${NAMEIBASE}
done
echo ""               >> ${README}
echo ""               >> ${README}

cat >> ${README} <<EOF

${REDUCEDFNAME}.xml contains:
EOF
NTMP="`echo $PROBELISTREDUCED | tr , ' '`"
echo "neutrino flavors: ${NTMP}" >> ${README}
echo "and a more limited list of ${NISOTOPESREDUCED} isotopes: " >> ${README}
NAMEILAST=""
for NAMEI in `echo $ISONAMESREDUCED | tr ',' ' ' ` ; do
  NAMEIBASE=`echo $NAMEI | tr -d [0-9]`
  if [ "${NAMEIBASE}" == "${NAMEILAST}" ]; then
    printf "  %-5s" ${NAMEI}  >> ${README}
  else
    echo ""                   >> ${README}
    printf "   %-5s" ${NAMEI} >> ${README}
  fi
  NAMEILAST=${NAMEIBASE}
done
echo ""               >> ${README}
echo ""               >> ${README}

#  tar cvjf genie_xsec-2.9.0-noarch-default.tar.bz2 genie_xsec/v2_9_0 genie_xsec/v2_9_0.version
echo -e "${OUTBLUE}${b0}: create_ups start making ${UPSTARFILE} ${OUTNOCOL}"
echo -e "${OUTYELLOW}tar -cvjf ${UPSTARFILE} genie_xsec/${GXSPLVERSION} genie_xsec/${GXSPLVERSION}.version ${OUTNOCOL}"
tar -cvjf ${UPSTARFILE} genie_xsec/${GXSPLVERSION} genie_xsec/${GXSPLVERSION}.version

${MYCP} ${UPSTARFILE} ${OUTPUTDIR}/ups/${UPSTARFILE}
echo -e "${OUTBLUE}${b0}: create_ups complete ${OUTNOCOL}"

  sleep 5s
}
##############################################################################
export OUTPUTTOP=""
export GXSPLVERSION=""
export GXSPLQUALIFIER=""
export OUTPUTDIR=""
export OPTARGS=""

export DOINIT=0
export DOFINALIZECFG=0
export DOLAUNCHDAG=0
export DOSTATUS=0

export CURSTAGE=0
export CURINSTANCE=0
export REWRITE=0
export VERBOSE=0
export DOTRACE=0

export OUTREADABLE=1

# running under condor with -N <N> ... $PROCESS [0...<N-1>]
if [ -n "$PROCESS" ]; then CURINSTANCE=$PROCESS ; fi

# functions in bash can't easily pass in/out bash style arrays
# so instead use a single variable with ":" separated values as the
# exchange medium
export PROBELISTFULL=""
export PROBELISTREDUCED=""

export KNOTS="unset"

export SPLITNUISOTOPES=0  # do all nu flavors together in isotopes
# some values for initialization stage
export INITKNOTS="500"
export INITEMAX="400"
export INITTUNE=""
export INITGENLIST="Default"
export INITDOELECTRON=0
export CUSTOMTUNE=0
export FETCHTUNEFROM=""

export  INITSETUPSTR="ups:genie%v3_XX%e17:r6:prof:rhatcher"
#export INITGENIEV="v2_8_6b"
#export INITGENIEQ="debug:e7"
#export INITUPS=""
## guess a default ups installation
#thisnode=`uname -n | cut -d. -f1`
#case "$thisnode" in
#  *nova*                           ) INITUPS="nova" ;;
#  *genie*                          ) INITUPS="genie" ;;
#  *lar* | *dune* | lbne* | uboone* ) INITUPS="larsoft" ;;
#  *mac-124096*                     ) INITUPS="rhatcher" ;;
#esac

export SKIPSTAGE3CHECK=0
export CLEAN_FAKE=1

##############################################################################
process_args() {

  PRINTUSAGE=0

  DOTRACE=`echo "$@" | grep -c -- --trace`
  ISDEBUG=`echo "$@" | grep -c -- --debug`
  if [ $DOTRACE -gt 0 ]; then set -o xtrace ; fi
  if [ $ISDEBUG -gt 0 ]; then VERBOSE=999 ; fi
  if [ $ISDEBUG -gt 0 ]; then echo "pre-getopt  \$# $#  \$@ \"$@\"" ; fi

  # longarg "::" means optional arg, if not supplied given as null string
  # use this for targfile lowth peanut
  TEMP=`getopt -n $0 -s bash -a \
     --longoptions="help verbose top: version: qualifier: setup: init rewrite split-nu-isotopes \
     knots: emax: tune: genlist: electron fetch-tune-from: run-stage: subprocess: instance: status finalize-cfg:: \
     launch-dag:: skip-stage3-check keep-scratch morehelp debug trace" \
     -o hvT:V:Q:ir:s:-: -- "$@" `
# remove "ups genie-v: genie-q:", replace w/ "setup:"
  eval set -- "${TEMP}"
  if [ $ISDEBUG -gt 0 ]; then echo "post-getopt \$# $#  \$@ \"$@\"" ; fi
  unset TEMP

  let iarg=0
  while [ $# -gt 0 ]; do
    let iarg=${iarg}+1
    if [ $VERBOSE -gt 0 ]; then
      printf "arg[%2d] processing \$1=\"%s\" (\$2=\"%s\")\n" "$iarg" "$1" "$2"
    fi
    case "$1" in
      "--"                ) shift;                      break  ;;
      -h | --help         ) PRINTUSAGE=1                       ;;
           --morehelp     ) PRINTUSAGE=2                       ;;
      -v | --verbose      ) let VERBOSE=${VERBOSE}+1           ;;
      -T | --top          ) export OUTPUTTOP="$2";      shift  ;;
      -V | --vers*        ) export GXSPLVERSION="$2";   shift  ;;
      -Q | --qual*        ) export GXSPLQUALIFIER="$2"; shift  ;;
      -i | --init         ) export DOINIT=1                    ;;
           --rewrite      ) export REWRITE=1                   ;;
           --setup        ) export INITSETUPSTR="$2";   shift  ;;
#           --ups          ) export INITUPS="$2";        shift  ;;
#           --genie-v*     ) export INITGENIEV="$2";     shift  ;;
#           --genie-q*     ) export INITGENIEQ="$2";     shift  ;;
           --split-nu-isotopes ) export SPLITNUISOTOPES=1      ;;
           --knots        ) export INITKNOTS="$2";      shift  ;;
           --emax         ) export INITEMAX="$2";       shift  ;;
           --tune         ) export INITTUNE="$2";       shift  ;;
           --genlist      ) export INITGENLIST="$2";    shift  ;;
           --electron     ) export INITDOELECTRON=1;    ;;
           --fetch-tune-from ) export FETCHTUNEFROM="$2"; shift ;;
           --finalize-cfg ) export DOFINALIZECFG=1
                            # optional arg :: (blank if not given)
                            JSG_ARG1="$2";              shift  ;;
           --launch-dag   ) export DOLAUNCHDAG=1
                            # optional arg :: (blank if not given)
                            JSG_ARG2="$2";              shift  ;;
           --status       ) export DOSTATUS=1                  ;;
      -r | --run-stage    ) export CURSTAGE="$2";       shift  ;;
      -s | --subprocess   ) export CURINSTANCE="$2";    shift  ;;
           --instance     ) export CURINSTANCE="$2";    shift  ;;
           --skip-stage3-check ) export SKIPSTAGE3CHECK=1      ;;
           --keep-scratch ) export CLEAN_FAKE=0                ;;
           --debug        ) export VERBOSE=999                 ;;
           --trace        ) export DOTRACE=1                   ;;
      -*                  ) echo "unknown flag $opt ($1)"
                            usage
                            ;;
     esac
     shift  # eat up the arg we just used
  done
  usage_exit=0

  INITTUNECMC=`echo ${INITTUNE} | cut -d_ -f1-2`
  # custom tune
  if [ -n "${FETCHTUNEFROM}" ]; then
    CUSTOMTUNE=1
    if [ ! -d "${FETCHTUNEFROM}/${INITTUNECMC}" ]; then
      # did user include tune name with path?
      FETCHTUNEFROMBASE=`basename ${FETCHTUNEFROM}`
      FETCHTUNEFROMDIR=`dirname ${FETCHTUNEFROM}`
      if [ "${FETCHTUNEFROMBASE}" == "${INITTUNECMC}" ]; then
        FETCHTUNEFROM="${FETCHTUNEFROMDIR}"
      fi
    fi
  fi
  echo -e  "${OUTYELLOW} RWH --- FETCHTUNEFROM=${FETCHTUNEFROM} ${CUSTOMTUNE} ${OUTNOCOL}"

  # convert spaces to underscore in version/qualifier
  export GXSPLVERSION=`echo ${GXSPLVERSION}     | tr ' ' '_' `
  if [ ${INITDOELECTRON} -eq 1 ]; then
     export GXSPLQUALIFIER="${GXSPLQUALIFIER}:electron"
  fi
  export GXSPLQUALIFIER=`echo ${GXSPLQUALIFIER} | tr ' ' '_' `
  export GXSPLQUALIFIERDASHES=`echo ${GXSPLQUALIFIER} | tr ':' '-' `
  # must have OUTPUTTOP, GXSPLVERSION, GXSKPLQUALIFIER set
  # but don't check if user asked for --help or --morehelp ...
  if [ ${PRINTUSAGE} == 0 ]; then
  if [[ -z "${OUTPUTTOP}" || -z "${GXSPLVERSION}" || -z "${GXSPLQUALIFIER}" ]]
  then
    echo -e "${OUTRED}You must supply values for:${OUTNOCOL}"
    echo -e "${OUTRED}   --top       ${OUTNOCOL}[${OUTGREEN}${OUTPUTTOP}${OUTNOCOL}]"
    echo -e "${OUTRED}   --version   ${OUTNOCOL}[${OUTGREEN}${GXSPLVERSION}${OUTNOCOL}]"
    echo -e "${OUTRED}   --qualifier ${OUTNOCOL}[${OUTGREEN}${GXSPLQUALIFIER}${OUTNOCOL}]"
    usage_exit=42
  fi
  fi

  export OUTPUTDIR=${OUTPUTTOP}/GXSPLINES-${GXSPLVERSION}-${GXSPLQUALIFIERDASHES}
  export MYUPSDATADIR=${OUTPUTDIR}/genie/genie_xsec/${GXSPLVERSION}/NULL/${GXSPLQUALIFIERDASHES}/data
  # for 1-based indexing ...
  let CURINSTANCE1=${CURINSTANCE}+1
  export CURINSTANCE1

  if [ ${DOFINALIZECFG} -gt 0 -o ${DOLAUNCHDAG} -gt 0 ]; then
    # need user to have given arg, or fetch value from environment
    # or finally, if possible, from dag file
    if [ -n "$JSG_ARG1" -a -n "$JSG_ARG2" ]; then
      if [ "$JSG_ARG1" != "$JSG_ARG2" ]; then
        echo -e "${OUTRED}${b0}: JOBSUB_GROUP set inconsistently"
        echo -e "      ${JSG_ARG1} from --finalize-cfg"
        echo -e "      ${JSG_ARG2} from --launch-dag"
        echo -e "sort it out ... ${OUTNOCOL}"
        exit 42
      fi
    fi
    export JOBSUB_GROUP_ARG=${JSG_ARG1}
    JSGSRC=finalize-cfg
    if [ -z "${JOBSUB_GROUP_ARG}" ]; then
      export JOBSUB_GROUP_ARG=${JSG_ARG2}
      JSGSRC=launch-dag
    fi
    if [ -z "${JOBSUB_GROUP_ARG}" ]; then
      export JOBSUB_GROUP_ARG=${JOBSUB_GROUP}  # env
      JSGSRC=env_jobsub_group
    fi
    if [ -z "${JOBSUB_GROUP_ARG}" ]; then
      export JOBSUB_GROUP_ARG=${GROUP}  # env
      JSGSRC=env_group
    fi
    if [ -z "${JOBSUB_GROUP_ARG}" ]; then
      if [ -f ${OUTPUTDIR}/cfg/genie_splines.dag ]; then
        # should have one locally from unpacked cfg.tar.gz
        export JOBSUB_GROUP_ARG=`grep "default JOBSUB_GROUP" genie_splines.dag | cut -d= -f2`
        JSGSRC=dag
      fi
    fi
    if [ -z "${JOBSUB_GROUP_ARG}" ]; then
      echo -e "${OUTRED}${b0}: --finalize-cfg needs "
      echo -e "  \${JOBSUB_GROUP} specified or from the environment ${OUTNOCOL}"
       exit 42
    elif [ ${VERBOSE} -gt 0 ]; then
      echo -e "${OUTGREEN}${b0}: JOBSUB_GROUP_ARG=${JOBSUB_GROUP_ARG} from ${JSGSRC} ${OUTNOCOL}"
    fi
  fi

  # show the defaults correctly now
  if [ $PRINTUSAGE -gt 0 -o ${usage_exit} -ne 0 ]; then
    echo " "
    usage
    if [ $PRINTUSAGE -gt 1 ]; then
      extended_help
    fi
    exit ${usage_exit}
  fi

  # any left over non-flag args (i.e. --init xml files to copy)
  export OPTARGS="$@"
  if [ ${VERBOSE} -gt 2 ]; then
    echo "OPTARGS=${OPTARGS}"
  fi
}
##############################################################################
##############################################################################

process_args "$@"

# make sure we're in a scratch area
# needed during init so we can write locally before copying to output area
# in case output area is /pnfs  (can't append to files in PNFS)
export ORIGINALDIR=`pwd`
if [ -n "${_CONDOR_SCRATCH_DIR}" ]; then
  export FAKESCRATCH=0
  # actually on condor worker node ... sometimes dag jobs start too fast
  # and don't see ouptut of previous stage yet
  # 60 seconds didn't seem to be sufficient ...
  if [ ${CURSTAGE} -gt 1 ]; then sleep 120 ; fi
else
##  _CONDOR_SCRATCH_DIR=/var/tmp/fake_CONDOR_SCRATCH_DIR_$$
## to likely to overwhelm ...
  case `uname -n` in
    *nova* )
       _CONDOR_SCRATCH_DIR=/nova/ana/users/${USER}/fake_CONDOR_SCRATCH_DIR_$$
       ;;
    *genie* )
        # there is no /genie/data or /genie/ana
        # but we don't want to use PNFS
       _CONDOR_SCRATCH_DIR=/genie/app/users/${USER}/fake_CONDOR_SCRATCH_DIR_$$
       ;;
  esac
  export FAKESCRATCH=1
  echo -e "${OUTCYAN}${b0}: fake a \${_CONDOR_SCRATCH_DIR} as ${_CONDOR_SCRATCH_DIR} ${OUTNOCOL}"
  if [ ! -d ${_CONDOR_SCRATCH_DIR} ]; then
    mkdir -p ${_CONDOR_SCRATCH_DIR}
  fi
fi
if [ ! -d ${_CONDOR_SCRATCH_DIR} ]; then
  echo -e "${OUTLTRED}no directory ${_CONDOR_SCRATCH_DIR}${OUTNOCOL}"
  exit 42
fi
cd ${_CONDOR_SCRATCH_DIR}

echo -e "${OUTPURPLE}${b0}: pwd=`pwd` ${OUTNOCOL}"

let PRERUN123=${DOINIT}+${DOFINALIZECFG}+${DOLAUNCHDAG}
let PRERUN23=${DOFINALIZECFG}+${DOLAUNCHDAG}

if [ $DOINIT -ne -0 ]; then
  echo -e "${b0}:${OUTBLUE} --init  rewrite=${REWRITE} ${OUTNOCOL}"
  init_output_area $OPTARGS
fi

echo -e "${OUTBLUE}${b0}:CURSTAGE ${CURSTAGE} DOSTATUS ${DOSTATUS}${OUTNOCOL}"
if [ ${PRERUN23} -eq 0 -a ${CURSTAGE} -eq 0 -a ${DOSTATUS} -eq 0 ]; then
  # nothing more to do
  exit 0
else

  if [ ${DOFINALIZECFG} -ne 0 ]; then
    echo -e "${OUTBLUE}${b0}: --finalize-cfg make_cfg_tar ${OUTNOCOL}"
    # can't do this in output area if it is /pfns because no append
    make_cfg_tar
  fi

  # cfg.tar.gz should have scripts + *.xml files
###  cp ${OUTPUTDIR}/cfg/cfg.tar.gz cfg.tar.gz
###### can't ^ because PNFS not readable on grid
###  ${MYCP} ${OUTPUTDIR}/cfg/cfg.tar.gz cfg.tar.gz
###### can't ^ because ifdh has not been setup (cf. the setup )
  echo "----- chicken & egg copy of cfg.tar.gz"
  if [ -f ${OUTPUTDIR}/cfg/cfg.tar.gz ]; then
    echo -e "${OUTRED}${b0}: cp ${OUTPUTDIR}/cfg/cfg.tar.gz cfg.tar.gz ${OUTNOCOL}"
    cp ${OUTPUTDIR}/cfg/cfg.tar.gz cfg.tar.gz
  else
    echo -e "${OUTRED}${b0}: setup common ifdhc"
    source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
    setup ifdhc ${IFDHC_VERSION}
    if [ -n "${IFDHC_CONFIG_VERSION}" ]; then
      echo "explicitly setting up ifdhc_config ${IFDHC_CONFIG_VERSION}"
      setup ifdhc_config ${IFDHC_CONFIG_VERSION}
    fi
    export IFDH_CP_MAXRETRIES=2 # because 7 is way too many attepts
    which ifdh
    echo -e "${OUTRED}${b0}: ifdh cp ${OUTPUTDIR}/cfg/cfg.tar.gz cfg.tar.gz ${OUTNOCOL}"
    ifdh cp ${OUTPUTDIR}/cfg/cfg.tar.gz cfg.tar.gz
  fi
  if [ ! -f cfg.tar.gz ]; then
    echo -e "${OUTRED}${b0}: no cfg.tar.gz ${OUTNOCOL}"
    exit 42
  fi
  tar xf cfg.tar.gz

  echo " "
  missing=""
  for reqfile in isotopes.cfg setup_genie.sh define_cfg.sh
  do
    if [ ! -f ${reqfile} ]; then
      missing="${missing} ${reqfile}"
    fi
  done
  if [ -n "$missing" ]; then
    echo -e "${OUTBLUE}${b0}: missing ${missing} from ${OUTDIR}/cfg/cfg.tar.gz"
    exit 42
  fi

  if [ ${VERBOSE} -gt 1 ]; then echo "...source ./setup_genie.sh" ; fi
  source ./setup_genie.sh
  if [ ${VERBOSE} -gt 1 ]; then echo "....done setup_genie.sh" ; fi

  source ./define_cfg.sh
  define_cfg

  if [ ${DOFINALIZECFG} -ne 0 ]; then
    # new conventions QUALIFIER = {tunex}:k{knots}:e{emax}
    QTUNEX=`echo ${GXSPLQUALIFIER} | cut -d':' -f1 | tr -d "_"`
    QKNOTS=`echo ${GXSPLQUALIFIER} | cut -d':' -f2 | tr -d "k"`
    QEMAXX=`echo ${GXSPLQUALIFIER} | cut -d':' -f3 | tr -d "e"`
    okay="true"
    TUNEX=`echo ${TUNE} | tr -d "_"`
    EMAXX=`echo ${EMAX} | tr '.' 'p' | sed -e 's/p0*$//g'`
    if [ "${TUNEX}" != "${QTUNEX}" ]; then okay="false"; fi
    if [ "${KNOTS}" != "${QKNOTS}" ]; then okay="false"; fi
    if [ "${EMAXX}" != "${QEMAXX}" ]; then okay="false"; fi
    if [ "${okay}"  != "true" ]; then
      echo -e "${OUTBLUE}${b0}: --finalize-cfg ${OUTRED}mismatch${OUTNOCOL}"
      echo -e "  ${OUTORANGE}TUNE ${TUNE} TUNEX ${TUNEX} qualifier ${QTUNEX} ${OUTNOCOL}"
      echo -e "  ${OUTORANGE}KNOTS ${KNOTS} qualifier ${QKNOTS} ${OUTNOCOL}"
      echo -e "  ${OUTORANGE}EMAX  ${EMAX}  qualifier ${QEMAX} ${OUTNOCOL}"
      exit 42
    fi

    echo -e "${OUTBLUE}${b0}: --finalize-cfg write_base_dag_file ${OUTNOCOL}"
    # can't do this in output area if it is /pfns because no append
    write_base_dag_file

  fi

  echo " "
  report_node_info
  report_setup
  report_cfg

  if [ ${DOLAUNCHDAG} -ne 0 ]; then
    echo ""
    echo -e "${OUTBLUE}${b0}: --launch-dag ${OUTNOCOL}"
    setup jobsub_client
    echo -e "${OUTBLUE}${b0}: creating genie_splines.${JOBSUB_GROUP_ARG}.dag ${OUTNOCOL}"
    sed -e "s/group JOBSUB_GROUP/group ${JOBSUB_GROUP_ARG}/g" ${OUTPUTDIR}/cfg/genie_splines.dag  > genie_splines.${JOBSUB_GROUP_ARG}.dag
    if [ ${VERBOSE} -gt 2 ]; then
       echo -e "${OUTBLUE}${b0}: genie_splines.${JOBSUB_GROUP_ARG}.dag ${OUTNOCOL}"
      cat genie_splines.${JOBSUB_GROUP_ARG}.dag
    fi
    # --generate-email-summary doesn't seem to be an option
    JSDAGCMD="jobsub_submit_dag --group ${JOBSUB_GROUP_ARG} file://`pwd`/genie_splines.${JOBSUB_GROUP_ARG}.dag"
    echo -e "${OUTPURPLE} ${JSDAGCMD} ${OUTNOCOL}"
    NOWTXT=`date "+%Y%m%d_%H%M%S"`
    JSLOG=${ORIGINALDIR}/jobsub_submit_dag-${NOWTXT}.log
    echo "${JSDAGCMD}" > $JSLOG
    cat genie_splines.${JOBSUB_GROUP_ARG}.dag >> $JSLOG
    ${JSDAGCMD} >> $JSLOG
    echo -e "${OUTPURPLE} jobsub_submit_dag log ${JSLOG} ${OUTNOCOL}"
    echo -e "${OUTLTRED}"
    grep "Error authenticating" $JSLOG
    grep "Use job id" $JSLOG
    echo -e "${OUTNOCOL}"
  fi

  if [ ${DOSTATUS} -ne 0 ]; then
    echo -e "${OUTBLUE}${b0}: checking status ${OUTNOCOL}"
    print_status
  fi
  echo " "

  if [ ${CURSTAGE} -gt 0 ]; then
    echo -e "${OUTBLUE}${b0}: start of processing stage $CURSTAGE subprocess $CURINSTANCE ${OUTNOCOL}"

    export GMKSPLARGS="-e ${EMAX} -n ${KNOTS} --tune ${TUNE}"
    if [ "${EVENTGENERATORLIST}" != "Default" ]; then
      GMKSPLARGS="${GMKSPLARGS} --event-generator-list ${EVENTGENERATORLIST}"
    fi

    #export GXMLPATH="`pwd`:$GXMLPATH:."
    export GXMLPATH=".:$GXMLPATH:."
    unset GSPLINE_DIR
    unset GSPLOAD

    case $CURSTAGE in
      1 ) generate_freenucpair ;;
      2 ) combine_stage1       ;;
      3 ) if [ ${SPLITNUISOTOPES} -eq 0 ]; then
            generate_isotope
          else
            generate_isotope_split_nu
          fi ;;
      4 ) combine_stage3       ;;
      5 ) create_ups           ;;
      * ) echo -e "${OUTRED}${b0}: no stage ${CURSTAGE} ${OUTNOCOL}"
          ;;
    esac

    # if stage != 0 ... put sleep in ... just to let things "finish"?
    sleep 20s

  fi # CURSTAGE -gt 0

  # clean-up
  if [ ${FAKESCRATCH} -eq 1 ]; then
    if [ ${CLEAN_FAKE} -ne 0 ]; then
      echo -e "${OUTBLUE}${b0}: rm -r ${_CONDOR_SCRATCH_DIR} ${OUTNOCOL}"
      rm -r ${_CONDOR_SCRATCH_DIR}
    else
      echo -e "${OUTBLUE}${b0}: asked not to remove ${_CONDOR_SCRATCH_DIR} ${OUTNOCOL}"
    fi
  fi
fi
echo -e "${OUTBLUE}${b0}: end-of-script${OUTNOCOL}"

# end-of-script gen_genie_splines_v3.sh
