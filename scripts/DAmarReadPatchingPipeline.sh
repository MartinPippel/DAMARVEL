#!/bin/bash -e

#call: DAmarReadPatchingPipeline.sh ${configFile} ${pipelineType} ${pipelineStepIdx} ${pipelineRunID}"

echo "[INFO] DAmarReadPatchingPipeline.sh - called with following $# args: $@"

if [[ $# -ne 4 ]]
then 
	(>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh.sh: invalid number of arguments: $# Expected 4! ");
   	exit 1
fi

configFile=$1
pipelineName="fix"
pipelineType=$2
pipelineStepIdx=$3
pipelineRunID=$4

if [[ ! -f ${configFile} ]]
then 
    (>&2 echo "[ERROR] DAmarReadPatchingPipeline.sh: cannot access config file ${configFile}")
    exit 1
fi

source ${configFile}
source ${SUBMIT_SCRIPTS_PATH}/DAmar.cfg ${configFile}
### todo: how to handle more than slurm??? 
source ${SUBMIT_SCRIPTS_PATH}/slurm.cfg ${configFile}

pipelineStepName=$(getStepName ${pipelineName} ${pipelineType} ${pipelineStepIdx})
echo -e "[DEBUG] DAmarReadPatchingPipeline.sh: getStepName \"${pipelineName}\" \"${pipelineType}\" \"${pipelineStepIdx}\" --> ${pipelineStepName}"

setDabaseName

if [[ ! -n "${pipelineType}" ]]
then 
    (>&2 echo "cannot create read patching scripts if variable pipelineType is not set.")
    exit 1
fi

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

## 1st argument ptype


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

# first argument LAseparate type
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
    if [[ -n ${RAW_FIX_LASEPARATE_USEREPEAT} ]]
    then 
    	ptype=""
    	if [[ "$1" -eq 0 ]]
    	then 
    		ptype="dalign"
    	elif [[ "$1" -eq 1 ]]
    	then 
    		ptype="repcomp"
    	fi
    	RAW_FIX_LASEPARATE_REPEAT="repeats_c${RAW_COV}_l${RAW_FIX_LAREPEAT_LEAVE_COV}h${RAW_FIX_LAREPEAT_ENTER_COV}_${ptype}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust"
        FIX_LASEPARATE_OPT="${FIX_LASEPARATE_OPT} -r${RAW_FIX_LASEPARATE_REPEAT}"
    fi 

    # type is passed as argument
    FIX_LASEPARATE_OPT="${FIX_LASEPARATE_OPT} -T$1"
}

function setlassortOptions()
{
	FIX_LASSORT_OPT=""
	
	if [[ -z ${RAW_FIX_LASSORT_THREADS} ]]
	then 
		RAW_FIX_LASSORT_THREADS=8
	fi	
	FIX_LASSORT_OPT="${FIX_LASSORT_OPT} -t${RAW_FIX_LASSORT_THREADS}"
	
	if [[ -z ${RAW_FIX_LASSORT_MERGEFAN} ]]
	then 
		RAW_FIX_LASSORT_MERGEFAN=64
	fi	
	FIX_LASSORT_OPT="${FIX_LASSORT_OPT} -f${RAW_FIX_LASSORT_MERGEFAN}"

	if [[ -z ${RAW_FIX_LASSORT_SORT} ]]
	then 
		RAW_FIX_LASSORT_SORT=full
	fi	
	FIX_LASSORT_OPT="${FIX_LASSORT_OPT} -s${RAW_FIX_LASSORT_SORT}"
}

function setLAfilterOptions()
{
	FIX_LAFILTER_OPT=""
	
	if [[ -z "${RAW_FIX_LAFILTER_PURGE}" ]]
	then
		RAW_FIX_LAFILTER_PURGE=1	
	fi 
	
	if [[ ${RAW_FIX_LAFILTERCHAINS_ANCHOR} -gt 0 ]]
	then 
		FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -p"
	fi
	
	if [[ -z "${RAW_FIX_LAFILTER_MAXSEGERR}" ]]
	then
		RAW_FIX_LAFILTER_MAXSEGERR=65	
	fi 
	
	if [[ ${RAW_FIX_LAFILTER_MAXSEGERR} -gt 0 ]]
	then 
		FIX_LAFILTER_OPT="${FIX_LAFILTER_OPT} -b ${RAW_FIX_LAFILTER_MAXSEGERR}"
	fi
}

function setLAfilterChainsOptions()
{
	FIX_LAFILTERCHAINS_OPT=""
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_ANCHOR} && ${RAW_FIX_LAFILTERCHAINS_ANCHOR} -gt 0 ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -n ${RAW_FIX_LAFILTERCHAINS_ANCHOR}"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_PURGE} && ${RAW_FIX_LAFILTERCHAINS_PURGE} -gt 0 ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -p"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_NKEEPCHAINS} ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -k ${RAW_FIX_LAFILTERCHAINS_NKEEPCHAINS}"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_LOWCOMP} ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -l ${RAW_FIX_LAFILTERCHAINS_LOWCOMP}"
	fi
	
	# add default trim and q tracks
	
	if [[ "${RAW_DACCORD_INDIR}" == "${RAW_REPCOMP_OUTDIR}" ]]
	then
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -t trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp -q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp"	
	else
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -t trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_dalign -q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_dalign"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_UNALIGNBASES} && ${RAW_FIX_LAFILTERCHAINS_UNALIGNBASES} -gt 0 ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -u ${RAW_FIX_LAFILTERCHAINS_UNALIGNBASES}"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_DIFF} && ${RAW_FIX_LAFILTERCHAINS_DIFF} -gt 0 ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -d ${RAW_FIX_LAFILTERCHAINS_DIFF}"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_CHAINLEN} && ${RAW_FIX_LAFILTERCHAINS_CHAINLEN} -gt 0 ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -o ${RAW_FIX_LAFILTERCHAINS_CHAINLEN}"
	fi
	
	if [[ -n ${RAW_FIX_LAFILTERCHAINS_FULLDISCAREADLEN} && ${RAW_FIX_LAFILTERCHAINS_FULLDISCAREADLEN} -gt 0 ]]
	then 
		FIX_LAFILTERCHAINS_OPT="${FIX_LAFILTERCHAINS_OPT} -Z ${RAW_FIX_LAFILTERCHAINS_FULLDISCAREADLEN}"
	fi
	
}

