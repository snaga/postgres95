#!/bin/sh
#-------------------------------------------------------------------------
#
# Gen_fmgrtab.sh--
#    shell script to generate fmgr.h and fmgrtab.c from pg_proc.h
#
# Copyright (c) 1994, Regents of the University of California
#
#
# IDENTIFICATION
#    $Header: /usr/local/cvsroot/postgres95/src/backend/utils/Gen_fmgrtab.sh,v 1.3 1996/07/22 21:55:40 scrappy Exp $
#
# NOTES
#    Passes any -D options on to cpp prior to generating the list
#    of internal functions.  These come from BKIOPTS.
#
#-------------------------------------------------------------------------

# cpp is usually in one of these places...
PATH=/usr/lib:/lib:/usr/ccs/lib:$PATH

BKIOPTS=''
if [ $? != 0 ]
then
	echo `basename $0`: Bad option
	exit 1
fi

#
# Pass on any -D declarations, throwing away any other command
# line switches.
#
for opt in $*
do
	case $opt in
	-D) BKIOPTS="$BKIOPTS -D$2"; shift; shift;;
	-D*) BKIOPTS="$BKIOPTS $1";shift;;
	--) shift; break;;
	-*) shift;;
	esac
done

INFILE=$1
RAWFILE=fmgr.raw
HFILE=fmgr.h
TABCFILE=fmgrtab.c

#
# Generate the file containing raw pg_proc tuple data
# (but only for "internal" language procedures...).
#
# Unlike genbki.sh, which can run through cpp last, we have to
# deal with preprocessor statements first (before we sort the
# function table by oid).
#
awk '
BEGIN		{ raw = 0; }
/^DATA/		{ print; next; }
/^BKI_BEGIN/	{ raw = 1; next; }
/^BKI_END/	{ raw = 0; next; }
raw == 1	{ print; next; }' $INFILE | \
sed 	-e 's/^.*OID[^=]*=[^0-9]*//' \
	-e 's/(//g' \
	-e 's/[ 	]*).*$//' | \
awk '
/^#/		{ print; next; }
$4 == "11"	{ print; next; }' | \
cpp $BKIOPTS | \
egrep '^[0-9]' | \
sort -n > $RAWFILE

#
# Generate fmgr.h
#
cat > $HFILE <<FuNkYfMgRsTuFf
/*-------------------------------------------------------------------------
 *
 * $HFILE--
 *    Definitions for using internal procedures.
 *
 *
 * Copyright (c) 1994, Regents of the University of California
 *
 * $Id: Gen_fmgrtab.sh,v 1.3 1996/07/22 21:55:40 scrappy Exp $
 *
 * NOTES
 *	******************************
 *	*** DO NOT EDIT THIS FILE! ***
 *	******************************
 *
 *	It has been GENERATED by $0
 *	from $1
 *
 *-------------------------------------------------------------------------
 */
#ifndef	FMGR_H
#define FMGR_H

#include "postgres.h"			/* for some prototype typedefs */

/*
 *	Maximum number of arguments for a built-in function.
 *
 *	XXX note that you cannot call a function with more than 8 
 *	    arguments from the user level since the catalogs only 
 *	    store 8 argument type values for type-checking ...
 */
#define	MAXFMGRARGS	9

typedef struct {
    char *data[MAXFMGRARGS];
} FmgrValues;

/*
 * defined in fmgr.c
 */
extern char *fmgr_c(func_ptr user_fn, Oid func_id, int n_arguments,
	FmgrValues *values, bool *isNull);
extern void fmgr_info(Oid procedureId, func_ptr *function, int *nargs);
extern char *fmgr(Oid procedureId, ... );
extern char *fmgr_ptr(func_ptr user_fn, Oid func_id, ... );
extern char *fmgr_array_args(Oid procedureId, int nargs, 
			     char *args[], bool *isNull);

/*
 * defined in dfmgr.c
 */
extern func_ptr fmgr_dynamic(Oid procedureId, int *pronargs);
extern void load_file(char *filename);


/*
 *	For performance reasons, we often want to simply jump through a
 *	a function pointer (if it's valid, that is).  These calls have
 *	been macroized so we can run them through a routine that does
 *	sanity-checking (and so we can track them down more easily when
 *	we must).
 */
