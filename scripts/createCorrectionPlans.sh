#!/bin/bash -e

configFile=$1
currentStep=$2
slurmID=$3

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}

if [[ -z ${FIX_FILT_SCRUB_TYPE} ]]
then
	(>&2 echo "WARNING - Variable FIX_FILT_SCRUB_TYPE is not set. Use default mode: dalign!")
	FIX_FILT_SCRUB_TYPE=1
fi

if [[ -z "${PROJECT_ID}" ]]
then 
    (>&2 echo "ERROR - You have to specify a project id. Set variable PROJECT_ID")
    exit 1
fi

if [[ ! -n "${FIX_CORR_TYPE}" ]]
then 
    (>&2 echo "cannot create touring scripts if variable FIX_CORR_TYPE is not set.")
    exit 1
fi

if [[ ! -n ${RAW_DB} ]]
then 
    (>&2 echo "raw database unknown - You have to set the variable RAW_DB")
    exit 1
fi

if [[ ! -f ${RAW_DB%.db}.db ]]
then 
    (>&2 echo "raw database ${RAW_DB%.db}.db missing")
    exit 1 
fi

if [[ ! -n ${FIX_DB} ]]
then 
    (>&2 echo "patched database unknown - You have to set the variable FIX_DB")
    exit 1
fi

if [[ ! -f ${FIX_DB%.db}.db ]]
then 
    (>&2 echo "patched database ${FIX_DB%.db}.db missing")
    exit 1
fi

if [[ ! -n ${COR_DB} ]]
then 
    (>&2 echo "corrected database unknown - You have to set the variable COR_DB")
    exit 1
fi

function getNumOfDbBlocks()
{
    db=$1
    if [[ ! -f $db ]]
    then
        (>&2 echo "database $db not found")
        exit 1
    fi

    blocks=$(grep block $db | awk '{print $3}')
    if [[ ! -n $blocks ]]
    then 
        (>&2 echo "database $db has not been partitioned. Run DBsplit first!")
        exit 1
    fi 
    echo ${blocks}
}

function getSubDirName()
{
    runID=$1
    blockID=$2

    dname="d${runID}"

    if [[ $runID -lt 10 ]]
    then 
        dname="d00${runID}"
    elif [[ $runID -lt 100 ]]
    then 
        dname="d0${runID}"
    fi

    bname="${blockID}"

    if [[ ${blockID} -lt 10 ]]
    then 
        bname="0000${blockID}"
    elif [[ ${blockID} -lt 100 ]]
    then 
        bname="000${blockID}"
    elif [[ ${blockID} -lt 1000 ]]
    then 
        bname="00${blockID}"           
    elif [[ ${blockID} -lt 10000 ]]
    then 
        bname="0${blockID}"           
    fi
    echo ${dname}_${bname}                 
}

function setpath2ridsOptions()
{
    COR_PATH2RIDS_OPT=""
    if [[ -z ${FIX_CORR_PATHS2RIDS_FILE} ]]
    then
      FIX_CORR_PATHS2RIDS_FILE=${COR_DB%.db}.tour.rids
    fi
}

function setLAqOptions()
{
    SCRUB_LAQ_OPT=""
    adaptQTRIMCUTOFF=""    

    if [[ -n ${FIX_SCRUB_LAQ_MINSEG} && ${FIX_SCRUB_LAQ_MINSEG} -ne 0 ]]
    then
        SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -s ${FIX_SCRUB_LAQ_MINSEG}"
    else 
        FIX_SCRUB_LAQ_MINSEG=25
        SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -s ${FIX_SCRUB_LAQ_MINSEG}"
    fi

    if [[ -n ${FIX_SCRUB_LAQ_QTRIMCUTOFF} && ${FIX_SCRUB_LAQ_QTRIMCUTOFF} -ne 0 ]]
    then
        if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -ne 100 ]]
        then 
            adaptQTRIMCUTOFF=$(echo "${FIX_SCRUB_LAQ_QTRIMCUTOFF}*${RAW_FIX_DALIGNER_TRACESPACE}/100+1" | bc)
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"
        else
            adaptQTRIMCUTOFF=${FIX_SCRUB_LAQ_QTRIMCUTOFF}
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"            
        fi
    else 
        if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -ne 100 ]]
        then 
            FIX_SCRUB_LAQ_QTRIMCUTOFF=25
            adaptQTRIMCUTOFF=$(echo "${FIX_SCRUB_LAQ_QTRIMCUTOFF}*${RAW_FIX_DALIGNER_TRACESPACE}/100+1" | bc)
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"
        else
            adaptQTRIMCUTOFF=25
            FIX_SCRUB_LAQ_QTRIMCUTOFF=25
            SCRUB_LAQ_OPT="${SCRUB_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"            
        fi
    fi
}