function setDaccordOptions()
{
	FIX_DACCORD_OPT=""
	
	if [[ -z ${RAW_FIX_DACCORD_THREADS} ]]
	then 
		RAW_FIX_DACCORD_THREADS=8
	fi
	FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -t${RAW_FIX_DACCORD_THREADS}"
	
	if [[ -n ${RAW_FIX_DACCORD_WINDOW} && ${RAW_FIX_DACCORD_WINDOW} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -w${RAW_FIX_DACCORD_WINDOW}"
	fi

	if [[ -n ${RAW_FIX_DACCORD_ADVANCESIZE} && ${RAW_FIX_DACCORD_ADVANCESIZE} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -a${RAW_FIX_DACCORD_ADVANCESIZE}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_MAXDEPTH} && ${RAW_FIX_DACCORD_MAXDEPTH} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -d${RAW_FIX_DACCORD_MAXDEPTH}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_FULLSEQ} && ${RAW_FIX_DACCORD_FULLSEQ} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -f1"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_VEBOSE} && ${RAW_FIX_DACCORD_VEBOSE} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -V${RAW_FIX_DACCORD_VEBOSE}"
	fi
		
	if [[ -n ${RAW_FIX_DACCORD_MINWINDOWCOV} && ${RAW_FIX_DACCORD_MINWINDOWCOV} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -m${RAW_FIX_DACCORD_MINWINDOWCOV}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_MINWINDOWERR} && ${RAW_FIX_DACCORD_MINWINDOWERR} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -e${RAW_FIX_DACCORD_MINWINDOWERR}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_MINOUTLEN} && ${RAW_FIX_DACCORD_MINOUTLEN} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -l${RAW_FIX_DACCORD_MINOUTLEN}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_MINKFREQ} && ${RAW_FIX_DACCORD_MINKFREQ} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} --minfilterfreq${RAW_FIX_DACCORD_MINKFREQ}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_MAXKFREQ} && ${RAW_FIX_DACCORD_MAXKFREQ} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} --maxfilterfreq${RAW_FIX_DACCORD_MAXKFREQ}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_MAXOVLS} && ${RAW_FIX_DACCORD_MAXOVLS} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -D${RAW_FIX_DACCORD_MAXOVLS}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_VARD} && ${RAW_FIX_DACCORD_VARD} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} --vard${RAW_FIX_DACCORD_VARD}"
	fi
	
	if [[ -n ${RAW_FIX_DACCORD_KMER} && ${RAW_FIX_DACCORD_KMER} -gt 0 ]]
	then 
		FIX_DACCORD_OPT="${FIX_DACCORD_OPT} -k${RAW_FIX_DACCORD_KMER}"
	fi
}

function setHaploSplitOptions()
{
	FIX_SPLIT_OPT=""
	
	if [[ -z "${RAW_FIX_SPLIT_TYPE}" ]]
	then 
		RAW_FIX_SPLIT_TYPE=split_agr		
	fi
	
	if [[ "${RAW_FIX_SPLIT_TYPE}" != "split_agr" && "${RAW_FIX_SPLIT_TYPE}" != "split_dis" ]]
	then
		(>&2 echo "ERROR - Split type not supported. (split_agr or split_dis)")
    	exit 1
	fi
	
	FIX_SPLIT_OPT="${RAW_FIX_SPLIT_TYPE}"
	
	if [[ -z "${RAW_FIX_SPLIT_THREADS}" ]]
	then
		RAW_FIX_SPLIT_THREADS=8
	fi
	
	FIX_SPLIT_OPT="${FIX_SPLIT_OPT} -t${RAW_FIX_SPLIT_THREADS}"	
	
	if [[ -n "${RAW_FIX_SPLIT_SEQDEPTH}" && ${RAW_FIX_SPLIT_SEQDEPTH} -gt 0 ]]
	then
		FIX_SPLIT_OPT="${FIX_SPLIT_OPT} -d${RAW_FIX_SPLIT_SEQDEPTH}"
	fi
	
	if [[ -n "${RAW_FIX_SPLIT_PHASETHRESHOLD}" ]]
	then
		FIX_SPLIT_OPT="${FIX_SPLIT_OPT} -p${RAW_FIX_SPLIT_PHASETHRESHOLD}"
	fi
	
	if [[ -n "${RAW_FIX_SPLIT_MAXALNS}" && ${RAW_FIX_SPLIT_MAXALNS} -gt 0 ]]
	then
		FIX_SPLIT_OPT="${FIX_SPLIT_OPT} -D${RAW_FIX_SPLIT_MAXALNS}"
	fi
		
	### for split split_dis there are further options available
	if [[ -n ${RAW_FIX_SPLIT_DIFFRATE} ]]
	then 
		FIX_SPLIT_OPT="${FIX_SPLIT_OPT} --drate${RAW_FIX_SPLIT_DIFFRATE}"
	fi
	
	if [[ -n ${RAW_FIX_SPLIT_NUMVARS} ]]
	then 
		FIX_SPLIT_OPT="${FIX_SPLIT_OPT} --kv${RAW_FIX_SPLIT_NUMVARS}"
	fi

	if [[ -n ${RAW_FIX_SPLIT_PHASETYPE} ]]
	then 
		FIX_SPLIT_OPT="${FIX_SPLIT_OPT} --phasetype${RAW_FIX_SPLIT_PHASETYPE}"
	fi
	
	
}


