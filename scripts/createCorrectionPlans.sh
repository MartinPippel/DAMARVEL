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
#type-0 steps: 1-paths2rids, 2-LAcorrect, 3-prepDB, 4-tour2fasta, 5-statistics ### for BIG genomes, we need to create several corrected databases 
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

        #echo "bl=0; while [[ 1 ]]; do bl=\$((bl+1)); infile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.\${bl}.rids; if [[ ! -f \${infile_r} ]]; then break; fi; if [[ -d ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl} ]]; then rm -r ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}; fi; mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}; for x in \$(cat \${infile_r}); do blockID=\$(${MARVEL_PATH}/scripts/rid2bid.py ${FIX_FILT_OUTDIR}/${FIX_DB%.db} \${x}); echo \".* source=\${x},.*\" >> ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/readID_pattern_block_\${blockID}.txt; done; y=1; while [[ \$y -lt ${fixblocks} ]]; do bfile=${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/readID_pattern_block_\${y}.txt; seqkit grep -n -r -f \${bfile} ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/${FIX_DB%.db}.\${y}.00.fasta > ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${FIX_DB%.db}.\${y}.00.fasta; echo \"${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${FIX_DB%.db}.\${y}.00.fasta\" >> ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/reads_block.fofn; done; ${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace -f ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/reads_block.fofn ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${COR_DB%.db}; done" > corr_03_createDB_block_${FIX_DB%.db}.${slurmID}.plan
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
        	 while [[ $y -lt ${fixblocks} ]]; 
        	 do 
        	 	echo "bfile=${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/readID_pattern_block_${y}.txt; seqkit grep -n -r -f \${bfile} ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/${FIX_DB%.db}.${y}.00.fasta > ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${FIX_DB%.db}.${y}.00.fasta; echo \"${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${FIX_DB%.db}.${y}.00.fasta\" >> ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/reads_block.fofn;"
        	 	y=$((y+1))
        	 done; 
        #	 ${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace -f ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/reads_block.fofn ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${COR_DB%.db}; 
        done > corr_04_seqkitGrep_block_${FIX_DB%.db}.${slurmID}.plan   
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_04_seqkitGrep_block_${FIX_DB%.db}.${slurmID}.version
    ### prepare seqkit grep reads  
    elif [[ ${currentStep} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls corr_05_*_*_${FIX_DB%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done

        #echo "bl=0; while [[ 1 ]]; do bl=\$((bl+1)); infile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.\${bl}.rids; if [[ ! -f \${infile_r} ]]; then break; fi; if [[ -d ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl} ]]; then rm -r ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}; fi; mkdir -p ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}; for x in \$(cat \${infile_r}); do blockID=\$(${MARVEL_PATH}/scripts/rid2bid.py ${FIX_FILT_OUTDIR}/${FIX_DB%.db} \${x}); echo \".* source=\${x},.*\" >> ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/readID_pattern_block_\${blockID}.txt; done; y=1; while [[ \$y -lt ${fixblocks} ]]; do bfile=${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/readID_pattern_block_\${y}.txt; seqkit grep -n -r -f \${bfile} ${FIX_FILT_OUTDIR}/${COR_DIR}/reads/${FIX_DB%.db}.\${y}.00.fasta > ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${FIX_DB%.db}.\${y}.00.fasta; echo \"${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${FIX_DB%.db}.\${y}.00.fasta\" >> ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/reads_block.fofn; done; ${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace -f ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/reads_block.fofn ${FIX_FILT_OUTDIR}/${COR_DIR}/part_\${bl}/${COR_DB%.db}; done" > corr_03_createDB_block_${FIX_DB%.db}.${slurmID}.plan
        bl=0; 
        while [[ 1 ]]; 
        do
        	 bl=$((bl+1)); 
        	 infile_r=${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.${bl}.rids; 
        	 if [[ ! -f ${infile_r} ]]; 
        	 then 
        	 	break; 
        	 fi; 
			echo "${MARVEL_PATH}/bin/FA2db -x0 -c source -c correctionq -c postrace -f ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/reads_block.fofn ${FIX_FILT_OUTDIR}/${COR_DIR}/part_${bl}/${COR_DB%.db};" 
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
        	echo "bl=\$(grep -e $x ${FIX_FILT_OUTDIR}/${COR_DIR}/${COR_DB%.db}.tour.*.paths | awk -F : '{print \$1}' | awk -F . '{print \$(NF-1)}'); ${MARVEL_PATH}/scripts/tour2fasta.py${COR_TOURTOFASTA_OPT} -p $(basename ${x%.tour.paths}) -c ${FIX_FILT_OUTDIR}/${FIX_DB%.db}/part_\${bl}/${COR_DB%.db} ${FIX_FILT_OUTDIR}/${FIX_DB%.db} ${x%.tour.paths}.graphml ${x}" 
        done > corr_04_tour2fasta_block_${FIX_DB%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_04_tour2fasta_block_${FIX_DB%.db}.${slurmID}.version
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
        	echo "${SUBMIT_SCRIPTS_PATH}/assemblyStats.sh ${configFile} 7" > corr_05_marvelStats_single_${FIX_DB%.db}.${slurmID}.plan
        	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > corr_05_marvelStats_single_${FIX_DB%.db}.${slurmID}.version
    	fi    	
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