function setLAcorrectOptions()
{
    COR_LACORRECT_OPT=""

    if [[ -n ${FIX_CORR_LACORRECT_VERBOSE} ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -v"
    fi
    if [[ -n ${FIX_CORR_LACORRECT_THREAD} ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -j ${FIX_CORR_LACORRECT_THREAD}"
    fi
    if [[ -n ${FIX_CORR_LACORRECT_MAXCOV} ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -c ${FIX_CORR_LACORRECT_MAXCOV}"
    fi 
    if [[ -n ${FIX_CORR_LACORRECT_MAXTILES} ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -t ${FIX_CORR_LACORRECT_MAXTILES}"
    fi  
    if [[ -z ${FIX_CORR_PATHS2RIDS_FILE} ]]
    then 
        setpath2ridsOptions
    fi
    if [[ -z ${FILT_LAFILTER_OPT} ]]
    then
        setLAfilterOptions 1
    fi
    COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -r ${FIX_FILT_OUTDIR}/${FIX_CORR_PATHS2RIDS_FILE}"

    if [[ -z ${SCRUB_LAQ_OPT} ]]
    then
        setLAqOptions
    fi

    if [[ ${FIX_FILT_SCRUB_TYPE} -eq 1 ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -q q0_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_dalign"
    elif  [[ ${FIX_FILT_SCRUB_TYPE} -eq 2 ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -q q0_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_repcomp"
    elif  [[ ${FIX_FILT_SCRUB_TYPE} -eq 3 ]]
    then
        COR_LACORRECT_OPT="${COR_LACORRECT_OPT} -q q0_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_forcealign"
    fi             
}

function setTourToFastaOptions()
{
    COR_TOURTOFASTA_OPT=""
    if [[ -n ${COR_CORR_TOURTOFASTA_SPLIT} ]]
    then
        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -s"
    fi
   
    if [[ -n ${FIX_CORR_2FASTA_TRIMNAME} ]]
    then
	COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t ${FIX_CORR_2FASTA_TRIMNAME}"
    elif [[ -n ${FIX_CORR_2FASTA_TRIM} ]]
    then 
    	COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t ${FIX_CORR_2FASTA_TRIM}"
	else
	    if [[ ${FIX_FILT_SCRUB_TYPE} -eq 1 ]]
	    then
	        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_dalign"
	    elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 2 ]]
	    then
	        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_repcomp"
	    elif [[ ${FIX_FILT_SCRUB_TYPE} -eq 3 ]]
	    then
	        COR_TOURTOFASTA_OPT="${COR_TOURTOFASTA_OPT} -t trim1_d${FIX_SCRUB_LAQ_QTRIMCUTOFF}_s${FIX_SCRUB_LAQ_MINSEG}_forcealign"
	    fi
	fi
}

function setDBsplitOptions()
{
    DACCORD_DBSPLIT_OPT=""

   
    if [[ -z ${COR_DACCORD_DBSPLIT_S} ]]
    then
        (>&2 echo "Set DBsplit -s argument to default value: 400!")
        COR_DACCORD_DBSPLIT_S=400
    fi

    DACCORD_DBSPLIT_OPT="${DACCORD_DBSPLIT_OPT} -s${COR_DACCORD_DBSPLIT_S}"
}

function setDatanderOptions()
{
    ### find and set datander options 
    DACCORD_DATANDER_OPT=""
    if [[ -n ${COR_DACCORD_DATANDER_THREADS} ]]
    then
        DACCORD_DATANDER_OPT="${DACCORD_DATANDER_OPT} -T${COR_DACCORD_DATANDER_THREADS}"
    fi
    if [[ -n ${COR_DACCORD_DATANDER_MINLEN} ]]
    then
        DACCORD_DATANDER_OPT="${DACCORD_DATANDER_OPT} -l${COR_DACCORD_DATANDER_MINLEN}"
    fi
}

function setTANmaskOptions()
{
    DACCORD_TANMASK_OPT=""
    if [[ -n ${COR_DACCORD_TANMASK_VERBOSE} && ${COR_DACCORD_TANMASK_VERBOSE} -ge 1 ]]
    then
        DACCORD_TANMASK_OPT="${DACCORD_TANMASK_OPT} -v"
    fi
    if [[ -n ${COR_DACCORD_TANMASK_MINLEN} && ${COR_DACCORD_TANMASK_MINLEN} -ge 1 ]]
    then
        DACCORD_TANMASK_OPT="${DACCORD_TANMASK_OPT} -l${COR_DACCORD_TANMASK_MINLEN}"
    fi
    if [[ -n ${COR_DACCORD_TANMASK_TRACK} ]]
    then
        DACCORD_TANMASK_OPT="${DACCORD_TANMASK_OPT} -n${COR_DACCORD_TANMASK_TRACK}"
    else 
    	COR_DACCORD_TANMASK_TRACK=tan
    	DACCORD_TANMASK_OPT="${DACCORD_TANMASK_OPT} -n${COR_DACCORD_TANMASK_TRACK}"
    fi
}

function setDaligerOptions()
{
    DACCORD_DALIGNER_OPT=""
    if [[ -n ${COR_DACCORD_DALIGNER_IDENTITY_OVLS} && ${COR_DACCORD_DALIGNER_IDENTITY_OVLS} -gt 0 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -I"
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_KMER} && ${COR_DACCORD_DALIGNER_KMER} -gt 0 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -k${COR_DACCORD_DALIGNER_KMER}"
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_ERR} ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -e${COR_DACCORD_DALIGNER_ERR}"
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_BIAS} && ${COR_DACCORD_DALIGNER_BIAS} -eq 1 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -b"
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_BRIDGE} && ${COR_DACCORD_DALIGNER_BRIDGE} -eq 1 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -B"
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_ASYMMETRIC} && ${COR_DACCORD_DALIGNER_ASYMMETRIC} -eq 1 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -A"
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_OLEN} ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -l${COR_DACCORD_DALIGNER_OLEN}"
    fi    
    if [[ -n ${COR_DACCORD_DALIGNER_MEM} && ${COR_DACCORD_DALIGNER_MEM} -gt 0 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -M${COR_DACCORD_DALIGNER_MEM}"
    fi    
    if [[ -n ${COR_DACCORD_DALIGNER_HITS} ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -h${COR_DACCORD_DALIGNER_HITS}"
    fi 
    if [[ -n ${COR_DACCORD_DALIGNER_T} ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -t${COR_DACCORD_DALIGNER_T}"
    fi  
    if [[ -n ${COR_DACCORD_DALIGNER_MASK} ]]
    then
        for x in ${COR_DACCORD_DALIGNER_MASK}
        do 
            DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -m${x}"
        done
    fi
    if [[ -n ${COR_DACCORD_DALIGNER_TRACESPACE} && ${COR_DACCORD_DALIGNER_TRACESPACE} -gt 0 ]]
    then
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -s${COR_DACCORD_DALIGNER_TRACESPACE}"
    fi
    if [[ -n ${THREADS_daligner} ]]
    then 
        DACCORD_DALIGNER_OPT="${DACCORD_DALIGNER_OPT} -T${THREADS_daligner}"
    fi
    if [ ! -n ${COR_DACCORD_DALIGNER_DAL} ]
    then
        COR_DACCORD_DALIGNER_DAL=8
    fi 
}

function setLAmergeOptions()
{
    DACCORD_LAMERGE_OPT=""
    if [[ -n ${COR_DACCORD_LAMERGE_NFILES} && ${COR_DACCORD_LAMERGE_NFILES} -gt 0 ]]
    then
        DACCORD_LAMERGE_OPT="${DACCORD_LAMERGE_OPT} -n ${COR_DACCORD_LAMERGE_NFILES}"
    fi
    if [[ -n ${COR_DACCORD_LAMERGE_SORT} && ${COR_DACCORD_LAMERGE_SORT} -gt 0 ]]
    then
        DACCORD_LAMERGE_OPT="${DACCORD_LAMERGE_OPT} -s"
    fi
    if [[ -n ${COR_DACCORD_LAMERGE_VERBOSE} && ${COR_DACCORD_LAMERGE_VERBOSE} -gt 0 ]]
    then
        DACCORD_LAMERGE_OPT="${DACCORD_LAMERGE_OPT} -v"
    fi
}

function setLArepeatOptions()
{
    if [[ ${#COR_DACCORD_LAREPEAT_LEAVE_COV[*]} -ne ${#COR_DACCORD_LAREPEAT_ENTER_COV[*]} || ${#COR_DACCORD_LAREPEAT_ENTER_COV[*]} -ne ${#COR_DACCORD_LAREPEAT_COV[*]} ]]
    then 
        (>&2 echo "LArepeat number of elements of COR_DACCORD_LAREPEAT_LEAVE_COV and COR_DACCORD_LAREPEAT_ENTER_COV and COR_DACCORD_LAREPEAT_COV differs")
        (>&2 echo "they must be of the same length")
        exit 1
    fi

    numRepeatTracks=${#COR_DACCORD_LAREPEAT_LEAVE_COV[*]}

    # define array variable - because we may want to create several repeat tracks in one run
    unset DACCORD_LAREPEAT_OPT
    unset DACCORD_DAZZ_LAREPEAT
    unset DACCORD_LAREPEAT_REPEATNAMES
    ### find and set LArepeat options     
    
    stype=""
    if [[ "x$1" == "x1" ]]
    then 
        stype="_dalign"
    elif [[ "x$1" == "x2" ]]
    then 
        stype="_repcomp"
    elif [[ "x$1" == "x3" ]]
    then 
        stype="_forcealign"        
    else
        (>&2 echo "Unknown scrubbing type !!!")
        exit 1            
    fi 

    for x in $(seq 0 $((${numRepeatTracks}-1)))
    do 
        tmp=""
        tmp="${tmp} -l ${COR_DACCORD_LAREPEAT_LEAVE_COV[$x]}"
        tmp="${tmp} -h ${COR_DACCORD_LAREPEAT_ENTER_COV[$x]}"

        if [[ -n ${COR_DACCORD_LAREPEAT_OLEN} && ${COR_DACCORD_LAREPEAT_OLEN} -gt 0 ]]
        then
            tmp="${tmp} -o ${COR_DACCORD_LAREPEAT_OLEN}"
        fi

        if [[ ${COR_DACCORD_LAREPEAT_COV[$x]} -ne -1 ]]
        then 
            tmp="${tmp} -c ${COR_DACCORD_LAREPEAT_COV[$x]}"
            tmp="${tmp} -t repeats_c${COR_DACCORD_LAREPEAT_COV[$x]}_l${COR_DACCORD_LAREPEAT_LEAVE_COV[$x]}h${COR_DACCORD_LAREPEAT_ENTER_COV[$x]}${stype}"
            DACCORD_LAREPEAT_REPEATNAMES[$x]="repeats_c${COR_DACCORD_LAREPEAT_COV[$x]}_l${COR_DACCORD_LAREPEAT_LEAVE_COV[$x]}h${COR_DACCORD_LAREPEAT_ENTER_COV[$x]}${stype}"
        else
        	if [[ -n ${COR_DACCORD_LAREPEAT_MAX_COV} && ${COR_DACCORD_LAREPEAT_MAX_COV} -gt 100 ]]
        	then 
        		tmp="${tmp} -M ${COR_DACCORD_LAREPEAT_MAX_COV}"
			elif [[ -n ${RAW_COV} && $((${RAW_COV}+20)) -gt 100 ]]
			then
				tmp="${tmp} -M 200"
        	fi         	
            tmp="${tmp} -t repeats_calCov_l${COR_DACCORD_LAREPEAT_LEAVE_COV[$x]}h${COR_DACCORD_LAREPEAT_ENTER_COV[$x]}${stype}"
            DACCORD_LAREPEAT_REPEATNAMES[$x]="repeats_calCov_l${COR_DACCORD_LAREPEAT_LEAVE_COV[$x]}h${COR_DACCORD_LAREPEAT_ENTER_COV[$x]}${stype}"
        fi
        DACCORD_LAREPEAT_OPT[$x]=${tmp}                
    done 
    DACCORD_DAZZ_LAREPEAT_OPT=" -v -c$(echo "${FIX_COV} ${COR_DACCORD_LAREPEAT_ENTER_COV[0]}" | awk '{printf "%d", $1*$2}') -nrepeats_c$(echo "${FIX_COV} ${COR_DACCORD_LAREPEAT_ENTER_COV[0]}" | awk '{printf "%d", $1*$2}')${stype}"

    FIX_REPMASK_REPEATTRACK=""
    for x in $(seq 1 ${#FIX_REPMASK_BLOCKCMP[*]})
    do
        idx=$(($x-1))
        FIX_REPMASK_REPEATTRACK="${FIX_REPMASK_REPEATTRACK} ${FIX_REPMASK_LAREPEAT_REPEATTRACK}_B${FIX_REPMASK_BLOCKCMP[${idx}]}C${FIX_REPMASK_LAREPEAT_COV[${idx}]}"
    done 

    ## check if repmaskFull_B10C10 exists 
    if [[ -f .${FIX_DB}.${FIX_REPMASK_LAREPEAT_REPEATTRACK}Full_B${FIX_REPMASK_BLOCKCMP[${idx}]}C${FIX_REPMASK_LAREPEAT_COV[${idx}]}.d2 ]]
    then
        FIX_REPMASK_REPEATTRACK="${FIX_REPMASK_REPEATTRACK} ${FIX_REPMASK_LAREPEAT_REPEATTRACK}Full_B${FIX_REPMASK_BLOCKCMP[${idx}]}C${FIX_REPMASK_LAREPEAT_COV[${idx}]}"
    fi
    
        
}

function setTKmergeOptions() 
{
    DACCORD_TKMERGE_OPT=""
    if [[ -n ${COR_DACCORD_TKMERGE_DELETE} && ${COR_DACCORD_TKMERGE_DELETE} -ne 0 ]]
    then
        DACCORD_TKMERGE_OPT="${DACCORD_TKMERGE_OPT} -d"
    fi
}

function setLAfilterOptions()
{
    if [[ "x$1" == "x1" ]]
    then 	
	    FILT_LAFILTER_OPT=""
	
	    if [[ -z ${FIX_FILT_OUTDIR} ]]
	    then
	        FIX_FILT_OUTDIR="m1"
	    fi
	    
	    ## its never used, but the variable is set once the function called for the first time
	    FILT_LAFILTER_OPT="-v"
	elif [[ "x$1" == "x2" ]]
	then     	    
	    DACCORD_LAFILTER_OPT=""
	    	
	    if [[ -z ${FIX_FILT_OUTDIR} ]]
	    then
	        FIX_FILT_OUTDIR="m1"
	    fi
	
	    if [[ -n ${COR_DACCORD_LAFILTER_NREP} && ${COR_DACCORD_LAFILTER_NREP} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -n ${COR_DACCORD_LAFILTER_NREP}"
	    fi
	    if [[ -n ${COR_DACCORD_LAFILTER_VERBOSE} && ${COR_DACCORD_LAFILTER_VERBOSE} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -v"
	    fi
	    if [[ -n ${COR_DACCORD_LAFILTER_PURGE} && ${COR_DACCORD_LAFILTER_PURGE} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -p"
	    fi
	    if [[ -n ${COR_DACCORD_LAFILTER_OLEN} && ${COR_DACCORD_LAFILTER_OLEN} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -o ${COR_DACCORD_LAFILTER_OLEN}"
	    fi    
	    if [[ -n ${COR_DACCORD_LAFILTER_RLEN} && ${COR_DACCORD_LAFILTER_RLEN} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -l ${COR_DACCORD_LAFILTER_RLEN}"
	    fi   
	
	    if [[ -n ${COR_DACCORD_LAFILTER_DIF} ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -d ${COR_DACCORD_LAFILTER_DIF}"
	    fi
	
	    if [[ -n ${COR_DACCORD_LAFILTER_UBAS} ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -u ${COR_DACCORD_LAFILTER_UBAS}"
	    fi
	    if [[ -n ${COR_DACCORD_LAFILTER_PRELOAD} && ${COR_DACCORD_LAFILTER_PRELOAD} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -L"
	    fi    
	    if [[ -n ${COR_DACCORD_LAFILTER_MERGEREPEATS} && ${COR_DACCORD_LAFILTER_MERGEREPEATS} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -y ${COR_DACCORD_LAFILTER_MERGEREPEATS}"
	    fi    
	    if [[ -n ${COR_DACCORD_LAFILTER_MERGEREPEATTIPS} && ${COR_DACCORD_LAFILTER_MERGEREPEATTIPS} -ne 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -Y ${COR_DACCORD_LAFILTER_MERGEREPEATTIPS}"
	    fi    
	    if [[ -n ${COR_DACCORD_LAFILTER_MINTIPCOV} && ${COR_DACCORD_LAFILTER_MINTIPCOV} -gt 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -z ${COR_DACCORD_LAFILTER_MINTIPCOV}"
	    fi            
	    if [[ -n ${COR_DACCORD_LAFILTER_MULTIMAPPER} && ${COR_DACCORD_LAFILTER_MULTIMAPPER} -gt 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -w"
	    fi
	    if [[ -n ${COR_DACCORD_LAFILTER_MAXREPEATMERGELEN} && ${COR_DACCORD_LAFILTER_MAXREPEATMERGELEN} -gt 0 ]]
	    then
	        DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -V ${COR_DACCORD_LAFILTER_MAXREPEATMERGELEN}"
	    fi
	    if [[ -n ${COR_DACCORD_LAFILTER_MAXREPEATMERGEWINDOW} && ${COR_DACCORD_LAFILTER_MAXREPEATMERGEWINDOW} -gt 0 ]]
	    then
	    	DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -W ${COR_DACCORD_LAFILTER_MAXREPEATMERGEWINDOW}"
	    fi
	                
	    
	    if [[ -n ${COR_DACCORD_LAFILTER_TRIM} && ${COR_DACCORD_LAFILTER_TRIM} -ne 0 ]]
	    then
	        if [[ -z ${SCRUB_LAQ_OPT} ]]
	        then 
	            setLAqOptions
	        fi
	    fi
		    
	    if [[ -n ${COR_DACCORD_LAFILTER_CHIMER} ]]
	    then 
	       DACCORD_LAFILTER_OPT="${DACCORD_LAFILTER_OPT} -c ${COR_DACCORD_LAFILTER_CHIMER}"
	    fi
	
	else 
        (>&2 echo "setLAfilterOptions: type $1 not supported")
        exit 1	
	fi
}

function setDaccordOptions()
{
	DACCORD_DACCORD_OPT=""
	
	if [[ -z ${COR_DACCORD_DACCORD_THREADS} ]]
	then 
		COR_DACCORD_DACCORD_THREADS=8
	fi
	DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -t${COR_DACCORD_DACCORD_THREADS}"
	
	if [[ -n ${COR_DACCORD_DACCORD_WINDOW} && ${COR_DACCORD_DACCORD_WINDOW} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -w${COR_DACCORD_DACCORD_WINDOW}"
	fi

	if [[ -n ${COR_DACCORD_DACCORD_ADVANCESIZE} && ${COR_DACCORD_DACCORD_ADVANCESIZE} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -a${COR_DACCORD_DACCORD_ADVANCESIZE}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_MAXDEPTH} && ${COR_DACCORD_DACCORD_MAXDEPTH} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -d${COR_DACCORD_DACCORD_MAXDEPTH}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_FULLSEQ} && ${COR_DACCORD_DACCORD_FULLSEQ} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -f1"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_VEBOSE} && ${COR_DACCORD_DACCORD_VEBOSE} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -V${COR_DACCORD_DACCORD_VEBOSE}"
	fi
		
	if [[ -n ${COR_DACCORD_DACCORD_MINWINDOWCOV} && ${COR_DACCORD_DACCORD_MINWINDOWCOV} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -m${COR_DACCORD_DACCORD_MINWINDOWCOV}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_MINWINDOWERR} && ${COR_DACCORD_DACCORD_MINWINDOWERR} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -e${COR_DACCORD_DACCORD_MINWINDOWERR}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_MINOUTLEN} && ${COR_DACCORD_DACCORD_MINOUTLEN} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -l${COR_DACCORD_DACCORD_MINOUTLEN}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_MINKFREQ} && ${COR_DACCORD_DACCORD_MINKFREQ} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} --minfilterfreq${COR_DACCORD_DACCORD_MINKFREQ}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_MAXKFREQ} && ${COR_DACCORD_DACCORD_MAXKFREQ} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} --maxfilterfreq${COR_DACCORD_DACCORD_MAXKFREQ}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_MAXOVLS} && ${COR_DACCORD_DACCORD_MAXOVLS} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -D${COR_DACCORD_DACCORD_MAXOVLS}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_VARD} && ${COR_DACCORD_DACCORD_VARD} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} --vard${COR_DACCORD_DACCORD_VARD}"
	fi
	
	if [[ -n ${COR_DACCORD_DACCORD_KMER} && ${COR_DACCORD_DACCORD_KMER} -gt 0 ]]
	then 
		DACCORD_DACCORD_OPT="${DACCORD_DACCORD_OPT} -k${COR_DACCORD_DACCORD_KMER}"
	fi
}

fixblocks=$(getNumOfDbBlocks ${FIX_DB%.db}.db)

if [[ -z ${COR_DIR} ]]
then 
    COR_DIR=correction
fi

## ensure some paths
if [[ -z "${MARVEL_SOURCE_PATH}" || ! -d  "${MARVEL_SOURCE_PATH}" ]]
then 
    (>&2 echo "ERROR - You have to set MARVEL_SOURCE_PATH. Used to report git version.")
    exit 1
fi

myTypes=("1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics" "1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics")
#type-0 steps: 1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics
#type-1 steps: 1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics ### for BIG genomes, we need to create several corrected databases
### daccord correction - including remapping 
#type-2 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 07-LArepeat/LAchain/LAstitch/LAgap, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord 
#type-3 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 06a-repcomp, 07-LArepeat/LAchain, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord
#type-4 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 06a-repcomp, 06b-forcealign, 07-LArepeat/LAchain, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord
if [[ ${FIX_CORR_TYPE} -eq 0 ]]
then
    ### paths2rids
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls corr_01_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do
            rm $x
        done

        setLAfilterOptions 1
        setpath2ridsOptions

        # create sym links 
        if [[ -d ${FIX_FILT_OUTDIR}/${COR_DIR} ]]
        then
            rm -r ${FIX_FILT_OUTDIR}/${COR_DIR}
        fi

        mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/reads
        mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs

        for x in ${FIX_FILT_OUTDIR}/tour/*[0-9].tour.paths;
        do  
            ln -s -r ${x} ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/$(basename ${x%.tour.paths}.tour.paths);
            ln -s -r ${x%.tour.paths}.graphml ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/$(basename ${x%.tour.paths}.graphml);
        done

        echo "find ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/ -name \"*.paths\" -exec cat {} \+ | awk '{if (NF > 4) print \$0}' | ${MARVEL_PATH}/scripts/paths2rids.py - ${FIX_FILT_OUTDIR}/${FIX_CORR_PATHS2RIDS_FILE}" > corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.version
    ### LAcorrect
    elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls corr_02_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do
            rm $x
        done

        setLAcorrectOptions

        for x in $(seq 1 ${fixblocks})
        do
            echo "${MARVEL_PATH}/bin/LAcorrect${COR_LACORRECT_OPT} -b ${x} ${FIX_FILT_OUTDIR}/${FIX_DB%.db} ${FIX_FILT_OUTDIR}/${FIX_DB%.db}.filt.${x}.las ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/${FIX_DB%.db}.${x}"
        done > corr_02_LAcorrect_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_02_LAcorrect_block_${FIX_DB%.db}.${slurmID}.version
    ### prepare corrected db 
    elif [[ ${currentStep} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls corr_03_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do
            rm $x
        done

        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions 1
        fi

        echo "if [[ -f ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.db ]]; then ${MARVEL_PATH}/bin/DBrm ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}; fi" > corr_03_createDB_single_${FIX_DB%.db}.${slurmID}.plan
        echo "find ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/ -name \"${FIX_DB%.db}.[0-9]*.[0-9]*.fasta\" > ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.fofn" >> corr_03_createDB_single_${FIX_DB%.db}.${slurmID}.plan
        echo "${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace -f ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.fofn ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}" >> corr_03_createDB_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_03_createDB_single_${FIX_DB%.db}.${slurmID}.version
    elif [[ ${currentStep} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls corr_04_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do
            rm $x
        done
        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions 1
        fi
        setTourToFastaOptions
        for x in ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/*.tour.paths
        do
            echo "${MARVEL_PATH}/scripts/tour2fasta.py${COR_TOURTOFASTA_OPT} -p $(basename ${x%.tour.paths}) -c ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db} ${FIX_FILT_OUTDIR}/${FIX_DB%.db} ${x%.tour.paths}.graphml ${x}" 
        done > corr_04_tour2fasta_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_04_tour2fasta_block_${FIX_DB%.db}.${slurmID}.version
    ### statistics
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls corr_05_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do
            rm $x
        done

        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions 1
        fi

        if [[ -n ${SLURM_STATS} && ${SLURM_STATS} -gt 0 ]]
                then
                ### run slurm stats - on the master node !!! Because sacct is not available on compute nodes
                if [[ $(hostname) == "falcon1" || $(hostname) == "falcon2" ]]
                then
                        bash ${SUBMIT_SCRIPTS_PATH}/slurmStats.sh ${configFile}
                else
                        cwd=$(pwd)
                        ssh falcon "cd ${cwd} && bash ${SUBMIT_SCRIPTS_PATH}/slurmStats.sh ${configFile}"
                fi
                fi

            if [[ -n ${MARVEL_STATS} && ${MARVEL_STATS} -gt 0 ]]
                then
                ### create assemblyStats plan 
                echo "${SUBMIT_SCRIPTS_PATH}/assemblyStats.sh ${configFile} 7" > corr_05_marvelStats_single_${FIX_DB%.db}.${slurmID}.plan
                echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_05_marvelStats_single_${FIX_DB%.db}.${slurmID}.version
        fi
    else
        (>&2 echo "step ${currentStep} in FIX_CORR_TYPE ${FIX_CORR_TYPE} not supported")
        (>&2 echo "valid steps are: ${myTypes[${FIX_CORR_TYPE}]}")
        exit 1
	fi
elif [[ ${FIX_CORR_TYPE} -eq 1 ]]
then 
    ### paths2rids
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls corr_01_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        setLAfilterOptions 1
        setpath2ridsOptions

        # create sym links 
        if [[ -d ${FIX_FILT_OUTDIR}/${COR_DIR} ]]
        then
            rm -r ${FIX_FILT_OUTDIR}/${COR_DIR}
        fi 

        mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/reads
        mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs

        for x in ${FIX_FILT_OUTDIR}/tour/*[0-9].tour.paths; 
        do 
            ln -s -r ${x} ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/$(basename ${x%.tour.paths}.tour.paths); 
            ln -s -r ${x%.tour.paths}.graphml ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/$(basename ${x%.tour.paths}.graphml); 
        done

        echo "max_reads=100000" > corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
		echo "bl=1" >> corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
		echo "[ -e ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.1.rids ] && rm ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.[0-9]*.rids" >> corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
		echo "[ -e ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.1.paths ] && rm ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.[0-9]*.paths" >> corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
		echo "for x in \$(find ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/ -name \"*.paths\"); do outfile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.\${bl}.rids; outfile_p=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.\${bl}.paths; echo \$x >> \${outfile_p}; awk '{if (NF > 4) print \$0}' \$x | ${MARVEL_PATH}/scripts/paths2rids.py - - >> \${outfile_r}; if [[ \$(wc -l < \${outfile_r}) -gt \$max_reads ]]; then bl=\$((bl+1)); fi; done" >> corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
		echo "cat ${FIX_FILT_OUTDIR}/${COR_DB%.db}.tour.[0-9]*.rids | sort -n > ${FIX_FILT_OUTDIR}/${FIX_CORR_PATHS2RIDS_FILE}" >> corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_01_paths2rids_single_${FIX_DB%.db}.${slurmID}.version
    ### LAcorrect
    elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls corr_02_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        setLAcorrectOptions

        for x in $(seq 1 ${fixblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAcorrect${COR_LACORRECT_OPT} -b ${x} ${FIX_FILT_OUTDIR}/${FIX_DB%.db} ${FIX_FILT_OUTDIR}/${FIX_DB%.db}.filt.${x}.las ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/${FIX_DB%.db}.${x}"
        done > corr_02_LAcorrect_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_02_LAcorrect_block_${FIX_DB%.db}.${slurmID}.version
    ### assign reads to database blocks  
    elif [[ ${currentStep} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls corr_03_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions 1
        fi

        bl=0; 
        while [[ 1 ]]; 
        do
        	 bl=$((bl+1)); 
        	 infile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.${bl}.rids;
        	 outfile_b=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.${bl}.bids; 
        	 if [[ ! -f ${infile_r} ]]; 
        	 then 
        	 	break; 
        	 fi; 
        	 if [[ -d ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl} ]]; 
        	 then 
        	 	rm -r ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}; 
        	 fi; 
        	 mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}; 
        	 echo "${MARVEL_PATH}/scripts/ridList2bidList.py ${FIX_FILT_OUTDIR}/${FIX_DB%.db} ${infile_r} > ${outfile_b}; block=1; while [[ \$block -le ${fixblocks} ]]; do grep -e \" \${block}$\" ${outfile_b} | awk '{print \".* source=\"\$1\",.*\"}' > ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/readID_pattern_block_\${block}.txt; block=\$((block+1)); done"
        done > corr_03_rid2bid_block_${FIX_DB%.db}.${slurmID}.plan   
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_03_rid2bid_block_${FIX_DB%.db}.${slurmID}.version                    
    ### prepare seqkit grep reads  
    elif [[ ${currentStep} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls corr_04_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        bl=0; 
        while [[ 1 ]]; 
        do
        	 bl=$((bl+1)); 
        	 infile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.${bl}.rids; 
        	 if [[ ! -f ${infile_r} ]]; 
        	 then 
        	 	break; 
        	 fi; 
        	 y=1; 
        	 while [[ $y -le ${fixblocks} ]]; 
        	 do 
        	 	echo "bfile=${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/readID_pattern_block_${y}.txt; seqkit grep -n -r -f \${bfile} ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/${FIX_DB%.db}.${y}.00.fasta > ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${FIX_DB%.db}.${y}.00.fasta; echo \"${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${FIX_DB%.db}.${y}.00.fasta\" >> ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/reads_block.fofn;"
        	 	y=$((y+1))
        	 done; 
        done > corr_04_seqkitGrep_block_${FIX_DB%.db}.${slurmID}.plan   
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_04_seqkitGrep_block_${FIX_DB%.db}.${slurmID}.version
    ### create separate corrected read DBs  
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls corr_05_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        bl=0; 
        while [[ 1 ]]; 
        do
        	 bl=$((bl+1)); 
        	 infile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.${bl}.rids; 
        	 if [[ ! -f ${infile_r} ]]; 
        	 then 
        	 	break; 
        	 fi; 
        	echo "if [[ -f ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${COR_DB%.db}.db ]]; then ${MARVEL_PATH}/bin/DBrm ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${COR_DB%.db}; fi; ${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace -f ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/reads_block.fofn ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${COR_DB%.db};" 
        done > corr_05_createDB_block_${FIX_DB%.db}.${slurmID}.plan   
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_05_createDB_block_${FIX_DB%.db}.${slurmID}.version        
    elif [[ ${currentStep} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls corr_06_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done
        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions 1
        fi
        setTourToFastaOptions
        

        
        for x in ${FIX_FILT_OUTDIR}/${COR_DIR}/contigs/*.tour.paths
        do 
        	echo "bl=\$(grep -e $x ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.*.paths | awk -F : '{print \$1}' | awk -F . '{print \$(NF-1)}'); ${MARVEL_PATH}/scripts/tour2fasta.py${COR_TOURTOFASTA_OPT} -p $(basename ${x%.tour.paths}) -c ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${COR_DB%.db} ${FIX_FILT_OUTDIR}/${FIX_DB%.db} ${x%.tour.paths}.graphml ${x}" 
        done > corr_06_tour2fasta_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_06_tour2fasta_block_${FIX_DB%.db}.${slurmID}.version
    ### statistics
    elif [[ ${currentStep} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls corr_07_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        if [[ -z ${FILT_LAFILTER_OPT} ]]
        then
            setLAfilterOptions 1
        fi
        
        if [[ -n ${SLURM_STATS} && ${SLURM_STATS} -gt 0 ]]
   		then
	        ### run slurm stats - on the master node !!! Because sacct is not available on compute nodes
	        if [[ $(hostname) == "falcon1" || $(hostname) == "falcon2" ]]
	        then 
	        	bash ${SUBMIT_SCRIPTS_PATH}/slurmStats.sh ${configFile}
	    	else
	        	cwd=$(pwd)
	        	ssh falcon "cd ${cwd} && bash ${SUBMIT_SCRIPTS_PATH}/slurmStats.sh ${configFile}"
	    	fi
		fi
	    	
	    if [[ -n ${MARVEL_STATS} && ${MARVEL_STATS} -gt 0 ]]
   		then
   	    	### create assemblyStats plan 
        	echo "${SUBMIT_SCRIPTS_PATH}/assemblyStats.sh ${configFile} 7" > corr_07_marvelStats_single_${FIX_DB%.db}.${slurmID}.plan
        	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_07_marvelStats_single_${FIX_DB%.db}.${slurmID}.version
    	fi    	
    else
        (>&2 echo "step ${currentStep} in FIX_CORR_TYPE ${FIX_CORR_TYPE} not supported")
        (>&2 echo "valid steps are: ${myTypes[${FIX_CORR_TYPE}]}")
        exit 1            
    fi
#type-2 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 07-LArepeat/LAchain/LAstitch/LAgap, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord 
elif [[ ${FIX_CORR_TYPE} -eq 2 ]]
then 
   	###01-prepareDB
	if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls corr_01_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
    	
    	if [[ ! -f "${CORR_DACCORD_REFFASTA}" ]]
        then
        	(>&2 echo "ERROR - set CORR_DACCORD_REFFASTA to input fasta file")
        	exit 1
   		fi
   				
		if [[ ! -d ${CORR_DACCORD_OUTDIR} ]] 
		then
			(>&2 echo "ERROR - Variable ${CORR_DACCORD_OUTDIR} is not set or cannot be accessed")
        	exit 1
		fi
    	
    	echo "if [[ -d ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} ]]; then mv ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}_$(date '+%Y-%m-%d_%H-%M-%S'); fi && mkdir -p ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}" > corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		
		echo "awk '{print \$1}' ${CORR_DACCORD_REFFASTA} | ${DACCORD_PATH}/bin/fastaidrename -pcontigs > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "samtools faidx ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "grep -e \">\" ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta | sed -e 's:^>::' > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.header" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan

    	### check if input is a Marvel database or a fasta-fofn 
		if [[ ! -f "${CORR_DACCORD_READS}" ]]
        then
        	(>&2 echo "ERROR - set ${CORR_DACCORD_READS} to input db")
        	exit 1
   		fi
   		
   		echo "${MARVEL_PATH}/bin/DBshow ${CORR_DACCORD_READS} | ${DACCORD_PATH}/bin/fastaidrename -preads > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_reads.fasta"  >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
   		
		## create db 
		## 1. add reads
		## marvel 
		echo "${MARVEL_PATH}/bin/FA2db -v -x 0 ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_reads.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
    	echo "${MARVEL_PATH}/bin/DBsplit${DACCORD_DBSPLIT_OPT} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		## dazzler 
		echo "${DAZZLER_PATH}/bin/fasta2DB -v ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_reads.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "${DAZZLER_PATH}/bin/DBsplit${DACCORD_DBSPLIT_OPT} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan               		
		## get number of read blocks
		echo "grep block ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB%.db}.db | awk '{print \$NF}' > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "grep daccord_reads ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB%.db}.db | awk '{print \$1}' > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_reads.txt" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		    		
    	## 2. add contigs 
    	## marvel 
    	echo "${MARVEL_PATH}/bin/FA2db -v -x 0 ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
    	## dazzler 
		echo "${DAZZLER_PATH}/bin/fasta2DB -v ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan

		## 3. adjust blockIDs
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} 		
		
		#echo "cd ${Daccord_DIR}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "cp ${Daccord_DIR}/${DACCORD_DB%.db}.db ${Daccord_DIR}/${DACCORD_DB%.db}.db.bac" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "cp ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.bac" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "found=0; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "for line in \$(seq 1 \$(wc -l < ${Daccord_DIR}/${DACCORD_DB%.db}.db)); " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "do " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo -n "	if [[ \${line} -le 6 && \${line} -ne 4 ]]; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "	then" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo -n "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "	elif [[ \${line} -eq 4 ]]; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "	then" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		printf \"blocks =%10d\\n\" \$(sed -n 4p ${Daccord_DIR}/${DACCORD_DB%.db}.db | awk '{print 1+\$3}') >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		printf \"blocks =%10d\\n\" \$(sed -n 4p ${Daccord_DIR}/${DACCORD_DB%.db}.db | awk '{print 1+\$3}') >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "	else" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo -n "		read_count=\$(sed -n \${line}p ${Daccord_DIR}/${DACCORD_DB%.db}.db | awk '{print \$1}'); " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		if [[ \${read_count} -gt \$(cat ${Daccord_DIR}/number_of_reads.txt) && \${found} -eq 0 ]]; " >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		then" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo -n "			printf \"%10s%10s\\n\" \"\$(cat ${Daccord_DIR}/number_of_reads.txt)\" \"\$(cat ${Daccord_DIR}/number_of_reads.txt)\" >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "			printf \"%10s\\n\" \"\$(cat ${Daccord_DIR}/number_of_reads.txt)\" >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "			found=1;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		fi;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo -n "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan				
		echo -n "	fi;" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan	 			
		echo "done" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "mv ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp ${Daccord_DIR}/${DACCORD_DB%.db}.db" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "mv ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 		
			
		## 4. create daligner sub directories
		echo -n "for x in \$(seq \$((1+\$(cat ${Daccord_DIR}/number_of_readsblocks.txt))) \$(grep block ${Daccord_DIR}/${DACCORD_DB%.db}.db | awk '{print \$NF}'));" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
	    echo -n "do" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo -n "  mkdir -p ${Daccord_DIR}/d\${x} ${Daccord_DIR}/r\${x};" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "done" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan	
			
		echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.version
		echo "samtools $(${CONDA_BASE_ENV} && samtools 2>&1 | grep Version | awk '{print $2}' && conda deactivate)" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.version
   	### 02-DBdust
	elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls corr_02_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
        myCWD=$(pwd)      
		
		### create DBdust commands 
        for x in $(seq 1 ${nCorrblocks})
        do 
            echo "cd ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} && ${MARVEL_PATH}/bin/DBdust ${DACCORD_DB%.db}.${x} && cd ${myCWD}"
            echo "cd ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} && ${DAZZLER_PATH}/bin/DBdust ${DACCORD_DAZZ_DB%.db}.${x} && cd ${myCWD}"
    	done > corr_02_DBdust_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_02_DBdust_block_${FIX_DB%.db}.${slurmID}.version
        echo "DAZZLER $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> corr_02_DBdust_block_${FIX_DB%.db}.${slurmID}.version
	### 03-Catrack
    elif [[ ${currentStep} -eq 3 ]]
    then 
        ### clean up plans 
        for x in $(ls corr_03_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set Catrack options 
        ## setCatrackOptions
        
        myCWD=$(pwd)
        
        ### create Catrack command
        echo "cd ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} && ${MARVEL_PATH}/bin/Catrack -v -f -d ${DACCORD_DB%.db} dust && cd ${myCWD}" > corr_03_Catrack_single_${FIX_DB%.db}.${slurmID}.plan
        echo "cd ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} && ${DAZZLER_PATH}/bin/Catrack  -v -f -d ${DACCORD_DAZZ_DB%.db} dust && cd ${myCWD}" >> corr_03_Catrack_single_${FIX_DB%.db}.${slurmID}.plan
                 
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_03_Catrack_single_${FIX_DB%.db}.${slurmID}.version
        echo "DAZZLER $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> corr_03_Catrack_single_${FIX_DB%.db}.${slurmID}.version
	### 04-datander
    elif [[ ${currentStep} -eq 4 ]]
    then 
        ### clean up plans 
        for x in $(ls corr_04_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        myCWD=$(pwd) 
		setDatanderOptions
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
		
		### create datander commands
        for x in $(seq 1 ${nCorrblocks})
        do 
            echo "cd ${Daccord_DIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/datander${DACCORD_DATANDER_OPT} ${DACCORD_DAZZ_DB%.db}.${x} && cd ${myCWD}"
    	done > corr_04_datander_block_${FIX_DB%.db}.${slurmID}.plan
        echo "DAZZLER datander $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" > corr_04_datander_block_${FIX_DB%.db}.${slurmID}.version		
	### 05-TANmask
    elif [[ ${currentStep} -eq 5 ]]
    then 
        ### clean up plans 
        for x in $(ls corr_05_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        ### find and set TANmask options         
        setTANmaskOptions
        
        myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
		
		
		if [[ -z ${COR_DACCORD_TANMASK_JOBS} ]]
        then 
        	COR_DACCORD_TANMASK_JOBS=50
        fi
        
        for x in $(seq 1 ${COR_DACCORD_TANMASK_JOBS} ${nCorrblocks})
        do 
        	y=$((x+COR_DACCORD_TANMASK_JOBS-1))
        	if [[ $y -gt ${nCorrblocks} ]]
        	then 
        		y=${nCorrblocks}
        	fi        	
        	
            echo "cd ${Daccord_DIR} && ${DAZZLER_PATH}/bin/TANmask${DACCORD_TANMASK_OPT} ${DACCORD_DAZZ_DB%.db} TAN.${DACCORD_DAZZ_DB%.db}.@${x}-${y} && cd ${myCWD}" 
    	done > corr_05_TANmask_block_${FIX_DB%.db}.${slurmID}.plan
        echo "DAZZLER TANmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" > corr_05_TANmask_block_${FIX_DB%.db}.${slurmID}.version
    ### 06-Catrack
    elif [[ ${currentStep} -eq 6 ]]
    then 
        ### clean up plans 
        for x in $(ls corr_06_*_*_${CONT_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set Catrack options
        #if [[ -z ${DACCORD_CATRACK_OPT} ]] 
        #then
        #    setCatrackOptions
        #fi
        
        if [[ -z ${DACCORD_TANMASK_OPT} ]] 
        then
            setTANmaskOptions
        fi
                
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
        
        ### create Catrack command
        echo "cd ${Daccord_DIR} && ${DAZZLER_PATH}/bin/Catrack -v -d -f ${DACCORD_DAZZ_DB%.db} ${COR_DACCORD_TANMASK_TRACK} && cd ${myCWD}" > corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.plan
        echo "cd ${Daccord_DIR} && ${DAZZLER_PATH}/bin/DBdump -r -m${COR_DACCORD_TANMASK_TRACK} ${DACCORD_DAZZ_DB%.db} | awk '{if (\$1 == \"R\") {read=\$2}; if (\$1 == \"T0\" && \$2 > 0) {for (i = 3; i < 3+2*\$2; i+=2) print read-1\" \"\$i\" \"\$(i+1)} }' > ${DACCORD_DAZZ_DB%.db}.${COR_DACCORD_TANMASK_TRACK}.txt && cd ${myCWD}" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.plan
      	echo "cd ${Daccord_DIR} && ${MARVEL_PATH}/bin/txt2track -m ${DACCORD_DB%.db} ${DACCORD_DAZZ_DB%.db}.${COR_DACCORD_TANMASK_TRACK}.txt ${COR_DACCORD_TANMASK_TRACK} && cd ${myCWD}" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.plan
      	echo "cd ${Daccord_DIR} && ${MARVEL_PATH}/bin/TKcombine ${DACCORD_DB%.db} ${COR_DACCORD_TANMASK_TRACK}_dust ${COR_DACCORD_TANMASK_TRACK} dust && cd ${myCWD}" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.plan 
        ### cleanup TAN.*.las 
        echo "cd ${Daccord_DIR} && rm TAN.${DACCORD_DAZZ_DB%.db}.*.las" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.plan
        
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" > corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.version
        echo "LASTOOLS viewmasks $(git --git-dir=${LASTOOLS_SOURCE_PATH}/.git rev-parse --short HEAD)" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.version    
        echo "DAMAR txt2track $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.version
        echo "DAMAR TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >> corr_06_Catrack_single_${FIX_DB%.db}.${slurmID}.version
	### 07-Repeat Masking - only on individual blocks on reads and on all contigs vs contigs
    elif [[ ${currentStep} -eq 7 ]]
    then
        for x in $(ls corr_07_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set daligner options 
        setDaligerOptions
		
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
		
		## create m1 -- mN5
    	for x in $(seq ${firstContigBlock} ${nCorrblocks})
        do             
			echo "cd ${Daccord_DIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DACCORD_DALIGNER_OPT} ${DACCORD_DAZZ_DB%.db}.${x} ${DACCORD_DAZZ_DB%.db}.${x} && mv ${DACCORD_DAZZ_DB%.db}.${x}.${DACCORD_DAZZ_DB%.db}.${x}.las r${x}/ && cd ${myCWD}"
		done > corr_07_daligner_block_${FIX_DB%.db}.${slurmID}.plan
		echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > corr_07_daligner_block_${FIX_DB%.db}.${slurmID}.version
	elif [[ ${currentStep} -eq 8 ]]
    then 
        ### clean up plans 
        for x in $(ls corr_08_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)

	        
        ### create LArepeat commands
        for x in $(seq ${firstContigBlock} ${nCorrblocks})
        do 
            echo "cd ${Daccord_DIR} && ${MARVEL_PATH}/bin/LArepeat -c 5 -l 1.0 -h 1.0 -b ${x} ${DACCORD_DB%.db} r${x}/${DACCORD_DAZZ_DB%.db}.${x}.${DACCORD_DAZZ_DB%.db}.${x}.las && cd ${myCWD}/" 
            echo "cd ${Daccord_DIR} && ${DAZZLER_PATH}/bin/REPmask -v -c5 -nrepeats ${DACCORD_DAZZ_DB%.db} r${x}/${DACCORD_DAZZ_DB%.db}.${x}.${DACCORD_DAZZ_DB%.db}.${x}.las && cd ${myCWD}/"
    	done > corr_08_LArepeat_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_08_LArepeat_block_${FIX_DB%.db}.${slurmID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> corr_08_LArepeat_block_${FIX_DB%.db}.${slurmID}.version
    ### 09-daligner
    elif [[ ${currentStep} -eq 9 ]]
    then
        for x in $(ls corr_09_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set daligner options 
        setDaligerOptions
		
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
		
		
    	for x in $(seq ${firstContigBlock} ${nCorrblocks})
        do             
    		echo -n "cd ${Daccord_DIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DACCORD_DALIGNER_OPT} -mrepeats ${DACCORD_DAZZ_DB%.db}.${x} ${DACCORD_DAZZ_DB%.db}.@1"
            count=0

            for y in $(seq 1 ${lastReadBlock})
            do  
                if [[ $count -lt ${COR_DACCORD_DALIGNER_DAL} ]]
                then
                    count=$((${count}+1))
                else
            		echo -n "-$((y-1))"                   	
					echo -n " && (z=${count}; while [[ \$z -ge 1 ]]; do mv ${DACCORD_DAZZ_DB%.db}.${x}.${DACCORD_DAZZ_DB%.db}.\$(($y-z)).las d${x}; z=\$((z-1)); done)"
                    
					if [[ -z "${COR_DACCORD_DALIGNER_ASYMMETRIC}" ]]
				    then
				    	echo -n " && (z=${count}; while [[ \$z -ge 1 ]]; do if [[ ${x} -ne \$(($y-z)) ]]; then mv ${DACCORD_DAZZ_DB%.db}.\$(($y-z)).${DACCORD_DAZZ_DB%.db}.${x}.las d\$(($y-z)); fi; z=\$((z-1)); done)"						   
				    fi                	
                    
					echo " && cd ${myCWD}"
				    ### if another TMP dir is used, such as a common directory, we have to be sure that output files from jobs on different compute nodes do not collide (happens when the get the same PID)

            		echo -n "cd ${Daccord_DIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DACCORD_DALIGNER_OPT} -mrepeats ${DACCORD_DAZZ_DB%.db}.${x} ${DACCORD_DAZZ_DB%.db}.@${y}"
                    count=1
                fi
            done
	    	echo -n "-${y}"	            	
		    
		    echo -n " && (z=$((count-1)); while [[ \$z -ge 0 ]]; do mv ${DACCORD_DAZZ_DB%.db}.${x}.${DACCORD_DAZZ_DB%.db}.\$(($y-z)).las d${x}; z=\$((z-1)); done)"
                    
			if [[ -z "${COR_DACCORD_DALIGNER_ASYMMETRIC}" ]]
		    then
		    	echo -n " && (z=$((count-1)); while [[ \$z -ge 0 ]]; do if [[ ${x} -ne \$(($y-z)) ]]; then mv ${DACCORD_DAZZ_DB%.db}.\$(($y-z)).${DACCORD_DAZZ_DB%.db}.${x}.las d\$(($y-z)); fi; z=\$((z-1)); done)"						   
		    fi
		    
            echo " && cd ${myCWD}"
    	done > corr_09_daligner_block_${FIX_DB%.db}.${slurmID}.plan
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > corr_09_daligner_block_${FIX_DB%.db}.${slurmID}.version		
	### 10-LAmerge
    elif [[ ${currentStep} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls corr_10_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAmerge options 
        setLAmergeOptions
        
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
        
        ### create LAmerge commands
        for x in $(seq ${firstContigBlock} ${nCorrblocks})
        do 
            echo "cd ${Daccord_DIR} && ${MARVEL_PATH}/bin/LAmerge${DACCORD_LAMERGE_OPT} ${DACCORD_DB%.db} ${DACCORD_DB%.db}.dalign.${x}.las d${x} && ${MARVEL_PATH}/bin/LAfilter -p -R6 ${DACCORD_DB%.db} ${DACCORD_DB%.db}.dalign.${x}.las ${DACCORD_DB%.db}.dalignFilt.${x}.las && cd ${myCWD}"
    	done > corr_10_LAmerge_block_${FIX_DB%.db}.${slurmID}.plan  
        echo "MARVEL LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_10_LAmerge_block_${FIX_DB%.db}.${slurmID}.version
    ### 11-LArepeat 
	elif [[ ${currentStep} -eq 11 ]]
    then    
        ### clean up plans 
        for x in $(ls corr_11_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        setLArepeatOptions 1
        if [[ ${numRepeatTracks} -eq 0 ]]
        then 
            exit 1
        fi    
    
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
    
    
        ### create LArepeat commands
        for y in $(seq ${firstContigBlock} ${nCorrblocks})
        do
        	for x in $(seq 0 $((${numRepeatTracks}-1)))
    		do
        		echo "cd ${Daccord_DIR} && ${MARVEL_PATH}/bin/LArepeat${DACCORD_LAREPEAT_OPT[$x]} -b ${y} ${DACCORD_DB%.db} ${DACCORD_DB%.db}.dalignFilt.${y}.las && cd ${myCWD}/"            		
    		done  		
    	done > corr_11_LArepeat_block_${FIX_DB%.db}.${slurmID}.plan 
        echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" >corr_11_LArepeat_block_${FIX_DB%.db}.${slurmID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> corr_11_LArepeat_block_${FIX_DB%.db}.${slurmID}.version         
    ### 12-LAfilter        
    elif [[ ${currentStep} -eq 12 ]]
    then
        ### clean up plans 
        for x in $(ls corr_12_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLArepeatOptions 1
		setLAfilterOptions 2
        
        if [[ ${numRepeatTracks} -eq 0 ]]
        then 
            exit 1
    	fi
    			    	
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
    
     	if [[ -n ${COR_DACCORD_LAFILTER_REPEAT_IDX} ]]
	    then 	
	        if [[ ${numRepeatTracks} -eq 0 || $((${COR_DACCORD_LAFILTER_REPEAT_IDX}+1)) -gt ${#DACCORD_LAREPEAT_OPT[*]} ]]
	        then 
	            exit 1
	        fi
	    fi
    	
    
        ### create LAfilter commands
        for y in $(seq ${firstContigBlock} ${nCorrblocks})
        do
         	## as we don't merge the block tracks into a global DB track
         	## we need to constract each repeat track individually 
         	my_block_rep_track=${y}.${DACCORD_LAREPEAT_REPEATNAMES[${COR_DACCORD_LAFILTER_REPEAT_IDX}]}
			echo "cd ${Daccord_DIR} && ${MARVEL_PATH}/bin/LAfilter${DACCORD_LAFILTER_OPT} -r ${my_block_rep_track} ${DACCORD_DB%.db} ${DACCORD_DB%.db}.dalignFilt.${y}.las ${DACCORD_DB%.db}.${y}.dalignFiltRep.las && cd ${myCWD}/"
    	done > corr_12_LAfilter_block_${FIX_DB%.db}.${slurmID}.plan 
				
    ### 13-daccord        
    elif [[ ${currentStep} -eq 13 ]]
    then
        ### clean up plans 
        for x in $(ls corr_13_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
		myCWD=$(pwd) 
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}
		
		lastReadBlock=$(cat ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt)
		firstContigBlock=$((1+lastReadBlock))
		nCorrblocks=$(getNumOfDbBlocks ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB%.db}.db)
        
        setDaccordOptions
        
        ## run daccord -eprof
        ## calc 
        for y in $(seq ${firstContigBlock} ${nCorrblocks})
        do
        	cmd1="${DACCORD_PATH}/bin/computeintrinsicqv2 -d$((FIX_COV+FIX_COV)) ${DACCORD_DAZZ_DB%.db} ${DACCORD_DB%.db}.${y}.dalignFiltRep.las"
        	cmd2="${DACCORD_PATH}/bin/daccord ${DACCORD_DACCORD_OPT} --eprofonly ${DACCORD_DB%.db}.${y}.dalignFiltRep.las ${DACCORD_DAZZ_DB%.db}.db"
        	cmd3="${DACCORD_PATH}/bin/daccord ${DACCORD_DACCORD_OPT} ${DACCORD_DB%.db}.${y}.dalignFiltRep.las ${DACCORD_DAZZ_DB%.db}.db > ${DACCORD_DB%.db}.${y}.dalignFiltRep.dac.fasta"
         	echo "cd ${Daccord_DIR} && ${cmd1}  && ${cmd2} && ${cmd3} && cd ${myCWD}/"
    	done > corr_13_daccord_block_${FIX_DB%.db}.${slurmID}.plan 
        
        
    ### 14-stats        
    elif [[ ${currentStep} -eq 14 ]]
    then
		### clean up plans 
        for x in $(ls corr_14_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
    	
    	if [[ -n ${MARVEL_STATS} && ${MARVEL_STATS} -gt 0 ]]
   		then
	        ### create assemblyStats plan
	        echo "${SUBMIT_SCRIPTS_PATH}/assemblyStats.sh ${configFile} 16" > corr_14_marvelStats_single_${FIX_DB%.db}.${slurmID}.plan
	    else 
	     	echo "echo set MARVEL_STATS to 1" > corr_14_marvelStats_single_${FIX_DB%.db}.${slurmID}.plan
		fi
    	
        		
	else
        (>&2 echo "step ${currentStep} in FIX_CORR_TYPE ${FIX_CORR_TYPE} not supported")
        (>&2 echo "valid steps are: ${myTypes[${FIX_CORR_TYPE}]}")
        exit 1            
    fi		
#type-3 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 06a-repcomp, 07-LArepeat/LAchain, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord
#type-4 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 06a-repcomp, 06b-forcealign, 07-LArepeat/LAchain, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord
elif [[ ${FIX_CORR_TYPE} -eq 3 ]]
then 
	if [[ ${currentStep} -eq 1 ]]
    then
		echo "todo"
		    	
    	
    	

	else
        (>&2 echo "step ${currentStep} in FIX_CORR_TYPE ${FIX_CORR_TYPE} not supported")
        (>&2 echo "valid steps are: ${myTypes[${FIX_CORR_TYPE}]}")
        exit 1            
    fi		
    
#type-4 steps: 01-prepareDB, 02-DBdust, 03-datander, 04-TANmask, 05-daliger, 06-LAmerge, 06a-repcomp, 06b-forcealign, 07-LArepeat/LAchain, 08-Lafilter, 09-lassort, 10-computeIntrinsicQV, 11-daccord
elif [[ ${FIX_CORR_TYPE} -eq 4 ]]
then 
   	if [[ ${currentStep} -eq 1 ]]
    then
		echo "not present yet"
	else
        (>&2 echo "step ${currentStep} in FIX_CORR_TYPE ${FIX_CORR_TYPE} not supported")
        (>&2 echo "valid steps are: ${myTypes[${FIX_CORR_TYPE}]}")
        exit 1            
    fi		
    
else
    (>&2 echo "unknown FIX_TOUR_TYPE ${FIX_CORR_TYPE}")
    (>&2 echo "supported types")
    x=0; while [ $x -lt ${#myTypes[*]} ]; do (>&2 echo "type-${x} steps: ${myTypes[${x}]}"); done    
    
    exit 1
fi

exit 0