#type-0 - steps[1-10]: 01-createSubdir, 02-daligner, 03-LAmerge, 04-LArepeat, 05-TKmerge, 06-TKcombine, 07-LAfilter, 08-LAq, 09-TKmerge, 10-LAfix
#type-1 - steps[1-10]: 01-createSubdir, 02-LAseparate, 03-repcomp, 04-LAmerge, 05-LArepeat, 06-TKmerge, 07-TKcombine, 08-LAq, 09-TKmerge, 10-LAfix
#type-2 - steps[1-17]: 01-createSubdir, 02-lassort2, 03-computeIntrinsicQV, 04_Catrack, 05_lasdetectsimplerepeats, 06_mergeAndSortRepeats, 07_lasfilteralignments, 08_mergesym2, 09_filtersym, 10_lasfilteralignmentsborderrepeats, 11_mergesym2, 12_filtersym, 13_filterchainsraw, 14_LAfilterChains, 15_LAfilter, 16_split, 16_LAmerge, 17_LAfix
#type-3 - steps[1-1]:  01_patchStats 
if [[ ${pipelineType} -eq 0 ]]
then 
	if [[ ${pipelineStepIdx} -eq 0 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        echo -e "if [[ -d ${DALIGN_OUTDIR} ]]; then mv ${DALIGN_OUTDIR} ${DALIGN_OUTDIR}_\$(stat --format='%Y' ${DALIGN_OUTDIR} | date '+%Y-%m-%d_%H-%M-%S'); fi" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	if [[ "${PACBIO_TYPE}" == "LoFi" ]]
       	then
       		echo -e "mkdir ${DALIGN_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.bps ${DALIGN_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.bps ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_Z}.db ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/lofi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/lofi/db/run/${DB_M}.db ${DALIGN_OUTDIR}/"
       		echo -e "cd ${myCWD}"
        else
       		echo -e "mkdir ${DALIGN_OUTDIR}"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.bps ${DALIGN_OUTDIR}/"
       		echo -e "ln -s -r ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.bps ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_Z}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_Z}.db ${DALIGN_OUTDIR}/"
       		echo -e "cp ../${INIT_DIR}/pacbio/hifi/db/run/.${DB_M}.idx ../${INIT_DIR}/pacbio/hifi/db/run/${DB_M}.db ${DALIGN_OUTDIR}/"
       		echo -e "cd ${myCWD}"       		
       	fi >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
       	
		for x in $(seq 1 ${nblocks})
	    do
			echo "mkdir -p ${DALIGN_OUTDIR}/d${x}"
		done >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		
		setRunInfo ${SLURM_PARTITION} sequential 1 2048 00:30:00 -1 -1 > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set daligner options 
        setDalignerOptions -1  ## use all available repeat tracks
        ### create daligner commands
        cmdLine=1
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ "x${DALIGNER_VERSION}" == "x2" ]]
        	then
        		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${x}"
			else
        		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x}"
			fi
            cmdLine=$((${cmdLine}+1))
            count=0

            for y in $(seq ${x} ${nblocks})
            do  
                if [[ $count -lt ${DALIGNER_BLOCKCMP} ]]
                then
                    count=$((${count}+1))
                    if [[ "x${DALIGNER_VERSION}" != "x2" ]]
            		then    
                    	echo -n " ${DB_Z%.db}.${y}"
                    fi
                else
                	if [[ "x${DALIGNER_VERSION}" == "x2" ]]
            		then    
                   		echo -n "-$((y-1)) && mv"
                	else
                		echo -n " && mv"
                	fi
                    
                    z=${count}
		    		while [[ $z -ge 1 ]]
		    		do
						echo -n " ${DB_Z%.db}.${x}.${DB_Z%.db}.$((y-z)).las"
						z=$((z-1))
		    		done
		    		echo -n " d${x}"
				    if [[ -z "${DALIGNER_ASYMMETRIC}" ]]
				    then
						z=${count}
			            while [[ $z -ge 1 ]]
		        	    do
							if [[ ${x} -ne $((y-z)) ]]
							then
		                    	echo -n " && mv ${DB_Z%.db}.$((y-z)).${DB_Z%.db}.${x}.las d$((y-z))"
							fi
		                    z=$((z-1)) 
		            	done   
				    fi
				    echo " && cd ${myCWD}"
                    if [[ "x${DALIGNER_VERSION}" == "x2" ]]
            		then
                    		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.@${y}"
                	else
                		echo -n "cd ${DALIGN_OUTDIR} && PATH=${DAZZLER_PATH}/bin:\${PATH} daligner${DALIGNER_OPT} ${DB_Z%.db}.${x} ${DB_Z%.db}.${y}"
                	fi
                    cmdLine=$((${cmdLine}+1))
                    count=1
                fi
            done
	    if [[ "x${DALIGNER_VERSION}" == "x2" ]]	
	    then
            	echo -n "-${y} && mv"
	    else
		echo -n " && mv"
	    fi
            z=$((count-1))
                    while [[ $z -ge 0 ]]
                    do
                        echo -n " ${DB_Z%.db}.${x}.${DB_Z%.db}.$((y-z)).las"
                        z=$((z-1))
                    done
                    echo -n " d${x}"
                    if [[ -z "${DALIGNER_ASYMMETRIC}" ]]
                    then
                        z=$((count-1))
                        while [[ $z -ge 0 ]]
                        do
                                if [[ ${x} -ne $((y-z)) ]]
                                then
                                   echo -n " && mv ${DB_Z%.db}.$((y-z)).${DB_Z%.db}.${x}.las d$((y-z))"
                                fi
                                z=$((z-1))
                        done
                    fi
                    echo " && cd ${myCWD}"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAZZLER daligner $(git --git-dir=${DAZZLER_SOURCE_PATH}/DALIGNER/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAmerge options 
        setLAmergeOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.dalign.${x}.las d${x} && ${MARVEL_PATH}/bin/LAfilter -p -R6 ${DB_M%.db} ${DB_Z%.db}.dalign.${x}.las ${DB_Z%.db}.dalignFilt.${x}.las && rm ${DB_Z%.db}.dalign.${x}.las && cd ${myCWD}"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara 
        echo "DAmar LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version             	       
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        setLArepeatOptions 0
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.dalignFilt.${x}.las && cd ${myCWD}/"
            echo "cd ${DALIGN_OUTDIR} && ${DAZZLER_PATH}/bin/REPmask -v -c${REPEAT_COV[0]} -n${REPEAT_TRACK[0]} ${DB_Z%.db} ${DB_Z%.db}.dalignFilt.${x}.las && cd ${myCWD}/"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan 
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version        
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
		# we need the name of the repeat track, especially if the plan starts with step4
        setLArepeatOptions ${pipelineName} -1
        ### find and set TKmerge options
        setTKmergeOptions
        
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	### create TKmerge command
        	echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} ${REPEAT_TRACK[${x}]} && cp .${DB_M%.db}.${REPEAT_TRACK[${x}]}.a2 .${DB_M%.db}.${REPEAT_TRACK[${x}]}.d2 ${myCWD} && cd ${myCWD}"      
        	echo "cd ${DALIGN_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${TKMERGE_OPT} -f -v ${DB_Z%.db} ${REPEAT_TRACK[${x}]} && cp .${DB_Z%.db}.${REPEAT_TRACK[${x}]}.anno .${DB_Z%.db}.${REPEAT_TRACK[${x}]}.data ${myCWD}/ && cd ${myCWD}/"
        	x=$((x+1))
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version   
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        repeatTracks=""     
        # we need the name of the repeat track, especially if the plan starts with step5
        setLArepeatOptions rmask -1
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	repeatTracks="${repeatTrack} ${#REPEAT_TRACK[${x}]}"
        	x=$(($x+1))
        done

        setLArepeatOptions ${pipelineName} -1
        x=0
        while [[ $x -lt ${#REPEAT_TRACK[@]} ]] 
        do
        	repeatTracks="${repeatTrack} ${#REPEAT_TRACK[${x}]}"
        	x=$(($x+1))
        done        
        
        ### find and set TKcombine options
        setTKcombineOptions 0
        
        echo "${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} combinedRep_pType${pipelineType} ${repeatTracks}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} combinedRep_pType${pipelineType}_tan_dust combinedRep_${pipelineType} tan dust" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara         
        echo "DAmar TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version         
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

        mkdir -p identity
        ### create LAfilter commands - filter out identity overlaps - has to be done because revcomp and forcealign will loose those 
        for x in $(seq 1 ${nblocks})
        do  
            echo "${MARVEL_PATH}/bin/LAfilter -p -R 3 -R 6 ${DB_M%.db} ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${x}.las identity/${DB_Z%.db}.identity.${x}.las"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
		getSlurmRunParameter ${pipelineStepName}
		setRunInfo ${SLURM_RUN_PARA[0]} sequential ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara   
    	echo "DAmar LAfilter $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version    
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
		### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/LAq${LAQ_OPT} -T trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} -Q q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} ${DB_M%.db} -b ${x} ${DB_Z%.db}.dalignFilt.${x}.las && cd ${myCWD}"
		done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar LAq $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version                
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        # we need the name of the q and trim track names, especially if the plan starts with step11
        setLAqOptions
        setTKmergeOptions
        
		### create TKmerge command
        echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType} && cp .${DB_M%.db}.trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.a2 .${DB_M%.db}.trim0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.d2 ${myCWD}/ && cd ${myCWD}" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
        echo "cd ${DALIGN_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}n && cp .${DB_M%.db}.q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.a2 .${DB_M%.db}.q0_d${LAQ_QCUTOFF}_s${LAQ_MINSEG}_pType${pipelineType}.d2 ${myCWD}/ && cd ${myCWD}" >> ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan       
        setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
        echo "DAmar TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version	
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions
        
    	mkdir -p patchedReads_pType${pipelineType}
		
		addOpt=""
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ -n ${LAFIX_TRIMFILE} ]]
        	then 
        		addOpt="-T${LAFIX_TRIMFILE}_${x}.txt "
        	fi
            echo "${MARVEL_PATH}/bin/LAfix${LAFIX_OPT} ${addOpt}${DB_M%.db} ${DALIGN_OUTDIR}/${DB_Z%.db}.dalignFilt.${x}.las patchedReads_pType${pipelineType}/${DB_M%.db}.${x}${RAW_FIX_LAFIX_FILESUFFIX}.fasta"
    	done > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.plan
    	setRunInfo ${SLURM_RUN_PARA[0]} parallel ${SLURM_RUN_PARA[1]} ${SLURM_RUN_PARA[2]} ${SLURM_RUN_PARA[3]} ${SLURM_RUN_PARA[4]} ${SLURM_RUN_PARA[5]} > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.slurmPara
    	echo "DAmar LAfix $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.version                 
    fi     
