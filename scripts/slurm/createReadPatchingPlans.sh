#!/bin/bash 

configFile=$1
currentStep=$2
slurmID=$3

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}

if [[ ! -n "${RAW_PATCH_TYPE}" ]]
then 
    (>&2 echo "cannot create read patching scripts if variable RAW_PATCH_TYPE is not set.")
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

if [[ ${RAW_PATCH_TYPE} -gt 1 && ! -f ${RAW_DAZZ_DB%.db}.db ]]
then 
    (>&2 echo "raw dazzler database ${RAW_DB%.db}.db missing")
    exit 1
fi

function getNumOfDbBlocks()
{
    if [[ ! -f ${RAW_DB%.db}.db ]]
    then
        (>&2 echo "raw database ${RAW_DB%.db}.db not found")
        exit 1
    fi

    blocks=$(grep block ${RAW_DB%.db}.db | awk '{print $3}')
    if [[ ! -n $blocks ]]
    then 
        (>&2 echo "raw database ${RAW_DB%.db}.db has not been partitioned. Run DBsplit first!")
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

function setDalignerOptions()
{
    FIX_DALIGNER_OPT=""
    if [[ -n ${RAW_FIX_DALIGNER_IDENTITY_OVLS} && ${RAW_FIX_DALIGNER_IDENTITY_OVLS} -gt 0 ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -I"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_KMER} && ${RAW_FIX_DALIGNER_KMER} -gt 0 ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -k ${RAW_FIX_DALIGNER_KMER}"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_ERR} ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -e ${RAW_FIX_DALIGNER_ERR}"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_BIAS} && ${RAW_FIX_DALIGNER_BIAS} -eq 1 ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -b"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_VERBOSE} && ${RAW_FIX_DALIGNER_VERBOSE} -ne 0 ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -v"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -gt 0 ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -s ${RAW_FIX_DALIGNER_TRACESPACE}"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_RUNID} ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -r ${RAW_FIX_DALIGNER_RUNID}"
    fi
    if [[ -n ${RAW_FIX_DALIGNER_ASYMMETRIC} && ${RAW_FIX_DALIGNER_ASYMMETRIC} -ne 0 ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -A"
    fi    
    if [[ -n ${RAW_FIX_DALIGNER_T} ]]
    then
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -t ${RAW_FIX_DALIGNER_T}"
    fi  
    if [[ -n ${RAW_FIX_DALIGNER_MASK} ]]
    then
        for x in ${RAW_FIX_DALIGNER_MASK}
        do 
            FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -m ${x}"
        done
    fi
    if [[ -n ${THREADS_daligner} ]]
    then 
        FIX_DALIGNER_OPT="${FIX_DALIGNER_OPT} -j ${THREADS_daligner}"
    fi
    if [ ! -n ${RAW_FIX_DALIGNER_DAL} ]
    then
        RAW_FIX_DALIGNER_DAL=8
    fi 
}

function setRepcompOptions()
{
    FIX_REPCOMP_OPT=""
    if [[ -n ${RAW_FIX_REPCOMP_TRACESPACE} && ${RAW_FIX_REPCOMP_TRACESPACE} -gt 0 ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} --tspace${RAW_FIX_REPCOMP_TRACESPACE}"
    fi
    if [[ -n ${RAW_FIX_REPCOMP_INBLOCKSIZE} ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -i${RAW_FIX_REPCOMP_INBLOCKSIZE}"
    fi
    if [[ -n ${RAW_FIX_REPCOMP_KMER} && ${RAW_FIX_REPCOMP_KMER} -gt 0 ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -k${RAW_FIX_REPCOMP_KMER}"
    fi
    if [[ -n ${RAW_FIX_REPCOMP_MEM} ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -M${RAW_FIX_REPCOMP_MEM}"
    fi
    if [[ -n ${RAW_FIX_REPCOMP_THREADS} && ${RAW_FIX_REPCOMP_THREADS} -gt 0 ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -t${RAW_FIX_REPCOMP_THREADS}"
    fi 
    if [[ -n ${RAW_FIX_REPCOMP_CORRELATION} ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -e${RAW_FIX_REPCOMP_CORRELATION}"
    fi 
    if [[ -n ${RAW_FIX_REPCOMP_MASK} ]]
    then
        for x in ${RAW_FIX_REPCOMP_MASK}
        do 
            FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -m${x}"
        done
    fi
        if [[ -n ${RAW_FIX_REPCOMP_OLEN} && ${RAW_FIX_REPCOMP_OLEN} -gt 0 ]]
    then 
        FIX_REPCOMP_OPT="${FIX_REPCOMP_OPT} -l${RAW_FIX_REPCOMP_OLEN}"
    fi 


    if [[ -z ${RAW_FIX_REPCOMP_RUNID} || ${RAW_FIX_REPCOMP_RUNID} == ${RAW_FIX_DALIGNER_RUNID} ]]
    then
        RAW_FIX_REPCOMP_RUNID=$((${RAW_FIX_DALIGNER_RUNID}+1))
    fi
}

function setLAmergeOptions()
{
    FIX_LAMERGE_OPT=""
    if [[ -n ${RAW_FIX_LAMERGE_NFILES} && ${RAW_FIX_LAMERGE_NFILES} -gt 0 ]]
    then
        FIX_LAMERGE_OPT="${FIX_LAMERGE_OPT} -n ${RAW_FIX_LAMERGE_NFILES}"
    fi
}

function setLArepeatOptions()
{
    ### find and set LArepeat options 
    FIX_LAREPEAT_OPT=""
    if [[ -n ${RAW_FIX_LAREPEAT_LEAVE_COV} ]]
    then
        FIX_LAREPEAT_OPT="${FIX_LAREPEAT_OPT} -l ${RAW_FIX_LAREPEAT_LEAVE_COV}"
    else  # set default value
        RAW_FIX_LAREPEAT_LEAVE_COV=1.7
    fi
    if [[ -n ${RAW_FIX_LAREPEAT_ENTER_COV} ]]
    then
        FIX_LAREPEAT_OPT="${FIX_LAREPEAT_OPT} -h ${RAW_FIX_LAREPEAT_ENTER_COV}"
    else  # set default value
        RAW_FIX_LAREPEAT_ENTER_COV=2.0
    fi
    if [[ -n ${RAW_FIX_LAREPEAT_COV} ]]
    then
        FIX_LAREPEAT_OPT="${FIX_LAREPEAT_OPT} -c ${RAW_FIX_LAREPEAT_COV}"
    fi
    if [[ -n ${RAW_FIX_LAREPEAT_REPEATTRACK} ]]
    then
        FIX_LAREPEAT_OPT="${FIX_LAREPEAT_OPT} -t ${RAW_FIX_LAREPEAT_REPEATTRACK}"
    else
        ptype=""
        if [[ ${RAW_PATCH_TYPE} -eq 0 ]]
        then 
            ptype="_dalign"
        elif [[ ${RAW_PATCH_TYPE} -eq 1 ]]
        then 
            ptype="_repcomp"
        elif [[ ${RAW_PATCH_TYPE} -eq 2 ]]
        then 
            ptype="_forcealign"        
        else
            (>&2 echo "Unknown RAW_PATCH_TYPE=${RAW_PATCH_TYPE} !!!")
            exit 1            
        fi 

        if [[ -n ${RAW_FIX_LAREPEAT_COV} ]]
        then
            RAW_FIX_LAREPEAT_REPEATTRACK=repeats_c${RAW_FIX_LAREPEAT_COV}_l${RAW_FIX_LAREPEAT_LEAVE_COV}h${RAW_FIX_LAREPEAT_ENTER_COV}${ptype}
        else
            RAW_FIX_LAREPEAT_REPEATTRACK=repeats_calCov_l${RAW_FIX_LAREPEAT_LEAVE_COV}h${RAW_FIX_LAREPEAT_ENTER_COV}${ptype}
        fi
        FIX_LAREPEAT_OPT="${FIX_LAREPEAT_OPT} -t ${RAW_FIX_LAREPEAT_REPEATTRACK}"
    fi
}

function setTKmergeOptions() 
{
    FIX_TKMERGE_OPT=""
    if [[ -n ${RAW_FIX_TKMERGE_DELETE} && ${RAW_FIX_TKMERGE_DELETE} -ne 0 ]]
    then
        FIX_TKMERGE_OPT="${FIX_TKMERGE_OPT} -d"
    fi
}

function setTKcombineOptions() 
{
    ignoreDelete=$1
    FIX_TKCOMBINE_OPT=""
    if [[ ${ignoreDelete} -eq 0 && -n ${RAW_FIX_TKCOMBINE_DELETE} && ${RAW_FIX_TKCOMBINE_DELETE} -ne 0 ]]
    then
        FIX_TKCOMBINE_OPT="${FIX_TKCOMBINE_OPT} -d"
    fi
    if [[ -n ${RAW_FIX_TKCOMBINE_VERBOSE} && ${RAW_FIX_TKCOMBINE_VERBOSE} -ne 0 ]]
    then
        FIX_TKCOMBINE_OPT="${FIX_TKCOMBINE_OPT} -v"
    fi
}

function setLAfilterOptions()
{
    FIX_LAFILTER_OPT=""
    if [[ -n ${RAW_FIX_LAFILTER_NREP} && ${RAW_FIX_LAFILTER_NREP} -ne 0 ]]
    then
        FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -n ${RAW_FIX_LAFILTER_NREP}"
    fi
    if [[ -n ${RAW_FIX_LAFILTER_VERBOSE} && ${RAW_FIX_LAFILTER_VERBOSE} -ne 0 ]]
    then
        FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -v"
    fi
    if [[ -n ${RAW_FIX_LAFILTER_PURGE} && ${RAW_FIX_LAFILTER_PURGE} -ne 0 ]]
    then
        FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -p"
    fi
    if [[ -n ${RAW_FIX_LAFILTER_OLEN} && ${RAW_FIX_LAFILTER_OLEN} -ne 0 ]]
    then
        FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -o ${RAW_FIX_LAFILTER_OLEN}"
    fi    
    if [[ -n ${RAW_FIX_LAFILTER_RLEN} && ${RAW_FIX_LAFILTER_RLEN} -ne 0 ]]
    then
        FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -l ${RAW_FIX_LAFILTER_RLEN}"
    fi   

    # we need the name of the repeat track, especially if the plan starts with step8
    if [[ ${RAW_PATCH_TYPE} -eq 0 ]]
    then
       if [[ -z ${FIX_LAREPEAT_OPT} ]]
       then 
            setLArepeatOptions
        fi       
        RAW_FIX_LAFILTER_REPEATTRACK=f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust
        FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -r ${RAW_FIX_LAFILTER_REPEATTRACK}"
    fi
}

function setLAstitchOptions()
{   
    FIX_STITCH_OPT=""
    if [[ -n ${RAW_FIX_LASTITCH_FUZZ} && ${RAW_FIX_LASTITCH_FUZZ} -ne 0 ]]
    then
        FIX_STITCH_OPT="${FIX_STITCH_OPT} -f ${RAW_FIX_LASTITCH_FUZZ}"
    fi
    if [[ -n ${RAW_FIX_LASTITCH_ANCHOR} && ${RAW_FIX_LASTITCH_ANCHOR} -ne 0 ]]
    then
        FIX_STITCH_OPT="${FIX_STITCH_OPT} -a ${RAW_FIX_LASTITCH_ANCHOR}"
    fi
    if [[ -n ${RAW_FIX_LASTITCH_PRELOAD} && ${RAW_FIX_LASTITCH_PRELOAD} -ne 0 ]]
    then
        FIX_STITCH_OPT="${FIX_STITCH_OPT} -L"
    fi
    if [[ -n ${RAW_FIX_LASTITCH_PURGE} && ${RAW_FIX_LASTITCH_PURGE} -ne 0 ]]
    then
        FIX_STITCH_OPT="${FIX_STITCH_OPT} -p"
    fi
    if [[ -n ${RAW_FIX_LASTITCH_LOWCOMPLEXITY} ]]
    then
        FIX_STITCH_OPT="${FIX_STITCH_OPT} -t ${RAW_FIX_LASTITCH_LOWCOMPLEXITY}"
    fi
    if [[ -n ${RAW_FIX_LASTITCH_VERBOSE} ]]
    then
        FIX_STITCH_OPT="${FIX_STITCH_OPT} -v"
    fi
    # we need the name of the repeat track, especially if the plan starts with step9
    if [[ -z ${FIX_LAREPEAT_OPT} ]]
    then 
        setLArepeatOptions
    fi       
    FIX_STITCH_OPT="${FIX_STITCH_OPT} -r f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust"
}

function setLAqOptions()
{
    FIX_LAQ_OPT=""
    adaptQTRIMCUTOFF=""    

    if [[ -n ${RAW_FIX_LAQ_MINSEG} && ${RAW_FIX_LAQ_MINSEG} -ne 0 ]]
    then
        FIX_LAQ_OPT="${FIX_LAQ_OPT} -s ${RAW_FIX_LAQ_MINSEG}"
    else 
        RAW_FIX_LAQ_MINSEG=25
        FIX_LAQ_OPT="${FIX_LAQ_OPT} -s ${RAW_FIX_LAQ_MINSEG}"
    fi

    if [[ -n ${RAW_FIX_LAQ_QTRIMCUTOFF} && ${RAW_FIX_LAQ_QTRIMCUTOFF} -ne 0 ]]
    then
        if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -ne 100 ]]
        then 
            adaptQTRIMCUTOFF=$(echo "${RAW_FIX_LAQ_QTRIMCUTOFF}*${RAW_FIX_DALIGNER_TRACESPACE}/100+1" | bc)
            FIX_LAQ_OPT="${FIX_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"
        else
            adaptQTRIMCUTOFF=${RAW_FIX_LAQ_QTRIMCUTOFF}
            FIX_LAQ_OPT="${FIX_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"            
        fi
    else 
        if [[ -n ${RAW_FIX_DALIGNER_TRACESPACE} && ${RAW_FIX_DALIGNER_TRACESPACE} -ne 100 ]]
        then 
            RAW_FIX_LAQ_QTRIMCUTOFF=25
            adaptQTRIMCUTOFF=$(echo "${RAW_FIX_LAQ_QTRIMCUTOFF}*${RAW_FIX_DALIGNER_TRACESPACE}/100+1" | bc)
            FIX_LAQ_OPT="${FIX_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"
        else
            adaptQTRIMCUTOFF=25
            RAW_FIX_LAQ_QTRIMCUTOFF=25
            FIX_LAQ_OPT="${FIX_LAQ_OPT} -d ${adaptQTRIMCUTOFF}"            
        fi
    fi
}

function setLAfixOptions()
{
    FIX_LAFIX_OPT=""
    if [[ -n ${RAW_FIX_LAFIX_GAP} && ${RAW_FIX_LAQ_MINSEG} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -g ${RAW_FIX_LAFIX_GAP}"
    fi
    if [[ -n ${RAW_FIX_LAFIX_MLEN} && ${RAW_FIX_LAFIX_MLEN} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -x ${RAW_FIX_LAFIX_MLEN}"
    fi
    if [[ -n ${RAW_FIX_LAFIX_LOW_COVERAGE} && ${RAW_FIX_LAFIX_LOW_COVERAGE} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -l"
    fi
    if [[ -n ${RAW_FIX_LAFIX_REPEAT} ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -r${RAW_FIX_LAFIX_REPEAT}"
    fi
    if [[ -n ${RAW_FIX_LAFIX_MAXCHIMERLEN} && ${RAW_FIX_LAFIX_MAXCHIMERLEN} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -C${RAW_FIX_LAFIX_MAXCHIMERLEN}"
    fi
    if [[ -n ${RAW_FIX_LAFIX_MINCHIMERBORDERCOV} && ${RAW_FIX_LAFIX_MINCHIMERBORDERCOV} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -b${RAW_FIX_LAFIX_MINCHIMERBORDERCOV}"
    fi

    if [[ -z ${FIX_LAQ_OPT} ]]
    then
        setLAqOptions
    fi
    if [[ -n ${RAW_FIX_LAFIX_AGGCHIMERDETECT} && ${RAW_FIX_LAFIX_AGGCHIMERDETECT} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -a"
    fi
    if [[ -n ${RAW_FIX_LAFIX_DISCARDCHIMERS} && ${RAW_FIX_LAFIX_DISCARDCHIMERS} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -d"
    fi

    ptype=""
    if [[ ${RAW_PATCH_TYPE} -eq 0 ]]
    then 
        ptype="_dalign"
    elif [[ ${RAW_PATCH_TYPE} -eq 1 ]]
    then 
        ptype="_repcomp"
    elif [[ ${RAW_PATCH_TYPE} -eq 2 ]]
    then 
        ptype="_forcealign"        
    else
        (>&2 echo "Unknown RAW_PATCH_TYPE=${RAW_PATCH_TYPE} !!!")
        exit 1            
    fi 

    FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}${ptype}"

    if [[ -n ${RAW_FIX_LAFIX_TRIM} && ${RAW_FIX_LAFIX_TRIM} -ne 0 ]]
    then
        FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -t trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}${ptype}"
    fi
    
    if [[ -n ${RAW_FIX_LAFIX_CONVERTRACKS} ]]
    then
        for x in ${RAW_FIX_LAFIX_CONVERTRACKS}
        do
            FIX_LAFIX_OPT="${FIX_LAFIX_OPT} -c $x"
        done
    fi

    ### create LAfix commands
    if [[ -z ${RAW_FIX_LAFIX_PATH} ]]
    then
        RAW_FIX_LAFIX_PATH=patchedReads
    fi 
}

function setForcealignOptions()
{
    FIX_FORCEALIGN_OPT=""
    if [[ -n ${RAW_FIX_FORCEALIGN_PARTIAL} && ${RAW_FIX_FORCEALIGN_PARTIAL} -ne 0 ]]
    then
        FIX_FORCEALIGN_OPT="${FIX_FORCEALIGN_OPT} --partial"
    fi
    if [[ -n ${RAW_FIX_FORCEALIGN_THREADS} && ${RAW_FIX_FORCEALIGN_THREADS} -gt 0 ]]
    then 
        FIX_FORCEALIGN_OPT="${FIX_FORCEALIGN_OPT} -t${RAW_FIX_FORCEALIGN_THREADS}"
    fi 
    if [[ -n ${RAW_FIX_FORCEALIGN_MAXDIST} && ${RAW_FIX_FORCEALIGN_MAXDIST} -gt 0 ]]
    then 
        FIX_FORCEALIGN_OPT="${FIX_FORCEALIGN_OPT} --maxdist${RAW_FIX_FORCEALIGN_MAXDIST}"
    fi 
    if [[ -n ${RAW_FIX_FORCEALIGN_BORDER} && ${RAW_FIX_FORCEALIGN_BORDER} -gt 0 ]]
    then 
        FIX_FORCEALIGN_OPT="${FIX_FORCEALIGN_OPT} --border${RAW_FIX_FORCEALIGN_BORDER}"
    fi 
    if [[ -n ${RAW_FIX_FORCEALIGN_CORRELATION} ]]
    then 
        FIX_FORCEALIGN_OPT="${FIX_FORCEALIGN_OPT} --correlation${RAW_FIX_FORCEALIGN_CORRELATION}"
    fi 


    if [[ -z ${RAW_FIX_FORCEALIGN_RUNID} ]]
    then
        if [[ -z ${RAW_FIX_REPCOMP_RUNID} ]]
        then
            RAW_FIX_FORCEALIGN_RUNID=$((${RAW_FIX_DALIGNER_RUNID}+2))
        else 
            RAW_FIX_FORCEALIGN_RUNID=$((${RAW_FIX_REPCOMP_RUNID}+1))
        fi
    fi
}

function setLAseparateOptions()
{
    FIX_LASEPARATE_OPT=""
    if [[ -n ${RAW_FIX_LASEPARATE_OLEN} && ${RAW_FIX_LASEPARATE_OLEN} -gt 0 ]]
    then 
        FIX_LASEPARATE_OPT="${FIX_LASEPARATE_OPT} -o${RAW_FIX_LASEPARATE_OLEN}"
    fi
    if [[ -n ${RAW_FIX_LASEPARATE_RLEN} && ${RAW_FIX_LASEPARATE_RLEN} -gt 0 ]]
    then 
        FIX_LASEPARATE_OPT="${FIX_LASEPARATE_OPT} -l${RAW_FIX_LASEPARATE_RLEN}"
    fi 
    if [[ -n ${RAW_FIX_LASEPARATE_REPEAT} ]]
    then 
        FIX_LASEPARATE_OPT="${FIX_LASEPARATE_OPT} -r${RAW_FIX_LASEPARATE_REPEAT}"
    fi 

    # type is passed as argument
    FIX_LASEPARATE_OPT="${FIX_LASEPARATE_OPT} -T$1"
}

nblocks=$(getNumOfDbBlocks)

#type-0 - steps: 1-daligner, 2-LAmerge, 3-LArepeat, 4-TKmerge, 5-TKcombine, 6-TKhomogenize, 7-TKcombine, 8-LAfilter, 9-LAq, 10-TKmerge, 11-LAfix
if [[ ${RAW_PATCH_TYPE} -eq 0 ]]
then 
    if [[ ${currentStep} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls fix_01_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set daligner options 
        setDalignerOptions
        ### create daligner commands
        cmdLine=1
        for x in $(seq 1 ${nblocks})
        do 

            if [[ -n ${RAW_FIX_DALIGNER_NUMACTL} && ${RAW_FIX_DALIGNER_NUMACTL} -gt 0 ]]
            then
                if [[ $((${cmdLine} % 2)) -eq  0 ]]
                then
                    NUMACTL="numactl -m0 -N0 "
                else
                    NUMACTL="numactl -m1 -N1 "    
                fi
            else
                NUMACTL=""
            fi
            cmd="${NUMACTL}${MARVEL_PATH}/bin/daligner${FIX_DALIGNER_OPT} ${RAW_DB%.db}.${x}"
            cmdLine=$((${cmdLine}+1))
            count=0

            for y in $(seq ${x} ${nblocks})
            do  
                if [[ $count -lt ${RAW_FIX_DALIGNER_DAL} ]]
                then
                    cmd="${cmd} ${RAW_DB%.db}.${y}"
                    count=$((${count}+1))
                else    
                    echo "${cmd}"
                    if [[ -n ${RAW_FIX_DALIGNER_NUMACTL} && ${RAW_FIX_DALIGNER_NUMACTL} -gt 0 ]]
                    then
                        if [[ $((${cmdLine} % 2)) -eq  0 ]]
                        then
                            NUMACTL="numactl -m0 -N0 "
                        else
                            NUMACTL="numactl -m1 -N1 "    
                        fi
                    else
                        NUMACTL=""
                    fi
                    cmd="${NUMACTL}${MARVEL_PATH}/bin/daligner${FIX_DALIGNER_OPT} ${RAW_DB%.db}.${x} ${RAW_DB%.db}.${y}"
                    cmdLine=$((${cmdLine}+1))
                    count=1
                fi
            done
            echo "${cmd}"
        done > fix_01_daligner_block_${RAW_DB%.db}.${slurmID}.plan
    elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls fix_02_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAmerge options 
        setLAmergeOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAmerge${FIX_LAMERGE_OPT} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.dalign.las $(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})"
        done > fix_02_LAmerge_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls fix_03_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        if [ -z ${FIX_LAREPEAT_OPT} ]
        then 
            setLArepeatOptions
        fi
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LArepeat${FIX_LAREPEAT_OPT} -b ${x} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.dalign.las"
        done > fix_03_LArepeat_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls fix_04_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step4
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### find and set TKmerge options 
        if [[ -z ${FIX_TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}" > fix_04_TKmerge_single_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls fix_05_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done     
        # we need the name of the repeat track, especially if the plan starts with step5
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### find and set TKcombine options
        setTKcombineOptions 1
        ### set repmask tracks 
        if [[ ${#RAW_REPMASK_LAREPEAT_COV[*]} -ne ${#RAW_REPMASK_BLOCKCMP[*]} ]]
        then 
            (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: arrays RAW_REPMASK_LAREPEAT_COV and RAW_REPMASK_BLOCKCMP must have same number of elements")
            exit 1
        fi
        RAW_REPMASK_REPEATTRACK=""
        for x in $(seq 1 ${#RAW_REPMASK_BLOCKCMP[*]})
        do
            idx=$(($x-1))
            RAW_REPMASK_REPEATTRACK="${RAW_REPMASK_REPEATTRACK} ${RAW_REPMASK_LAREPEAT_REPEATTRACK}_B${RAW_REPMASK_BLOCKCMP[${idx}]}C${RAW_REPMASK_LAREPEAT_COV[${idx}]}"
        done 
        ### create TKcombine command        
        if [[ -n ${RAW_REPMASK_REPEATTRACK} ]]
        then
            echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_REPEATTRACK}" > fix_05_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        else
            echo "ln -s .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.d2 .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.d2"  > fix_05_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
            echo "ln -s .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.a2 .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.a2"  >> fix_05_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        fi 
    elif [[ ${currentStep} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls fix_06_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step6
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### create TKhomogenize commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/TKhomogenize -i ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} -I h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} -b ${x} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.dalign.las"
        done > fix_06_TKhomogenize_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls fix_07_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step7
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions 
        fi
        ### find and set TKcombine options
        setTKcombineOptions 0
        ### create TKcombine commands
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} \#.h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}" > fix_07_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        ### find and set TKcombine options, but ignore the -d flag if it was set
        setTKcombineOptions 1
        (echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}" 
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_TANMASK_TRACK}" 
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK} dust"
        ) >> fix_07_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan
    elif [[ ${currentStep} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls fix_08_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

        mkdir -p identity
        ### create LAfilter commands - filter out identity overlaps - has to be done because revcomp and forcealign will loose those 
        for x in $(seq 1 ${nblocks})
        do  
            echo "${MARVEL_PATH}/bin/LAfilter -p -R 3 ${RAW_DB%.db} $(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${x}.las identity/${RAW_DB%.db}.${x}.identity.las"
        done > fix_08_LAfilter_block_${RAW_DB%.db}.${slurmID}.plan       
    elif [[ ${currentStep} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls fix_09_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAq${FIX_LAQ_OPT} -T trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_dalign -Q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_dalign ${RAW_DB%.db} -b ${x} ${RAW_DB%.db}.${x}.dalign.las"
        done > fix_09_LAq_block_${RAW_DB%.db}.${slurmID}.plan                 
    elif [[ ${currentStep} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls fix_10_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the q and trim track names, especially if the plan starts with step11
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLAqOptions
        fi  
        if [[ -z ${FIX_TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        (echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_dalign"
        echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_dalign"
        ) > fix_10_TKmerge_block_${RAW_DB%.db}.${slurmID}.plan               
    ### find and set TKmerge options    
    elif [[ ${currentStep} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls fix_11_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions
        mkdir -p ${RAW_FIX_LAFIX_PATH}_dalign

        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAfix${FIX_LAFIX_OPT} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.dalign.las ${RAW_FIX_LAFIX_PATH}_dalign/${RAW_DB%.db}.${x}${RAW_FIX_LAFIX_FILESUFFIX}.fasta"
        done > fix_11_LAfix_block_${RAW_DB%.db}.${slurmID}.plan                 
    else 
        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE} not supported")
        (>&2 echo "valid steps are: #type-0: 1-daligner, 2-LAmerge, 3-LArepeat, 4-TKmerge, 5-TKcombine, 6-TKhomogenize, 7-TKcombine, 8-LAfilter, 9-LAq, 10-TKmerge, 11-LAfix")
        exit 1        
    fi     
#type-1 steps [2-13] : 2-LAseparate, 3-repcomp, 4-LAmerge, 5-LArepeat, 6-TKmerge, 7-TKcombine, 8-TKhomogenize, 9-TKcombine, 10-LAq, 11-TKmerge, 12-LAfix
elif [[ ${RAW_PATCH_TYPE} -eq 1 ]]
then
    if [[ ${currentStep} -eq 1 ]]
    then
        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE} not supported. type-0 must be run in advance")
        exit 1

    #### LAseparate 
    elif [[ ${currentStep} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls fix_02_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

        ### find and set repcomp options 
        setLAseparateOptions 0

        for x in $(seq 1 ${nblocks}); 
        do 
            sdir=$(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})
            mkdir -p ${sdir}_ForRepComp
            mkdir -p ${sdir}_NoRepComp
            for y in $(seq 1 ${nblocks}); 
            do 
                if [[ ! -f ${sdir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ]]
                then
                    (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: File missing ${sdir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las!!")
                    exit 1                    
                fi
                echo "${MARVEL_PATH}/bin/LAseparate${FIX_LASEPARATE_OPT} ${RAW_DB%.db} ${sdir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ${sdir}_ForRepComp/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ${sdir}_NoRepComp/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las"                
            done 
        done > fix_02_LAseparate_block_${RAW_DB%.db}.${slurmID}.plan
    #### repcomp 
    elif [[ ${currentStep} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls fix_03_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set repcomp options 
        setRepcompOptions

        cmdLine=1
        for x in $(seq 1 ${nblocks}); 
        do 
            srcDir=$(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})_ForRepComp
            desDir=$(getSubDirName ${RAW_FIX_REPCOMP_RUNID} ${x})

            if [[ ! -d ${desDir} ]]
            then
                mkdir -p ${desDir}
            fi
            start=${x}

            for y in $(seq ${start} ${nblocks}); 
            do 
                movDir=$(getSubDirName ${RAW_FIX_REPCOMP_RUNID} ${y})
                if [[ -f ${srcDir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ]]
                then 
                    if [[ -n ${RAW_FIX_REPCOMP_NUMACTL} && ${RAW_FIX_REPCOMP_NUMACTL} -gt 0 ]]
                    then
                        if [[ $((${cmdLine} % 2)) -eq  0 ]]
                        then
                            NUMACTL="numactl -m0 -N0 "
                        else
                            NUMACTL="numactl -m1 -N1 "    
                        fi
                    else
                        NUMACTL=""
                    fi
                    echo -n "${NUMACTL}${REMPCOMP_PATH}/bin/repcomp${FIX_REPCOMP_OPT} -T/tmp/${RAW_DB%.db}.${x}.${y} ${desDir}/${RAW_DB%.db}.repcomp.${x}.${y} ${RAW_DAZZ_DB%.db} ${srcDir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las"
                    cmdLine=$((${cmdLine}+1))
                    if [[ $x -eq $y ]]
                    then
                        echo ""
                    else    
                        echo " && mv ${desDir}/${RAW_DB%.db}.repcomp.${x}.${y}_r.las ${movDir}/"
                    fi
                else
                    (>&2 echo "step ${currentStep} in RAW_FIX_TYPE ${RAW_FIX_TYPE}: File missing ${srcDir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las!!")
                    exit 1
                fi
            done 
        done > fix_03_repcomp_block_${RAW_DB%.db}.${slurmID}.plan  
    elif [[ ${currentStep} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls fix_04_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAmerge options 
        setLAmergeOptions
        setRepcompOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAmerge${FIX_LAMERGE_OPT} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.repcomp.las $(getSubDirName ${RAW_FIX_REPCOMP_RUNID} ${x}) $(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})_NoRepComp identity/${RAW_DB%.db}.${x}.identity.las"                                                                                                            
        done > fix_04_LAmerge_block_${RAW_DB%.db}.${slurmID}.plan  
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls fix_05_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        if [ -z ${FIX_LAREPEAT_OPT} ]
        then 
            setLArepeatOptions
        fi
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LArepeat${FIX_LAREPEAT_OPT} -b ${x} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.repcomp.las"
        done > fix_05_LArepeat_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls fix_06_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step4
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### find and set TKmerge options 
        if [[ -z ${FIX_TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}" > fix_06_TKmerge_single_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls fix_07_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done     
        # we need the name of the repeat track, especially if the plan starts with step5
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### find and set TKcombine options
        setTKcombineOptions 1
        ### set repmask tracks 
        if [[ ${#RAW_REPMASK_LAREPEAT_COV[*]} -ne ${#RAW_REPMASK_BLOCKCMP[*]} ]]
        then 
            (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: arrays RAW_REPMASK_LAREPEAT_COV and RAW_REPMASK_BLOCKCMP must have same number of elements")
            exit 1
        fi
        RAW_REPMASK_REPEATTRACK=""
        for x in $(seq 1 ${#RAW_REPMASK_BLOCKCMP[*]})
        do
            idx=$(($x-1))
            RAW_REPMASK_REPEATTRACK="${RAW_REPMASK_REPEATTRACK} ${RAW_REPMASK_LAREPEAT_REPEATTRACK}_B${RAW_REPMASK_BLOCKCMP[${idx}]}C${RAW_REPMASK_LAREPEAT_COV[${idx}]}"
        done 
        ### create TKcombine command        
        if [[ -n ${RAW_REPMASK_REPEATTRACK} ]]
        then
            echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_REPEATTRACK}" > fix_07_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        else
            echo "ln -s .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.d2 .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.d2"  > fix_07_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
            echo "ln -s .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.a2 .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.a2"  >> fix_07_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        fi 
    elif [[ ${currentStep} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls fix_08_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step6
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### create TKhomogenize commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/TKhomogenize -i ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} -I h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} -b ${x} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.repcomp.las"
        done > fix_08_TKhomogenize_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls fix_09_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step7
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions 
        fi
        ### find and set TKcombine options
        setTKcombineOptions 0
        ### create TKcombine commands
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} \#.h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}" > fix_09_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        ### find and set TKcombine options, but ignore the -d flag if it was set
        setTKcombineOptions 1
        (echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}" 
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_TANMASK_TRACK}" 
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK} dust"
        ) >> fix_09_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan    
    elif [[ ${currentStep} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls fix_10_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAq${FIX_LAQ_OPT} -T trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp -Q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp ${RAW_DB%.db} -b ${x} ${RAW_DB%.db}.${x}.repcomp.las"
        done > fix_10_LAq_block_${RAW_DB%.db}.${slurmID}.plan                 
    elif [[ ${currentStep} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls fix_11_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done     
        # we need the name of the q and trim track names, especially if the plan starts with step11
        if [[ -z ${FIX_LAQ_OPT} ]]
        then 
            setLAqOptions
        fi  
        if [[ -z ${FIX_TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        (echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp"
        echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp"
        ) > fix_11_TKmerge_block_${RAW_DB%.db}.${slurmID}.plan               
    elif [[ ${currentStep} -eq 12 ]]
    then
        ### clean up plans 
        for x in $(ls fix_12_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions
        mkdir -p ${RAW_FIX_LAFIX_PATH}_repcomp

        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAfix${FIX_LAFIX_OPT} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.repcomp.las ${RAW_FIX_LAFIX_PATH}_repcomp/${RAW_DB%.db}.${x}${RAW_FIX_LAFIX_FILESUFFIX}.fasta"
        done > fix_12_LAfix_block_${RAW_DB%.db}.${slurmID}.plan                 
    else 
        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE} not supported")
        (>&2 echo "valid steps are: #type-1 steps [2-12] : 2-LAseparate, 3-repcomp, 4-LAmerge, 5-LArepeat, 6-TKmerge, 7-TKcombine, 8-TKhomogenize, 9-TKcombine, 10-LAq, 11-TKmerge, 12-LAfix")
        exit 1        
    fi      
#type-2 steps [3-14]: 3-LAseparate, 4-forcealign, 5-LAmerge, 6-LArepeat, 7-TKmerge, 8-TKcombine, 9-TKhomogenize, 10-TKcombine, 11-LAq, 12-TKmerge, 13-LAfix
elif [[ ${RAW_PATCH_TYPE} -eq 2 ]]
then
    if [[ ${currentStep} -eq 1 ]]
    then
        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE} not supported. type-0 must be run in advance")
        exit 1
    elif [[ ${currentStep} -eq 2 ]]
    then
        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE} not supported. type-1 must be run in advance")
        exit 1

    #### LAseparate 
    elif [[ ${currentStep} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls fix_03_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 

        ### find and set repcomp options 
        setRepcompOptions
        setDalignerOptions
        setLAseparateOptions 1

        for x in $(seq 1 ${nblocks}); 
        do 
            sdir=$(getSubDirName ${RAW_FIX_REPCOMP_RUNID} ${x})
            mkdir -p ${sdir}_ForForceAlign
            mkdir -p ${sdir}_NoForceAlign
            for y in $(seq 1 ${nblocks}); 
            do 
                infile=""
                if [[ $x -le $y ]]
                then    
                    infile=${RAW_DB%.db}.repcomp.${x}.${y}_f.las 

                    if [[ ! -f ${sdir}/${infile} ]]
                    then
                        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: File missing ${sdir}/${infile}!!")
                        exit 1                    
                    fi
                    echo "${MARVEL_PATH}/bin/LAseparate${FIX_LASEPARATE_OPT} ${RAW_DB%.db} ${sdir}/${infile} ${sdir}_ForForceAlign/${infile} ${sdir}_NoForceAlign/${infile}"                
                fi
                if [[ $x -ge $y ]]
                then    
                    infile=${RAW_DB%.db}.repcomp.${y}.${x}_r.las 

                    if [[ ! -f ${sdir}/${infile} ]]
                    then
                        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: File missing ${sdir}/${infile}!!")
                        exit 1                    
                    fi
                    echo "${MARVEL_PATH}/bin/LAseparate${FIX_LASEPARATE_OPT} ${RAW_DB%.db} ${sdir}/${infile} ${sdir}_ForForceAlign/${infile} ${sdir}_NoForceAlign/${infile}"                
                fi
            done
        done > fix_03_LAseparate_block_${RAW_DB%.db}.${slurmID}.plan
        for x in $(seq 1 ${nblocks}); 
        do 
            sdir=$(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})_NoRepComp
            mkdir -p ${sdir}_ForForceAlign
            mkdir -p ${sdir}_NoForceAlign
            for y in $(seq 1 ${nblocks}); 
            do 
                if [[ ! -f ${sdir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ]]
                then
                    (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: File missing ${sdir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las!!")
                    exit 1                    
                fi
                echo "${MARVEL_PATH}/bin/LAseparate${FIX_LASEPARATE_OPT} ${RAW_DB%.db} ${sdir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ${sdir}_ForForceAlign/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las ${sdir}_NoForceAlign/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las"                
            done
        done >> fix_03_LAseparate_block_${RAW_DB%.db}.${slurmID}.plan          
    #### forcealign 
    elif [[ ${currentStep} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls fix_04_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set repcomp options 
        setDalignerOptions
        setRepcompOptions
        setForcealignOptions

        cmdLine=1
        for x in $(seq 1 ${nblocks}); 
        do 
            srcDir=$(getSubDirName ${RAW_FIX_REPCOMP_RUNID} ${x})_ForForceAlign
            desDir=$(getSubDirName ${RAW_FIX_FORCEALIGN_RUNID} ${x})

            if [[ ! -d ${desDir} ]]
            then
                mkdir -p ${desDir}
            fi
            start=${x}

            for y in $(seq ${start} ${nblocks}); 
            do 
                movDir=$(getSubDirName ${RAW_FIX_FORCEALIGN_RUNID} ${y})
                inFile=${srcDir}/${RAW_DB%.db}.repcomp.${x}.${y}_f.las

                if [[ -f ${inFile} ]]
                then 
                    if [[ -n ${RAW_FIX_FORCEALIGN_NUMACTL} && ${RAW_FIX_FORCEALIGN_NUMACTL} -gt 0 ]]
                    then
                        if [[ $((${cmdLine} % 2)) -eq  0 ]]
                        then
                            NUMACTL="numactl -m0 -N0 "
                        else
                            NUMACTL="numactl -m1 -N1 "    
                        fi
                    else
                        NUMACTL=""
                    fi
                    echo -n "${NUMACTL}${DACCORD_PATH}/bin/forcealign${FIX_FORCEALIGN_OPT} -T/tmp/${RAW_DB%.db}.forcealign.${x}.${y} ${desDir}/${RAW_DB%.db}.forcealign.${x}.${y} ${RAW_DAZZ_DB%.db} ${inFile}"
                    cmdLine=$((${cmdLine}+1))
                    if [[ $x -eq $y ]]
                    then
                        echo ""
                    else    
                        echo " && mv ${desDir}/${RAW_DB%.db}.forcealign.${x}.${y}_r.las ${movDir}"
                    fi
                else
                    (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: File missing ${inFile}!!")
                    exit 1
                fi
            done 
        done > fix_04_forcealign_block_${RAW_DB%.db}.${slurmID}.plan  
        for x in $(seq 1 ${nblocks}); 
        do 
            srcDir=$(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})_NoRepComp_ForForceAlign
            desDir=$(getSubDirName ${RAW_FIX_FORCEALIGN_RUNID} ${x})

            if [[ ! -d ${desDir} ]]
            then
                mkdir -p ${desDir}
            fi
            start=${x}

            for y in $(seq ${start} ${nblocks}); 
            do 
                movDir=$(getSubDirName ${RAW_FIX_FORCEALIGN_RUNID} ${y})
                inFile=${srcDir}/${RAW_DB%.db}.${x}.${RAW_DB%.db}.${y}.las
                
                if [[ -f ${inFile} ]]
                then 
                    if [[ -n ${RAW_FIX_FORCEALIGN_NUMACTL} && ${RAW_FIX_FORCEALIGN_NUMACTL} -gt 0 ]]
                    then
                        if [[ $((${cmdLine} % 2)) -eq  0 ]]
                        then
                            NUMACTL="numactl -m0 -N0 "
                        else
                            NUMACTL="numactl -m1 -N1 "    
                        fi
                    else
                        NUMACTL=""
                    fi
                    echo -n "${NUMACTL}${DACCORD_PATH}/bin/forcealign${FIX_FORCEALIGN_OPT} -T/tmp/${RAW_DB%.db}.norepcomp.forcealign.${x}.${y} ${desDir}/${RAW_DB%.db}.norepcomp.forcealign.${x}.${y} ${RAW_DAZZ_DB%.db} ${inFile}"
                    cmdLine=$((${cmdLine}+1))
                    if [[ $x -eq $y ]]
                    then
                        echo ""
                    else    
                        echo " && mv ${desDir}/${RAW_DB%.db}.norepcomp.forcealign.${x}.${y}_r.las ${movDir}"
                    fi
                else
                    (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: File missing ${inFile}!!")
                    exit 1
                fi
            done 
        done >> fix_04_forcealign_block_${RAW_DB%.db}.${slurmID}.plan
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls fix_05_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAmerge options 
        setLAmergeOptions
        setRepcompOptions
        setForcealignOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAmerge${FIX_LAMERGE_OPT} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.forcealign.las $(getSubDirName ${RAW_FIX_FORCEALIGN_RUNID} ${x}) $(getSubDirName ${RAW_FIX_REPCOMP_RUNID} ${x})_NoForceAlign $(getSubDirName ${RAW_FIX_DALIGNER_RUNID} ${x})_NoRepComp_NoForceAlign identity/${RAW_DB%.db}.${x}.identity.las"                                                                                                            
        done > fix_05_LAmerge_block_${RAW_DB%.db}.${slurmID}.plan  
    elif [[ ${currentStep} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls fix_06_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        if [ -z ${FIX_LAREPEAT_OPT} ]
        then 
            setLArepeatOptions
        fi
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LArepeat${FIX_LAREPEAT_OPT} -b ${x} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.forcealign.las"
        done > fix_06_LArepeat_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls fix_07_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step4
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### find and set TKmerge options 
        if [[ -z ${FIX_TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}" > fix_07_TKmerge_single_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls fix_08_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done     
        # we need the name of the repeat track, especially if the plan starts with step5
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### find and set TKcombine options
        setTKcombineOptions 1
        ### set repmask tracks 
        if [[ ${#RAW_REPMASK_LAREPEAT_COV[*]} -ne ${#RAW_REPMASK_BLOCKCMP[*]} ]]
        then 
            (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE}: arrays RAW_REPMASK_LAREPEAT_COV and RAW_REPMASK_BLOCKCMP must have same number of elements")
            exit 1
        fi
        RAW_REPMASK_REPEATTRACK=""
        for x in $(seq 1 ${#RAW_REPMASK_BLOCKCMP[*]})
        do
            idx=$(($x-1))
            RAW_REPMASK_REPEATTRACK="${RAW_REPMASK_REPEATTRACK} ${RAW_REPMASK_LAREPEAT_REPEATTRACK}_B${RAW_REPMASK_BLOCKCMP[${idx}]}C${RAW_REPMASK_LAREPEAT_COV[${idx}]}"
        done 
        ### create TKcombine command        
        if [[ -n ${RAW_REPMASK_REPEATTRACK} ]]
        then
            echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_REPEATTRACK}" > fix_08_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        else
            echo "ln -s .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.d2 .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.d2"  > fix_08_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
            echo "ln -s .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.a2 .${RAW_DB%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.a2"  >> fix_08_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        fi 
    elif [[ ${currentStep} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls fix_09_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step6
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions
        fi
        ### create TKhomogenize commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/TKhomogenize -i ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} -I h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} -b ${x} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.forcealign.las"
        done > fix_09_TKhomogenize_block_${RAW_DB%.db}.${slurmID}.plan         
    elif [[ ${currentStep} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls fix_10_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the repeat track, especially if the plan starts with step7
        if [[ -z ${FIX_LAREPEAT_OPT} ]]
        then 
            setLArepeatOptions 
        fi
        ### find and set TKcombine options
        setTKcombineOptions 0
        ### create TKcombine commands
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} \#.h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}" > fix_10_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan         
        ### find and set TKcombine options, but ignore the -d flag if it was set
        setTKcombineOptions 1
        (echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} h${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}" 
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_TANMASK_TRACK}" 
        echo "${MARVEL_PATH}/bin/TKcombine${FIX_TKCOMBINE_OPT} ${RAW_DB%.db} f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust f${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK} dust"
        ) >> fix_10_TKcombine_single_${RAW_DB%.db}.${slurmID}.plan    
    elif [[ ${currentStep} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls fix_11_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAq${FIX_LAQ_OPT} -T trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_forcealign -Q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_forcealign ${RAW_DB%.db} -b ${x} ${RAW_DB%.db}.${x}.forcealign.las"
        done > fix_11_LAq_block_${RAW_DB%.db}.${slurmID}.plan                 
    elif [[ ${currentStep} -eq 12 ]]
    then
        ### clean up plans 
        for x in $(ls fix_12_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done     
        # we need the name of the q and trim track names, especially if the plan starts with step11
        if [[ -z ${FIX_LAQ_OPT} ]]
        then 
            setLAqOptions
        fi  
        if [[ -z ${FIX_TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        (echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_forcealign"
        echo "${MARVEL_PATH}/bin/TKmerge${FIX_TKMERGE_OPT} ${RAW_DB%.db} q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_forcealign"
        ) > fix_12_TKmerge_block_${RAW_DB%.db}.${slurmID}.plan               
    elif [[ ${currentStep} -eq 13 ]]
    then
        ### clean up plans 
        for x in $(ls fix_13_*_*_${RAW_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions
        mkdir -p ${RAW_FIX_LAFIX_PATH}_forcealign

        for x in $(seq 1 ${nblocks})
        do 
            echo "${MARVEL_PATH}/bin/LAfix${FIX_LAFIX_OPT} ${RAW_DB%.db} ${RAW_DB%.db}.${x}.forcealign.las ${RAW_FIX_LAFIX_PATH}_forcealign/${RAW_DB%.db}.${x}${RAW_FIX_LAFIX_FILESUFFIX}.fasta"
        done > fix_13_LAfix_block_${RAW_DB%.db}.${slurmID}.plan                 
    else 
        (>&2 echo "step ${currentStep} in RAW_PATCH_TYPE ${RAW_PATCH_TYPE} not supported")
        (>&2 echo "valid steps are: #type-2 steps [3-14]: 3-LAseparate, 4-forcealign, 5-LAmerge, 6-LArepeat, 7-TKmerge, 8-TKcombine, 9-TKhomogenize, 10-TKcombine, 11-LAq, 12-TKmerge, 13-LAfix")
        exit 1        
    fi     
else
    echo "unknown RAW_PATCH_TYPE ${RAW_PATCH_TYPE}"
    exit 1
fi

exit 0