#ifdef TRACE_FMGR_PTR
#define	FMGR_PTR2(FP, FID, ARG1, ARG2) \
	fmgr_ptr(FP, FID, 2, ARG1, ARG2)
#else
#define	FMGR_PTR2(FP, FID, ARG1, ARG2) \
	((FP) ? (*((func_ptr)(FP)))(ARG1, ARG2) : fmgr(FID, ARG1, ARG2))
#endif

/*
 *	Flags for the builtin oprrest selectivity routines.
 */
#define	SEL_CONSTANT 	1	/* constant does not vary (not a parameter) */
#define	SEL_RIGHT	2 	/* constant appears to right of operator */

FuNkYfMgRsTuFf
awk '{ print $2, $1; }' $RAWFILE | \
tr '[a-z]' '[A-Z]' | \
sed -e 's/^/#define F_/' >> $HFILE
cat >> $HFILE <<FuNkYfMgRsTuFf

#endif	/* FMGR_H */
FuNkYfMgRsTuFf

#
# Generate fmgr function table file.
#
# Print out the bogus function declarations, then the table that
# refers to them.
#
cat > $TABCFILE <<FuNkYfMgRtAbStUfF
/*-------------------------------------------------------------------------
 *
 * $TABCFILE--
 *    The function manager's table of internal functions.
 *
 * Copyright (c) 1994, Regents of the University of California
 *
 *
 * IDENTIFICATION
 *    $Header: /usr/local/cvsroot/postgres95/src/backend/utils/Gen_fmgrtab.sh,v 1.3 1996/07/22 21:55:40 scrappy Exp $
 *
 * NOTES
 *
 *	******************************
 *	*** DO NOT EDIT THIS FILE! ***
 *	******************************
 *
 *	It has been GENERATED by $0
 *	from $1
 *
 *	We lie here to cc about the return type and arguments of the
 *	builtin functions; all ld cares about is the fact that it
 *	will need to resolve an external function reference.
 *
 *-------------------------------------------------------------------------
 */
#ifdef WIN32
#include <limits.h>
#else
# if defined(PORTNAME_BSD44_derived) || \
     defined(PORTNAME_bsdi) || \
     defined(PORTNAME_bsdi_2_1)
# include <machine/limits.h>
# define MAXINT	INT_MAX
# else
# include <values.h>           /* for MAXINT */
# endif /* bsd descendents */
#endif /* WIN32 */

#include "utils/fmgrtab.h"

FuNkYfMgRtAbStUfF
awk '{ print "extern char *" $2 "();"; }' $RAWFILE >> $TABCFILE
cat >> $TABCFILE <<FuNkYfMgRtAbStUfF

static FmgrCall fmgr_builtins[] = {
FuNkYfMgRtAbStUfF
awk '{ printf ("  {%d , %d , %s, \"%s\" },\n"), $1, $8, $2, $2 }' $RAWFILE >> $TABCFILE
cat >> $TABCFILE <<FuNkYfMgRtAbStUfF
	/* guardian value */
#ifndef WIN32
      { MAXINT, 0, (func_ptr) NULL }
#else
      { INT_MAX, 0, (func_ptr) NULL }
#endif /* WIN32 */
};

static int fmgr_nbuiltins = (sizeof(fmgr_builtins) / sizeof(FmgrCall)) - 1;

FmgrCall *fmgr_isbuiltin(Oid id)
{
    register int i;
    int	low = 0;
    int	high = fmgr_nbuiltins;

    low = 0;
    high = fmgr_nbuiltins;
    while (low <= high) {
	i = low + (high - low) / 2;
	if (id == fmgr_builtins[i].proid)
	    break;
	else if (id > fmgr_builtins[i].proid)
	    low = i + 1;
	else
	    high = i - 1;
    }
    if (id == fmgr_builtins[i].proid)
	return(&fmgr_builtins[i]);
    return((FmgrCall *) NULL);
}

func_ptr fmgr_lookupByName(char *name) 
{
    int i;
    for (i=0;i<fmgr_nbuiltins;i++) {
	if (strcmp(name,fmgr_builtins[i].funcName) == 0)
		return(fmgr_builtins[i].func);
    }
    return((func_ptr) NULL);
}

FuNkYfMgRtAbStUfF

rm -f $RAWFILE

# ----------------
#	all done
# ----------------
exit 0