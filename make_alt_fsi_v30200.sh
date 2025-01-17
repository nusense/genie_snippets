#! /usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  #echo "script ${BASH_SOURCE[0]} is being sourced ..."
  QUITCMD="return"
else
  #echo "script is being run ..."
  QUITCMD="exit"
fi

#==============================================================================

BASETUNE=$1
NEWFSI=$2

XSECVER="v3_02_02"
XSECDOT=`echo ${XSECVER} | tr _ . | tr -d v`   # "3.02.00"
KNOTS="250"
EMAX="1000"

if [ "$BASETUNE" = "" ]; then BASETUNE=G18_02a_00_000 ; fi
if [ "$NEWFSI"   = "" ]; then NEWFSI="b" ; fi

WORKDIR=/genie/app/rhatcher/make_alt_fsi
START=`pwd`

#==============================================================================

#NEWCMC=`echo $BASETUNE | cut -c 1-6`
#NEWSUB=`echo $BASETUNE | cut -c 8-`
#NEWTUNE="${NEWCMC}${NEWFSI}${NEWSUB}"

NEWF1=`echo $BASETUNE | cut -d'_' -f1`
OLDF2=`echo $BASETUNE | cut -d'_' -f2`
NEWF2=${OLDF2::-1}${NEWFSI}
NEWF3=`echo $BASETUNE | cut -d'_' -f3`
NEWF4=`echo $BASETUNE | cut -d'_' -f4`
NEWTUNE=${NEWF1}_${NEWF2}_${NEWF3}_${NEWF4}

BASETUNESQ=`echo $BASETUNE | tr -d "_"`
NEWTUNESQ=`echo $NEWTUNE | tr -d "_"`

BASEQDASH=${BASETUNESQ}-k${KNOTS}-e${EMAX}
NEWQDASH=${NEWTUNESQ}-k${KNOTS}-e${EMAX}

echo BASETUNE=$BASETUNE  NEWTUNE=$NEWTUNE
echo $BASETUNESQ $NEWTUNESQ
echo XSECVER=$XSECVER $XSECDOT KNOTS=$KNOTS EMAX=$EMAX

TOPDIR=/pnfs/genie/scratch/users/rhatcher/gen_genie_splines_v3

BASESUBDIR=GXSPLINES-${XSECVER}-${BASETUNESQ}-k${KNOTS}-e${EMAX}/ups
NEWSUBDIR=GXSPLINES-${XSECVER}-${NEWTUNESQ}-k${KNOTS}-e${EMAX}/ups

BASETAR=genie_xsec-${XSECDOT}-noarch-${BASEQDASH}.tar.bz2
NEWTAR=genie_xsec-${XSECDOT}-noarch-${NEWQDASH}.tar.bz2

ls ${TOPDIR}/${BASESUBDIR}
echo ${BASETAR}
echo ${NEWTAR}

if [ ! -f ${TOPDIR}/${BASESUBDIR}/${BASETAR} ]; then
  echo -e "${OUTRED}can't find original tarball${OUTNOCOL}"
  echo look for ${TOPDIR}/${BASESUBDIR}/${BASETAR}
  $QUITCMD 1
fi

if [ ! -d ${TOPDIR}/${NEWSUBDIR} ]; then
  mkdir -p ${TOPDIR}/${NEWSUBDIR}
fi

if [ ! -d ${WORKDIR} ]; then mkdir -p ${WORKDIR} ; fi
cd ${WORKDIR}
WORKDIRTEST=`pwd`
if [ ${WORKDIR} != ${WORKDIRTEST} ]; then
  echo -e "${OUTRED}not in ${WORKDIR}${OUTNOCOL}"
  $QUITCMD 2
fi

echo -e "${OUTGREEN}working in ${WORKDIR}${OUTNOCOL}"

if [ -d genie_xsec ]; then rm -rf genie_xsec ; fi

tar xvjf ${TOPDIR}/${BASESUBDIR}/${BASETAR}

cd ${WORKDIR}
cd genie_xsec/${XSECVER}.version
BASEVFILE=NULL_${BASEQDASH}
NEWVFILE=NULL_${NEWQDASH}
if [ ! -f ${BASEVFILE} ]; then
  echo -e "${OUTRED}no version file ${BASEVFILE}${OUTNOCOL}"
  $QUITCMD 3
fi
sed -e "s/${BASETUNESQ}/${NEWTUNESQ}/g" ${BASEVFILE} > ${NEWVFILE}
diff ${BASEVFILE} ${NEWVFILE}
rm   ${BASEVFILE}

cd ${WORKDIR}
cd genie_xsec/${XSECVER}/NULL
mv ${BASEQDASH} ${NEWQDASH}
cd ${NEWQDASH}
pwd

cd ups
if [ ! -f genie_xsec.table ]; then
  echo -e "${OUTRED}no genie_xsec.table${OUTNOCOL}"
  $QUITCMD 3
fi
sed -i -e "s/${BASETUNESQ}/${NEWTUNESQ}/g" -e "s/${BASETUNE}/${NEWTUNE}/g" genie_xsec.table

cd ../data
if [ ! -f README ]; then
  echo -e "${OUTRED}no README file${OUTNOCOL}"
  $QUITCMD 4
fi

gunzip gxspl-freenuc.xml.gz
sed -i -e "s/${BASETUNE}/${NEWTUNE}/g" gxspl-freenuc.xml
gzip gxspl-freenuc.xml

gunzip  gxspl-NUbig.xml.gz
sed -i -e "s/${BASETUNE}/${NEWTUNE}/g" gxspl-NUbig.xml
gzip  gxspl-NUbig.xml

sed -i -e "s/${BASETUNE}/${NEWTUNE}/g" README
sed -i -e "s/${BASETUNE}/${NEWTUNE}/g" gxspl-NUsmall.xml

echo "looking for instance of old tune name:"
grep ${BASETUNE} *
echo ""
echo "looking for instance of new tune name:"
grep ${NEWTUNE} *
echo ""

cd $WORKDIR
if [ -f ${NEWTAR} ]; then rm ${NEWTAR} ; fi
echo tar cvjf ${NEWTAR} genie_xsec
tar cvjf ${NEWTAR} genie_xsec

echo -e "${OUTYELLOW}=========================================================${OUTNOCOL}"
cd $START
# end-of-script
