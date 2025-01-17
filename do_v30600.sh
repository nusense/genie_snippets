#! /usr/bin/env bash

# ./do_v30600.sh <action> [ <tunelist> ]
#     action:  init launch stage2 stage4 stage5 status

#export EXTRAFLG="--skip-stage3-check"
#export EXTRAQUAL=":partial"

# ACTION is one of:  init launch-dag status


export ACTION="status"
if [ -n "$1" ]; then ACTION="$1" ; fi

export TUNELIST=" \
              XN24_20i_02_11b \
              XAR23_20i_00_000 \
              XG18_02a_00_000 \
"
export OTHERTUNES=" \
              XG00_00a_00_000 \
              XG00_00b_00_000 \
 \
              XG18_01a_00_000 \
              XG18_01a_02_11a \
              XG18_01b_00_000 \
              XG18_01b_02_11a \
 \
              XG18_02a_02_11a \
              XG18_02a_02_11b \
              XG18_02b_00_000 \
              XG18_02b_02_11a \
 \
              XG18_10a_00_000 \
              XG18_10a_02_11a \
              XG18_10a_02_11b \
              XG18_10b_00_000 \
              XG18_10b_02_11a \
 \
              XG18_10i_00_000 \
              XG18_10j_00_000 \
 \
              XG21_11a_00_000 \
"

echo TUNELIST=$TUNELIST

export JOBSUB_GROUP=nova # nova dune  # need to try "genie" role=production
export SEP="============================================================="

export KNOTS=250
export EMAX="1000.0"   # was 400.0

# KNOTS=25
# EMAX=10.0

GENLIST="Default"

export GVERS=v3_06_00
export GXVER=v3_06_00
export GQUAL="e26:prof"

export LOGBASE=v30600

echo "version:  $GXVER $GVERS $GQUAL"

TOPGEN=/pnfs/nova/scratch/users/rhatcher/gen_genie_splines_v3

function now ()
{
    date "+%Y-%m-%d %H:%M:%S"
}
function bootstrap_genie ()
{
    export GPRD=/grid/fermiapp/products/genie;
    export ALTUPS="";
    case "$1" in
        cv*)
            export GPRD=/cvmfs/fermilab.opensciencegrid.org/products/genie
        ;;
        alt*)
            export ALTUPS=/genie/app/rhatcher/altups
        ;;
    esac;
    source ${GPRD}/bootstrap_genie_ups.sh;
    if [ -n "$ALTUPS" ]; then
        echo -e "${OUTGREEN}adding ${ALTUPS} to \${PRODUCTS}${OUTNOCOL}";
        export PRODUCTS=${PRODUCTS}:${ALTUPS};
    fi
}

#al9# bootstrap_genie cvmfs
#al9# setup jobsub_client
alias myjobs="jobsub_q --user $USER"

export UPSV="ups:genie+trycvmfs%${GVERS}%${GQUAL}"

#cd /genie/app/rhatcher/GXSPLINE
cd /exp/nova/app/users/rhatcher/GXSPLINE

export TUNE
EMAXX=`echo ${EMAX} | tr '.' 'p' | sed -e 's/p0*$//g'`

for TUNE in ${TUNELIST} ; do
  C1=`echo $TUNE | cut -c1`
  if [ "$C1" == "X" -o "$C1" == "x" ]; then
    echo " "
    echo -e "${OUTORANGE}skip ${TUNE}${OUTNOCOL}"
    continue
  fi
  echo " "
  echo -e "${OUTGREEN}start ${ACTION} on ${TUNE}${OUTNOCOL}"

  export LOGFILE=do_${LOGBASE}_${TUNE}.log
  TUNEX=`echo ${TUNE} | tr -d "_" `
  GENQUAL=${TUNEX}:k${KNOTS}:e${EMAXX}
  if [ "${GENLIST}" != "Default" ]; then
    GENQUAL="${GENQUAL}:${GENLIST}"
  fi

  GENCMD="./gen_genie_splines_v3.sh ${EXTRAFLG} \
     --top ${TOPGEN} --version ${GXVER} \
     --qualifier "${GENQUAL}${EXTRAQUAL}" \
     --tune "${TUNE}" --genlist "${GENLIST}"  \
     --setup "$UPSV" --knots $KNOTS --emax $EMAX "
  export INITFIN="--split-nu-isotopes --init --finalize"

  case "$ACTION" in
    *init* )
      echo ${TUNE} ${SEP} `now`
      echo ${TUNE} ${SEP} `now` >> ${LOGFILE}
      echo $GENCMD  $INITFIN -v
      echo $GENCMD  $INITFIN -v >> ${LOGFILE}
           $GENCMD  $INITFIN -v >> ${LOGFILE} 2>&1
      init_stat=$?
      echo -e "${OUTGREEN}init_stat=${init_stat}${OUTNOCOL}"
      ;;
    *launch* | *dag* )
      echo ${TUNE} ${SEP} `now`
      echo ${TUNE} ${SEP} `now` >> ${LOGFILE}
      echo $GENCMD  --launch-dag
      echo $GENCMD  --launch-dag >> ${LOGFILE}
           $GENCMD  --launch-dag >> ${LOGFILE} 2>&1
      launch_stat=$?
      echo -e "${OUTGREEN}launch_stat=${launch_stat}${OUTNOCOL}"
      ;;
    *stage2* )
      echo ${TUNE} ${SEP} `now`
      echo ${TUNE} ${SEP} `now` >> ${LOGFILE}
      echo $GENCMD  --run-stage 2
      echo $GENCMD  --run-stage 2 >> ${LOGFILE}
           $GENCMD  --run-stage 2 >> ${LOGFILE} 2>&1
      stage2_stat=$?
      echo -e "${OUTGREEN}stage4_stat=${stage2_stat}${OUTNOCOL}"
      ;;
    *stage4* )
      echo ${TUNE} ${SEP} `now`
      echo ${TUNE} ${SEP} `now` >> ${LOGFILE}
      echo $GENCMD  --run-stage 4
      echo $GENCMD  --run-stage 4 >> ${LOGFILE}
           $GENCMD  --run-stage 4 >> ${LOGFILE} 2>&1
      stage4_stat=$?
      echo -e "${OUTGREEN}stage4_stat=${stage4_stat}${OUTNOCOL}"
      ;;
    *stage5* )
      echo ${TUNE} ${SEP} `now`
      echo ${TUNE} ${SEP} `now` >> ${LOGFILE}
      echo $GENCMD  --run-stage 5
      echo $GENCMD  --run-stage 5 >> ${LOGFILE}
           $GENCMD  --run-stage 5 >> ${LOGFILE} 2>&1
      stage5_stat=$?
      echo -e "${OUTGREEN}stage5_stat=${stage5_stat}${OUTNOCOL}"
      ;;
    *status* )
      echo ${TUNE} ${SEP} `now`
           $GENCMD --status
      ;;
    * )
      echo -e "${OUTORANGE}unknown ACTION=${ACTION}${OUTNOCOL}"
      ;;
   esac
done
### $GENCMD --launch-dag

# end-of-script
