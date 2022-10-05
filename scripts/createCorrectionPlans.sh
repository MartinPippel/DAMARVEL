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

function setLAfilterOptions()
{
    FILT_LAFILTER_OPT=""

    if [[ -z ${FIX_FILT_OUTDIR} ]]
    then
        FIX_FILT_OUTDIR="m1"
    fi
    
    ## its never used, but the variable is set once the function called for the first time
    FILT_LAFILTER_OPT="-v"    
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
        setLAfilterOptions
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

        setLAfilterOptions
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
            setLAfilterOptions
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
            setLAfilterOptions
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
            setLAfilterOptions
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

        setLAfilterOptions
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
            setLAfilterOptions
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
            setLAfilterOptions
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
            setLAfilterOptions
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
		echo "${MARVEL_PATH}/bin/FA2db -v ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_reads.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
    	echo "${MARVEL_PATH}/bin/DBsplit${DACCORD_DBSPLIT_OPT} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		## dazzler 
		echo "${DAZZLER_PATH}/bin/fasta2DB -v ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_reads.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "${DAZZLER_PATH}/bin/DBsplit${DACCORD_DBSPLIT_OPT} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan               		
		## get number of read blocks
		echo "grep block ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB%.db}.db | awk '{print \$NF}' > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_readsblocks.txt" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "grep daccord_reads ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB%.db}.db | awk '{print \$1}' > ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/number_of_reads.txt" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		    		
    	## 2. add contigs 
    	## marvel 
    	echo "${MARVEL_PATH}/bin/FA2db -v ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
    	## dazzler 
		echo "${DAZZLER_PATH}/bin/fasta2DB -v ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/${DACCORD_DAZZ_DB} ${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID}/daccord_contigs.fasta" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan

		## 3. adjust blockIDs
		Daccord_DIR=${CORR_DACCORD_OUTDIR}/daccord_${CORR_DACCORD_RUNID} 		
		
		#echo "cd ${Daccord_DIR}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "cp ${Daccord_DIR}/${DACCORD_DB%.db}.db ${Daccord_DIR}/${DACCORD_DB%.db}.db.bac" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "cp ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.bac" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "found=0" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "for line in \$(seq 1 \$(wc -l < ${Daccord_DIR}/${DACCORD_DB%.db}.db))" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "do" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "	if [[ \${line} -le 6 && \${line} -ne 4 ]]" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "	then" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "	elif [[ \${line} -eq 4 ]]" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "	then" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		printf \"blocks =%10d\\n\" \$(sed -n 4p ${DACCORD_DB%.db}.db | awk '{print 1+\$3}') >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		printf \"blocks =%10d\\n\" \$(sed -n 4p ${DACCORD_DB%.db}.db | awk '{print 1+\$3}') >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "	else" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "		read_count=\$(sed -n \${line}p ${Daccord_DIR}/${DACCORD_DB%.db}.db | awk '{print \$1}')" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		if [[ \${read_count} -gt \$(cat ${Daccord_DIR}/number_of_reads.txt) && \${found} -eq 0 ]]" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		then" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "			printf \"%10s%10s\\n\" \"\$(cat ${Daccord_DIR}/number_of_reads.txt)\" \"\$(cat ${Daccord_DIR}/number_of_reads.txt)\" >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "			printf \"%10s\\n\" \"\$(cat ${Daccord_DIR}/number_of_reads.txt)\" >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "			found=1" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		fi" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "		sed -n \${line}p ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db >> ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan				
		echo "	fi" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan	 			
		echo "done" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 
		echo "mv ${Daccord_DIR}/${DACCORD_DB%.db}.db.tmp ${Daccord_DIR}/${DACCORD_DB%.db}.db" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "mv ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db.tmp ${Daccord_DIR}/${DACCORD_DAZZ_DB%.db}.db" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan 		
			
		## 4. create daligner sub directories
		echo "for x in \$(seq \$((1+\$(cat ${Daccord_DIR}/number_of_readsblocks.txt))) \$(grep block ${Daccord_DIR}/${DACCORD_DB%.db}.db | awk '{print \$NF}'))" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
	    echo "do" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
		echo "  mkdir -p ${Daccord_DIR}/d\${x}" >> corr_01_prepInFasta_single_${FIX_DB%.db}.${slurmID}.plan
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
    ### 07-daligner
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
		
		
    	for x in $(seq ${firstContigBlock} ${nCorrblocks})
        do             
    		echo -n "cd ${Daccord_DIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DACCORD_DALIGNER_OPT} ${DACCORD_DAZZ_DB%.db}.${x} ${DACCORD_DAZZ_DB%.db}.@1"
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

            		echo -n "cd ${Daccord_DIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} ${DAZZLER_PATH}/bin/daligner${DACCORD_DALIGNER_OPT} ${DACCORD_DAZZ_DB%.db}.${x} ${DACCORD_DAZZ_DB%.db}.@${y}"
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
    	done > corr_07b_daligner_block_${FIX_DB%.db}.${slurmID}.plan
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > corr_07_daligner_block_${FIX_DB%.db}.${slurmID}.version		
	### 08-LAmerge
    elif [[ ${currentStep} -eq 8 ]]
    then
        ### clean up plans 
        for x in corr_08_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
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
            echo "cd ${FIX_DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge${DACCORD_LAMERGE_OPT} ${DACCORD_DB%.db} ${DACCORD_DB%.db}.dalign.${x}.las d${x} && ${MARVEL_PATH}/bin/LAfilter -p -R6 ${DACCORD_DB%.db} ${DACCORD_DB%.db}.dalign.${x}.las ${DACCORD_DB%.db}.dalignFilt.${x}.las && cd ${myCWD}"
    	done > corr_08_LAmerge_block_${FIX_DB%.db}.${slurmID}.plan  
        echo "MARVEL LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_08_LAmerge_block_${FIX_DB%.db}.${slurmID}.version       
				
		
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