#type-1 steps   [ 1-1] :  01-createSubdir, 02-LAseparate, 03-repcomp, 04-LAmerge, 05-LArepeat, 06-TKmerge, 07-TKcombine, 08-LAq, 09-TKmerge, 10-LAfix     
elif [[ ${pipelineType} -eq 1 ]]
then
	if [[ ${pipelineStepIdx} -eq 1 ]]
    then
		### clean up plans 
	    for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
	    do            
	        rm $x
	    done 
	    
	    echo "if [[ -d ${RAW_REPCOMP_OUTDIR} ]]; then mv ${RAW_REPCOMP_OUTDIR} ${RAW_REPCOMP_OUTDIR}_$(date '+%Y-%m-%d_%H-%M-%S'); fi && mkdir ${RAW_REPCOMP_OUTDIR} && ln -s -r .${DB_M%.db}.* ${DB_M%.db}.db .${DB_Z%.db}.* ${DB_Z%.db}.db ${RAW_REPCOMP_OUTDIR}" > fix_${sID}_createSubdir_single_${DB_M%.db}.${slurmID}.plan
		for x in $(seq 1 ${nblocks})
	    do
			echo "mkdir -p ${RAW_REPCOMP_OUTDIR}/r${x} ${RAW_REPCOMP_OUTDIR}/d${x}_ForRepComp ${RAW_REPCOMP_OUTDIR}/d${x}_NoRepComp"
		done >> fix_${sID}_createSubdir_single_${DB_M%.db}.${slurmID}.plan
	    echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_createSubdir_single_${DB_M%.db}.${slurmID}.version
  	#### LAseparate
  	elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

        ### find and set LAseparate options 
        setLAseparateOptions 0

        for x in $(seq 1 ${nblocks}); 
        do 
            for y in $(seq 1 ${nblocks}); 
            do 
                if [[ ! -f ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ]]
                then
                    (>&2 echo "step ${pipelineStepIdx} in pipelineType ${pipelineType}: File missing ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las!!")
                    exit 1                    
                fi
                echo "${MARVEL_PATH}/bin/LAseparate${FIX_LASEPARATE_OPT} ${DB_M%.db} ${DALIGN_OUTDIR}/d${x}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ${RAW_REPCOMP_OUTDIR}/d${x}_ForRepComp/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ${RAW_REPCOMP_OUTDIR}/d${x}_NoRepComp/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las"                
            done 
    	done > fix_${sID}_LAseparate_block_${DB_M%.db}.${slurmID}.plan
    	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_LAseparate_block_${DB_M%.db}.${slurmID}.version
    #### repcomp 
    elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set repcomp options 
        setRepcompOptions

        cmdLine=1
        for x in $(seq 1 ${nblocks}); 
        do 
            srcDir=${RAW_REPCOMP_OUTDIR}/d${x}_ForRepComp
            desDir=${RAW_REPCOMP_OUTDIR}/r${x}

            if [[ ! -d ${desDir} ]]
            then
                mkdir -p ${desDir}
            fi
            start=${x}

            for y in $(seq ${start} ${nblocks}); 
            do 
                movDir=${RAW_REPCOMP_OUTDIR}/r${y}
                if [[ -f ${srcDir}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las ]]
                then 
                    echo -n "${REPCOMP_PATH}/bin/repcomp${FIX_REPCOMP_OPT} -T/tmp/${DB_Z%.db}.${x}.${y} ${desDir}/${DB_Z%.db}.repcomp.${x}.${y} ${DB_Z%.db} ${srcDir}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las"
                    cmdLine=$((${cmdLine}+1))
                    if [[ $x -eq $y ]]
                    then
                        echo ""
                    else    
                        echo " && mv ${desDir}/${DB_Z%.db}.repcomp.${x}.${y}_r.las ${movDir}/"
                    fi
                else
                    (>&2 echo "step ${pipelineStepIdx} in RAW_FIX_TYPE ${RAW_FIX_TYPE}: File missing ${srcDir}/${DB_Z%.db}.${x}.${DB_Z%.db}.${y}.las!!")
                    exit 1
                fi
            done 
		done > fix_${sID}_repcomp_block_${DB_M%.db}.${slurmID}.plan
    	echo "repcomp $(git --git-dir=${REPCOMP_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_repcomp_block_${DB_M%.db}.${slurmID}.version
	### 04_LAmergeLAfilter
    elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set LAmerge options 
        setLAmergeOptions
        setRepcompOptions
        ### create LAmerge commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/LAmerge${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.repcomp.${x}.las r${x} d${x}_ForRepComp d${x}_NoRepComp ${myCWD}/identity/${DB_Z%.db}.identity.${x}.las && ${MARVEL_PATH}/bin/LAfilter -p -R6 ${DB_M%.db} ${DB_Z%.db}.repcomp.${x}.las ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}"                                                                                                                     
    	done > fix_${sID}_LAmerge_block_${DB_M%.db}.${slurmID}.plan
    	echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_LAmerge_block_${DB_M%.db}.${slurmID}.version      
    ### 05_LArepeat
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        setLArepeatOptions 2
        ### create LArepeat commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/LArepeat${FIX_LAREPEAT_OPT} -b ${x} ${DB_M%.db} ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}/"
            echo "cd ${RAW_REPCOMP_OUTDIR} && ${DAZZLER_PATH}/bin/REPmask -v -c${RAW_DAZZ_FIX_LAREPEAT_THRESHOLD} -n${RAW_DAZZ_FIX_LAREPEAT_REPEATTRACK} ${DB_Z%.db} ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}/"
            
    	done > fix_${sID}_LArepeat_block_${DB_M%.db}.${slurmID}.plan
    	echo "MARVEL LArepeat $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_LArepeat_block_${DB_M%.db}.${slurmID}.version
    	echo "DAZZLER REPmask $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAMASKER/.git rev-parse --short HEAD)" >> fix_${sID}_LArepeat_block_${DB_M%.db}.${slurmID}.version
    ### 06_TKmerge         
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        # we need the name of the repeat track, especially if the plan starts with step4
        setLArepeatOptions 2
        ### find and set TKmerge options 
        if [[ -z ${TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        echo "cd ${RAW_REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK} && cp .${DB_M%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.a2 .${DB_M%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.d2 ${myCWD} && cd ${myCWD}" > fix_${sID}_TKmerge_single_${DB_M%.db}.${slurmID}.plan      
        echo "cd ${RAW_REPCOMP_OUTDIR} && ${DAZZLER_PATH}/bin/Catrack${TKMERGE_OPT} -f -v ${DB_Z%.db} ${RAW_DAZZ_FIX_LAREPEAT_REPEATTRACK} && cp .${DB_Z%.db}.${RAW_DAZZ_FIX_LAREPEAT_REPEATTRACK}.anno .${DB_Z%.db}.${RAW_DAZZ_FIX_LAREPEAT_REPEATTRACK}.data ${myCWD}/ && cd ${myCWD}/" >> fix_${sID}_TKmerge_single_${DB_M%.db}.${slurmID}.plan
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_TKmerge_single_${DB_M%.db}.${slurmID}.version
        echo "DAZZLER Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" >> fix_${sID}_TKmerge_single_${DB_M%.db}.${slurmID}.version
    ### 07_TKcombine   
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done     
        # we need the name of the repeat track, especially if the plan starts with step5
        setLArepeatOptions 2
        ### find and set TKcombine options
        setTKcombineOptions 1
        ### set repmask tracks 
        if [[ ${#RAW_REPMASK_LAREPEAT_COV[*]} -ne ${#RAW_REPMASK_BLOCKCMP[*]} ]]
        then 
            (>&2 echo "step ${pipelineStepIdx} in pipelineType ${pipelineType}: arrays RAW_REPMASK_LAREPEAT_COV and RAW_REPMASK_BLOCKCMP must have same number of elements")
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
            echo "${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_FIX_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_REPEATTRACK}" > fix_${sID}_TKcombine_single_${DB_M%.db}.${slurmID}.plan
            echo "${MARVEL_PATH}/bin/TKcombine${TKCOMBINE_OPT} ${DB_M%.db} ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_TANMASK_TRACK}_dust ${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK} ${RAW_REPMASK_TANMASK_TRACK} dust" >> fix_${sID}_TKcombine_single_${DB_M%.db}.${slurmID}.plan         
        else
            echo "ln -s .${DB_M%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.d2 .${DB_M%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.d2"  > fix_${sID}_TKcombine_single_${DB_M%.db}.${slurmID}.plan         
            echo "ln -s .${DB_M%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}.a2 .${DB_M%.db}.${RAW_FIX_LAREPEAT_REPEATTRACK}_${RAW_REPMASK_LAREPEAT_REPEATTRACK}.a2"  >> fix_${sID}_TKcombine_single_${DB_M%.db}.${slurmID}.plan         
        fi 
        echo "MARVEL TKcombine $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_TKcombine_single_${DB_M%.db}.${slurmID}.version
    ### 08_LAq  
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        ### find and set LAq options 
        setLAqOptions
        ### create LAq commands
        for x in $(seq 1 ${nblocks})
        do 
            echo "cd ${RAW_REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/LAq${FIX_LAQ_OPT} -T trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp -Q q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp ${DB_M%.db} -b ${x} ${DB_Z%.db}.repcompFilt.${x}.las && cd ${myCWD}"
		done > fix_${sID}_LAq_block_${DB_M%.db}.${slurmID}.plan
    	echo "MARVEL LAq $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_LAq_block_${DB_M%.db}.${slurmID}.version
	### 09_TKmerge    	                 
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done  
           
        # we need the name of the q and trim track names, especially if the plan starts with step11
        if [[ -z ${FIX_LAQ_OPT} ]]
        then 
            setLAqOptions
        fi  
        if [[ -z ${TKMERGE_OPT} ]]
        then 
            setTKmergeOptions
        fi
        ### create TKmerge command
        echo "cd ${RAW_REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp && cp .${DB_M%.db}.trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp.a2 .${DB_M%.db}.trim0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp.d2 ${myCWD}/ && cd ${myCWD}" > fix_${sID}_TKmerge_block_${DB_M%.db}.${slurmID}.plan
        echo "cd ${RAW_REPCOMP_OUTDIR} && ${MARVEL_PATH}/bin/TKmerge${TKMERGE_OPT} ${DB_M%.db} q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp&& cp .${DB_M%.db}.q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp.a2 .${DB_M%.db}.q0_d${RAW_FIX_LAQ_QTRIMCUTOFF}_s${RAW_FIX_LAQ_MINSEG}_repcomp.d2 ${myCWD}/ && cd ${myCWD}" >> fix_${sID}_TKmerge_block_${DB_M%.db}.${slurmID}.plan
        echo "MARVEL TKmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_TKmerge_block_${DB_M%.db}.${slurmID}.version               
   ### 10 LAfix
    elif [[ ${pipelineStepIdx} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls fix_10_*_*_${DB_M%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options 
        setLAfixOptions repcomp
        mkdir -p ${RAW_FIX_LAFIX_PATH}
		addopt=""
        for x in $(seq 1 ${nblocks})
        do 
        	if [[ -n ${RAW_FIX_LAFIX_TRIMFILEPREFIX} ]]
        	then 
        		addopt="-T${RAW_FIX_LAFIX_TRIMFILEPREFIX}_${x}.txt "
        	fi
            echo "${MARVEL_PATH}/bin/LAfix${FIX_LAFIX_OPT} ${addopt}${DB_M%.db} ${RAW_REPCOMP_OUTDIR}/${DB_Z%.db}.repcompFilt.${x}.las ${RAW_FIX_LAFIX_PATH}/${DB_M%.db}.${x}${RAW_FIX_LAFIX_FILESUFFIX}.fasta"
		done > fix_10_LAfix_block_${DB_M%.db}.${slurmID}.plan
    	echo "MARVEL LAfix $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_10_LAfix_block_${DB_M%.db}.${slurmID}.version                                  
    else 
        (>&2 echo "step ${pipelineStepIdx} in pipelineType ${pipelineType} not supported")
        (>&2 echo "valid steps are: ${myTypes[${pipelineType}]}")
        exit 1        
    fi  
elif [[ ${pipelineType} -eq 2 ]]
then 
	
	if [[ -z "${RAW_DACCORD_INDIR}" ]]
	then
		RAW_DACCORD_INDIR=${DALIGN_OUTDIR}	
	fi
	
	fsuffix="dalignFilt"
	if [[ "${RAW_DACCORD_INDIR}" == "${RAW_REPCOMP_OUTDIR}" ]]
	then
		fsuffix="repcompFilt"
	fi	
	
    ### create sub-directory and link relevant DB and Track files
    if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
    for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done                 

    	echo "if [[ -d ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} ]]; then mv ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR}_$(date '+%Y-%m-%d_%H-%M-%S'); fi && mkdir ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ln -s -r .${DB_M%.db}.* ${DB_M%.db}.db .${DB_Z%.db}.* ${DB_Z%.db}.db ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR}" > fix_${sID}_createSubDir_single_${DB_M%.db}.${slurmID}.plan
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_createSubDir_single_${DB_M%.db}.${slurmID}.version
 	### 02-lassort
	elif [[ ${pipelineStepIdx} -eq 2 ]]
    then
        ### clean up plans 
    	for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 

		setlassortOptions
		
		for x in $(seq 1 ${nblocks})
        do
        	echo "${LASTOOLS_PATH}/bin/lassort ${FIX_LASSORT_OPT} ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}Sort.${x}.las ${RAW_DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}.${x}.las"
		done > fix_${sID}_lassort_block_${DB_M%.db}.${slurmID}.plan    	         
        echo "LASTOOLS lassort $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_lassort_block_${DB_M%.db}.${slurmID}.version
    ### 03-computeIntrinsicQV
	elif [[ ${pipelineStepIdx} -eq 3 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 				
		
		for x in $(seq 1 ${nblocks})
        do
        	echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ln -s -f ${DB_Z%.db}.${fsuffix}Sort.${x}.las ${DB_Z%.db}.${x}.${fsuffix}Sort.las && ${DACCORD_PATH}/bin/computeintrinsicqv2 -d${RAW_COV} ${DB_Z%.db}.db ${DB_Z%.db}.${x}.${fsuffix}Sort.las && unlink ${DB_Z%.db}.${x}.${fsuffix}Sort.las && cd ${myCWD}"
		done > fix_${sID}_computeintrinsicqv2_block_${DB_M%.db}.${slurmID}.plan    	         
        echo "DACCORD computeintrinsicqv2 $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_computeintrinsicqv2_block_${DB_M%.db}.${slurmID}.version
	### 04_Catrack
	elif [[ ${pipelineStepIdx} -eq 4 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DAZZLER_PATH}/bin/Catrack -v -f -d ${DB_Z%.db}.db inqual && cp .${DB_Z%.db}.inqual.anno .${DB_Z%.db}.inqual.data ${myCWD}/ && cd ${myCWD}" > fix_${sID}_Catrack_single_${DB_M%.db}.${slurmID}.plan
		echo "DAZZ_DB Catrack $(git --git-dir=${DAZZLER_SOURCE_PATH}/DAZZ_DB/.git rev-parse --short HEAD)" > fix_${sID}_Catrack_single_${DB_M%.db}.${slurmID}.version                
    ### 05_lasdetectsimplerepeats
    elif [[ ${pipelineStepIdx} -eq 5 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
                
        OPT=""
        if [[ -z "${RAW_FIX_LASDETECTSIMPLEREPEATS_ERATE}" ]]
        then 
        	RAW_FIX_LASDETECTSIMPLEREPEATS_ERATE=0.35
   	 	fi 
   	 	
   	 	OPT="${OPT} -d$((RAW_COV/2)) -e${RAW_FIX_LASDETECTSIMPLEREPEATS_ERATE}"
    	
        for x in $(seq 1 ${nblocks})
        do
        	echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/lasdetectsimplerepeats ${OPT} ${DB_Z%.db}.rep.${x}.data ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}Sort.${x}.las && cd ${myCWD}"
		done > fix_${sID}_lasdetectsimplerepeats_block_${DB_M%.db}.${slurmID}.plan
      	echo "DACCORD lasdetectsimplerepeats $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_lasdetectsimplerepeats_block_${DB_M%.db}.${slurmID}.version
    ### 06_mergeAndSortRepeats
    elif [[ ${pipelineStepIdx} -eq 6 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        files="${DB_Z%.db}.rep.[0-9].data"
		if [[ ${nblocks} -gt 9 ]]
		then
			files="${files} ${DB_Z%.db}.rep.[0-9][0-9].data"
		fi
		if [[ ${nblocks} -gt 99 ]]
		then
			files="${files} ${DB_Z%.db}.rep.[0-9][0-9][0-9].data"
		fi
		if [[ ${nblocks} -gt 999 ]]
		then
			files="${files} ${DB_Z%.db}.rep.[0-9][0-9][0-9][0-9].data"
		fi
		if [[ ${nblocks} -gt 9999 ]]
		then
			files="${files} ${DB_Z%.db}.rep.[0-9][0-9][0-9][0-9][0-9].data"
		fi
    	if [[ ${nblocks} -gt 99999 ]]
        then
    		(>&2 echo "fix_${sID}_mergeAndSortRepeats: more than 99999 db blocks are not supported!!!")
        	exit 1	
    	fi
    	## sanity check 
    	cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && if [[ $(ls ${files} | wc -l) -ne ${nblocks} ]]; then exit 1; fi && cd ${myCWD}
    	echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && cat ${files} | ${DACCORD_PATH}/bin/repsort ${DB_Z%.db}.db > ${DB_Z%.db}.rep.data && cd ${myCWD}" >> fix_${sID}_mergeAndSortRepeats_single_${DB_M%.db}.${slurmID}.plan
        echo "DACCORD repsort $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_mergeAndSortRepeats_single_${DB_M%.db}.${slurmID}.version
    ### 07_lasfilteralignments 
    elif [[ ${pipelineStepIdx} -eq 7 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        OPT=""
        
        if [[ -z "${RAW_FIX_LASFILTERALIGNMENTS_ERATE}" ]]
        then 
        	RAW_FIX_LASFILTERALIGNMENTS_ERATE=0.35
   	 	fi 
   	 	
   	 	OPT="${OPT} -e${RAW_FIX_LASFILTERALIGNMENTS_ERATE}"
    	
        for x in $(seq 1 ${nblocks})
        do
        	echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/lasfilteralignments ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt1.${x}.las ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}Sort.${x}.las && cd ${myCWD}"
		done > fix_${sID}_lasfilteralignments_block_${DB_M%.db}.${slurmID}.plan
      	echo "DACCORD lasfilteralignments $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_lasfilteralignments_block_${DB_M%.db}.${slurmID}.version
    ### 08_mergesym2
    elif [[ ${pipelineStepIdx} -eq 8 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/mergesym2 ${DB_Z%.db}.${fsuffix}SortFilt1.sym ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt1.*.las.sym && cd ${myCWD}" > fix_${sID}_mergesym2_single_${DB_M%.db}.${slurmID}.plan
        echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && rm ${DB_Z%.db}.${fsuffix}SortFilt1.*.las.sym && cd ${myCWD}" >> fix_${sID}_mergesym2_single_${DB_M%.db}.${slurmID}.plan
        echo "DACCORD mergesym2 $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_mergesym2_single_${DB_M%.db}.${slurmID}.version        
	### 09_filtersym
    elif [[ ${pipelineStepIdx} -eq 9 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        OPT=""        
        
		if [[ -z "${RAW_FILT_FILTERSYM_VERBOSE}" ]]
        then
        	RAW_FILT_FILTERSYM_VERBOSE=1
   	 	fi 
   	 	
   	 	if [[ -n "${RAW_FILT_FILTERSYM_VERBOSE}" && ${RAW_FILT_FILTERSYM_VERBOSE} != 0 ]]
        then
   	 		OPT="--verbose" 
   	 	fi
   	 	
   	 	for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/filtersym ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt1.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt1.sym" 
		done > fix_${sID}_filtsym_block_${DB_M%.db}.${slurmID}.plan
      	echo "DACCORD filtsym $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_filtsym_block_${DB_M%.db}.${slurmID}.version                 
   	### 10_lasfilteralignmentsborderrepeats
    elif [[ ${pipelineStepIdx} -eq 10 ]]
    then
        ### clean up plans 
        for x in $(ls fix_10_*_*_${DB_M%.db}.${slurmID}.* 2> /dev/null)
        do            
            rm $x
        done
                
		OPT=""
        
		if [[ -z "${RAW_FILT_LASFILTERALIGNMENTSBORDERREPEATS_THREADS}" ]]
        then
        	RAW_FILT_LASFILTERALIGNMENTSBORDERREPEATS_THREADS=8
   	 	fi 
   	 	
   	 	OPT="-t${RAW_FILT_LASFILTERALIGNMENTSBORDERREPEATS_THREADS}"
   	 	
   	 	if [[ -z "${RAW_FILT_LASFILTERALIGNMENTSBORDERREPEATS_ERATE}" ]]
        then
        	RAW_FILT_LASFILTERALIGNMENTSBORDERREPEATS_ERATE=0.35
   	 	fi 
   	 	
   	 	OPT="${OPT} -e${RAW_FILT_LASFILTERALIGNMENTSBORDERREPEATS_ERATE}"
   	 	for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/lasfilteralignmentsborderrepeats ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt2.${x}.las ${DB_Z%.db}.db ${DB_Z%.db}.rep.data ${DB_Z%.db}.${fsuffix}SortFilt1.${x}.las && cd ${mxCWD}" 
		done > fix_10_lasfilteralignmentsborderrepeats_block_${DB_M%.db}.${slurmID}.plan
      	echo "DACCORD lasfilteralignmentsborderrepeats $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_10_lasfilteralignmentsborderrepeats_block_${DB_M%.db}.${slurmID}.version
  	### 11_mergesym2
    elif [[ ${pipelineStepIdx} -eq 11 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        OPT=""        
        echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/mergesym2 ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt2.sym ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt2.*.las.sym && cd ${myCWD}" > fix_${sID}_mergesym2_single_${DB_M%.db}.${slurmID}.plan
        echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && rm ${DB_Z%.db}.${fsuffix}SortFilt2.*.las.sym && cd ${myCWD}" >> fix_${sID}_mergesym2_single_${DB_M%.db}.${slurmID}.plan
        echo "DACCORD mergesym2 $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_mergesym2_single_${DB_M%.db}.${slurmID}.version        
	### 12_filtersym
    elif [[ ${pipelineStepIdx} -eq 12 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
        OPT=""
        
		if [[ -z "${RAW_FILT_FILTERSYM_VERBOSE}" ]]
        then
        	RAW_FILT_FILTERSYM_VERBOSE=1
   	 	fi 
   	 	
   	 	if [[ -n "${RAW_FILT_FILTERSYM_VERBOSE}" && ${RAW_FILT_FILTERSYM_VERBOSE} != 0 ]]
        then
   	 		OPT="--verbose" 
   	 	fi
   	 	
   	 	for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/filtersym ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt2.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt2.sym && cd ${myCWD}" 
		done > fix_${sID}_filtsym_block_${DB_M%.db}.${slurmID}.plan
      	echo "DACCORD filtsym $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_filtsym_block_${DB_M%.db}.${slurmID}.version
    ### 13_filterchainsraw
    elif [[ ${pipelineStepIdx} -eq 13 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
                
        OPT=""
        setLAfilterOptions
		if [[ -z "${RAW_FILT_FILTERCHAINSRAW_LEN}" ]]
        then
        	RAW_FILT_FILTERCHAINSRAW_LEN=4000
   	 	fi 
   	 	
   	 	OPT="-l${RAW_FILT_FILTERCHAINSRAW_LEN}"
        for x in $(seq 1 ${nblocks})
        do
    		echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/filterchainsraw ${OPT} ${DB_Z%.db}.${fsuffix}SortFilt2Chain.${x}.las ${DB_Z%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt2.${x}.las && ${MARVEL_PATH}/bin/LAfilter ${FIX_LAFILTER_OPT} ${DB_M%.db}.db ${DB_Z%.db}.${fsuffix}SortFilt2Chain.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las && cd ${myCWD}" 
		done > fix_${sID}_filterchainsraw_block_${DB_M%.db}.${slurmID}.plan
    	echo "DACCORD filterchainsraw $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_filterchainsraw_block_${DB_M%.db}.${slurmID}.version      	
    ### 14_daccord
    elif [[ ${pipelineStepIdx} -eq 14 ]]
    then
        ### clean up plans 
    	for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
	
		setDaccordOptions        
		
		for x in $(seq 1 ${nblocks})
		do
    		echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/daccord ${FIX_DACCORD_OPT} --eprofonly -E${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.eprof ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las ${DB_Z%.db}.db && ${DACCORD_PATH}/bin/daccord ${FIX_DACCORD_OPT} -E${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.eprof ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las ${DB_Z%.db}.db > ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta && cd ${myCWD}"
		done > fix_${sID}_daccord_block_${DB_M%.db}.${slurmID}.plan
        echo "DACCORD daccord $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_daccord_block_${DB_M%.db}.${slurmID}.version
   	### 15_computeextrinsicqv
    elif [[ ${pipelineStepIdx} -eq 15 ]]
    then
        ### clean up plans 
    	for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        
        if [[ ${nblocks} -lt 10 ]]
		then
			files="${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9].dac.fasta"
		elif [[ ${nblocks} -lt 100 ]]
		then
			files="${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9].dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9][0-9].dac.fasta"
		elif [[ ${nblocks} -lt 1000 ]]
		then
			files="${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9].dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9][0-9].dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9][0-9][0-9].dac.fasta"
		elif [[ ${nblocks} -lt 10000 ]]
		then
			files="${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9].dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9][0-9].dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9][0-9][0-9].dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.[0-9][0-9][0-9][0-9].dac.fasta"
		else
    		(>&2 echo "fix_${sID}_computeextrinsicqv_single_${DB_M%.db}.${slurmID}.: more than 99999 db blocks are not supported!!!")
        	exit 1	
    	fi
    	
    	OPT=""
		if [[ -n "${RAW_FILT_COMPUTEEXTRINSICQ_THREADS}" ]]
        then
        	OPT="${OPT} -t${RAW_FILT_COMPUTEEXTRINSICQ_THREADS}"
   	 	fi
		echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && cat ${files} > ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.dac.fasta && ${DACCORD_PATH}/bin/computeextrinsicqv${OPT} ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.dac.fasta ${DB_Z%.db}.db && cd ${myCWD}" > fix_${sID}_computeextrinsicqv_single_${DB_M%.db}.${slurmID}.plan
        echo "DACCORD computeextrinsicqv $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_computeextrinsicqv_single_${DB_M%.db}.${slurmID}.version
    ### 16_split
    elif [[ ${pipelineStepIdx} -eq 16 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        
		if [[ -z "${RAW_FIX_SPLIT_DIVIDEBLOCK}" ]]
		then 
			RAW_FIX_SPLIT_DIVIDEBLOCK=10
		fi
		
		# create folder structure
		for x in $(seq 1 ${nblocks})
		do
			directory="${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR}/${RAW_FIX_SPLIT_TYPE}_s${x}"
			if [[ -d "${directory}" ]]
			then
					mv ${directory} ${directory}_$(date '+%Y-%m-%d_%H-%M-%S'); 
			fi
			
			mkdir -p ${directory}			
		done 
                
        setHaploSplitOptions
        
        for x in $(seq 1 ${nblocks})
		do
			for y in $(seq 0 $((RAW_FIX_SPLIT_DIVIDEBLOCK-1)))
			do
				echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${DACCORD_PATH}/bin/${FIX_SPLIT_OPT} -E${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.eprof -J${y},${RAW_FIX_SPLIT_DIVIDEBLOCK} ${RAW_FIX_SPLIT_TYPE}_s${x}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2Split.${y}.${x}.las ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.dac.fasta ${DB_Z%.db}.${fsuffix}SortFilt2Chain2.${x}.las ${DB_Z%.db}.db && cd ${myCWD}"		
			done	    		
		done > fix_${sID}_split_block_${DB_M%.db}.${slurmID}.plan
        echo "DACCORD ${RAW_FIX_SPLIT_TYPE} $(git --git-dir=${DACCORD_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_split_block_${DB_M%.db}.${slurmID}.version
	### 17_LAmerge 
    elif [[ ${pipelineStepIdx} -eq 17 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done
        		        
        setLAmergeOptions
        setHaploSplitOptions
        
        for x in $(seq 1 ${nblocks})
		do
			echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${MARVEL_PATH}/bin/LAmerge ${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.${fsuffix}SortFilt2Chain2_${RAW_FIX_SPLIT_TYPE}.${x}.keep.las ${RAW_FIX_SPLIT_TYPE}_s${x}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2Split.*.${x}.las ${myCWD}/identity/${DB_Z%.db}.identity.${x}.las && cd ${myCWD}"
			echo "cd ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR} && ${MARVEL_PATH}/bin/LAmerge ${LAMERGE_OPT} ${DB_M%.db} ${DB_Z%.db}.${fsuffix}SortFilt2Chain2_${RAW_FIX_SPLIT_TYPE}.${x}.drop.las ${RAW_FIX_SPLIT_TYPE}_s${x}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2Split.*.${x}_drop.las ${myCWD}/identity/${DB_Z%.db}.identity.${x}.las && cd ${myCWD}"	
		done > fix_${sID}_LAmerge_block_${DB_M%.db}.${slurmID}.plan
        echo "MARVEL LAmerge $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_LAmerge_block_${DB_M%.db}.${slurmID}.version
	### 18_LAfix    
    elif [[ ${pipelineStepIdx} -eq 18 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done 
        ### find and set LAfix options
        
		if [[ "${fsuffix}" == "dalignFilt" ]]
		then
		   	setLAfixOptions dalign
		else
			setLAfixOptions repcomp
		fi
		
		setHaploSplitOptions
		
        mkdir -p ${RAW_FIX_LAFIX_PATH}_daccord_${RAW_FIX_SPLIT_TYPE}
		
		addopt=""

        for x in $(seq 1 ${nblocks})
        do 
        	if [[ -n ${RAW_FIX_LAFIX_TRIMFILEPREFIX} ]]
        	then 
        		addopt="-T${RAW_FIX_LAFIX_TRIMFILEPREFIX}_${x}.txt "
        	fi
            echo "${MARVEL_PATH}/bin/LAfix${FIX_LAFIX_OPT} ${addopt}${DB_M%.db} ${RAW_DACCORD_OUTDIR}_${RAW_DACCORD_INDIR}/${DB_Z%.db}.${fsuffix}SortFilt2Chain2_${RAW_FIX_SPLIT_TYPE}.${x}.keep.las ${RAW_FIX_LAFIX_PATH}_daccord_${RAW_FIX_SPLIT_TYPE}/${DB_M%.db}.${x}${RAW_FIX_LAFIX_FILESUFFIX}.fasta"
    	done > fix_${sID}_LAfix_block_${DB_M%.db}.${slurmID}.plan
    echo "MARVEL LAfix $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_LAfix_block_${DB_M%.db}.${slurmID}.version                
	else
        (>&2 echo "step ${pipelineStepIdx} in FIX_FILT_TYPE ${FIX_FILT_TYPE} not supported")
        (>&2 echo "valid steps are: ${myTypes[${FIX_FILT_TYPE}]}")
        exit 1            
    fi
elif [[ ${pipelineType} -eq 3 ]]
then
  	if [[ ${pipelineStepIdx} -eq 1 ]]
    then
        ### clean up plans 
        for x in $(ls ${pipelineName}_$(prependZero ${pipelineStepIdx})_${pipelineStepName}.${pipelineRunID}.* 2> /dev/null)
        do            
            rm $x
        done    
        
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
	    	echo "${SUBMIT_SCRIPTS_PATH}/patchingStats.sh ${configFile} 1" > fix_${sID}_patchingStats_block_${DB_M%.db}.${slurmID}.plan
		fi
        echo "MARVEL $(git --git-dir=${MARVEL_SOURCE_PATH}/.git rev-parse --short HEAD)" > fix_${sID}_patchingStats_block_${DB_M%.db}.${slurmID}.version
    else
		(>&2 echo "step ${pipelineStepIdx} in pipelineType ${pipelineType} not supported")
        (>&2 echo "valid steps are: ${myTypes[${pipelineType}]}")
        exit 1        
    fi
else
    (>&2echo "unknown pipelineType ${pipelineType}")    
    (>&2 echo "supported types")
    x=0; while [ $x -lt ${#myTypes[*]} ]; do (>&2 echo "${myTypes[${x}]}"); done
    exit 1
fi

exit 0
