/**
 * LAtrimContigs
 *
 * 1. read in Chained las file !!!
 * 2. trim contigs back if they overlap
 *
 *
 *
 *  Author :  DAmar Team
 *
 *  Date   :  February 2020
 *
 *******************************************************************************************/

#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <unistd.h>

#include "lib/colors.h"
#include "lib/oflags.h"
#include "lib/pass.h"
#include "lib/read_loader.h"
#include "lib/tracks.h"
#include "lib/trim.h"
#include "lib/utils.h"

#include "dalign/align.h"
#include "db/DB.h"

#define MAX_GAP 10000
#define MAX_TRIM 50000
#define TRIM_OFFSET 100

#define CONTIG_IS_CONTAINED 	(1 << 0)
#define CONTIG_TRIM 					(1 << 1)

typedef struct
{
	int beg;
	int end;
	int status;

	int *correspID;
	int numIDs;
	int curID;

} TrimInfo;

typedef struct
{

	HITS_DB* db;
	ovl_header_twidth twidth;

	TrimInfo *trim;

} TrimContigContext;

static void usage()
{
	fprintf(stderr, "[-v] <db> <chained_contig_overlaps_in> <out_prefix>\n");

	fprintf(stderr, "options: -v ... verbose\n");
}

static void contig_pre(PassContext* pctx, TrimContigContext* tctx)
{
	printf( ANSI_COLOR_GREEN "PASS contig trimming\n" ANSI_COLOR_RESET);

	tctx->twidth = pctx->twidth;

	tctx->trim = (TrimInfo*) malloc(sizeof(TrimInfo) * DB_NREADS(tctx->db));

	int i;
	for (i = 0; i < DB_NREADS(tctx->db); i++)
	{
		tctx->trim[i].beg = 0;
		tctx->trim[i].end = DB_READ_LEN(tctx->db, i);
		tctx->trim[i].status = 0;
		tctx->trim[i].numIDs = 1;
		tctx->trim[i].curID = 0;
		tctx->trim[i].correspID = (int*) malloc(sizeof(int) * tctx->trim[i].numIDs);
	}
}

static void contig_post(TrimContigContext* ctx, char *prefixOut)
{
	// TODO put file handling into contig_pre !!!!!
	// open output files
	char * statsOut = malloc(strlen(prefixOut) + 20);
	assert(statsOut != NULL);
	char * fastaOut = malloc(strlen(prefixOut) + 20);
	assert(fastaOut != NULL);
	char * trimOut = malloc(strlen(prefixOut) + 20);
	assert(trimOut != NULL);
	char * contOut = malloc(strlen(prefixOut) + 20);
	assert(contOut != NULL);

	FILE* statsFile = NULL;
	sprintf(statsOut, "%s.stats", prefixOut);
	if ((statsFile = fopen(statsOut, "w")) == NULL)
	{
		fprintf(stderr, "could not open %s\n", statsOut);
		exit(1);
	}

	FILE* fastaFile = NULL;
	sprintf(fastaOut, "%s.contigs.fasta", prefixOut);
	if ((fastaFile = fopen(fastaOut, "w")) == NULL)
	{
		fprintf(stderr, "could not open %s\n", fastaOut);
		exit(1);
	}

	FILE* trimFile = NULL;
	sprintf(trimOut, "%s.trimmed.fasta", prefixOut);
	if ((trimFile = fopen(trimOut, "w")) == NULL)
	{
		fprintf(stderr, "could not open %s\n", trimOut);
		exit(1);
	}

	FILE* contFile = NULL;
	sprintf(contOut, "%s.contained.fasta", prefixOut);
	if ((contFile = fopen(contOut, "w")) == NULL)
	{
		fprintf(stderr, "could not open %s\n", contOut);
		exit(1);
	}

	uint64 inputBases = 0;

	uint64 originalBases=0;
	int originalContigs=0;

	uint64 trimmedBases=0;
	int trimmedContigs=0;

	uint64 containedBases = 0;
	int containedContigs = 0;

	int i, j;
	char *contig = New_Read_Buffer(ctx->db);
	assert(contig != NULL);
	int upper = 1; // 2 upper case , 1 lower case, 0 int
	int width = 100;
	int fst, lst;
	for (i = 0; i < DB_NREADS(ctx->db); i++)
	{
		int clen = DB_READ_LEN(ctx->db, i);

		inputBases += clen;

		TrimInfo *t = ctx->trim + i;
		Load_Read(ctx->db, i, contig, upper);

		fst = t->beg;
		lst = t->end;

		if (t->status & CONTIG_IS_CONTAINED)
		{
			containedContigs++;
			containedBases+= lst-fst;
			// write stats file
			fprintf(statsFile, "%d\tCONT\t%d\t%d\t%d\t%d\t", i, clen, clen - fst - (clen - lst), fst, clen - lst);
			for (j = 0; j < t->curID; j++)
			{
				fprintf(statsFile, "%d", t->correspID[j]);
				if (j + 1 < t->curID)
					fprintf(statsFile, ",");
			}
			fprintf(statsFile, "\n");

			// write out contained sequence
			fprintf(contFile, ">%s/%d/%d_%d len=%d trimL=%d trimR=%d\n", ctx->db->path, i, fst, lst, lst - fst, fst, clen - lst);
			for (j = fst; j + width < lst; j += width)
				fprintf(contFile, "%.*s\n", width, contig + j);
			if (j < lst)
				fprintf(contFile, "%.*s\n", lst - j, contig + j);
		}
		else
		{
			if (t->status & CONTIG_TRIM)
			{
				trimmedContigs++;
				trimmedBases+= lst-fst;

				// write stats
				fprintf(statsFile, "%d\tTRIM\t%d\t%d\t%d\t%d\t", i, clen, clen - fst - (clen - lst), fst, clen - lst);

				for (j = 0; j < t->curID; j++)
				{
					fprintf(statsFile, "%d", t->correspID[j]);
					if (j + 1 < t->curID)
						fprintf(statsFile, ",");
				}
				fprintf(statsFile, "\n");

				// write trimmed contig sequence
				fprintf(fastaFile, ">%s/%d/%d_%d len=%d trimL=%d trimR=%d\n", ctx->db->path, i, fst, lst, lst - fst, fst, clen - lst);
				for (j = fst; j + width < lst; j += width)
					fprintf(fastaFile, "%.*s\n", width, contig + j);
				if (j < lst)
					fprintf(fastaFile, "%.*s\n", lst - j, contig + j);

				if (fst > 0)
				{
					// write left-trimmed-off sequence
					fprintf(trimFile, ">%s/%d/%d_%d len=%d\n", ctx->db->path, i, 0, fst, fst);
					for (j = 0; j + width < fst; j += width)
						fprintf(trimFile, "%.*s\n", width, contig + j);
					if (j < fst)
						fprintf(fastaFile, "%.*s\n", fst - j, contig + j);
				}
				if (lst < clen)
				{
					// write left-trimmed-off sequence
					fprintf(trimFile, ">%s/%d/%d_%d len=%d\n", ctx->db->path, i, lst, clen, clen-lst);
					for (j = lst; j + width < clen; j += width)
						fprintf(trimFile, "%.*s\n", width, contig + j);
					if (j < clen)
						fprintf(fastaFile, "%.*s\n", clen - j, contig + j);
				}
			}
			else
			{
				originalContigs++;
				originalBases+= lst-fst;

				// write out stats
				fprintf(statsFile, "%d\tORIG\t%d\t%d\t%d\t%d\t-1\n", i, clen, clen - fst - (clen - lst), fst, clen - lst);

				// write out original sequence
				fprintf(fastaFile, ">%s/%d/%d_%d len=%d trimL=%d trimR=%d\n", ctx->db->path, i, fst, lst, lst - fst, fst, clen - lst);
				for (j = fst; j + width < lst; j += width)
					fprintf(fastaFile, "%.*s\n", width, contig + j);
				if (j < lst)
					fprintf(fastaFile, "%.*s\n", lst - j, contig + j);
			}
		}
	}

	// output some statistics

	printf("IN  ALL  contigs %6d (%5.2f%%)\tbases %12llu (%5.2f%%)\n", i, 100.0, inputBases, 100.0);
	printf("OUT ALL  contigs %6d (%5.2f%%)\tbases %12llu (%5.2f%%)\n", trimmedContigs + originalContigs, (trimmedContigs + originalContigs)*100.0/i, trimmedBases+originalBases, (trimmedBases+originalBases)*100.0/inputBases);
	printf("OUT ORIG contigs %6d (%5.2f%%)\tbases %12llu (%5.2f%%)\n", originalContigs, (originalContigs)*100.0/i, originalBases, (originalBases)*100.0/inputBases);
	printf("OUT TRIM contigs %6d (%5.2f%%)\tbases %12llu (%5.2f%%)\n", trimmedContigs, (trimmedContigs)*100.0/i, trimmedBases, (trimmedBases)*100.0/inputBases);
	printf("OUT CONT contigs %6d (%5.2f%%)\tbases %12llu (%5.2f%%) #should be moved to ALT set\n", containedContigs, (containedContigs)*100.0/i, containedBases, (containedBases)*100.0/inputBases);

	fclose(statsFile);
	fclose(fastaFile);
	fclose(trimFile);
	fclose(contFile);
	free(statsOut);
	free(fastaOut);
	free(trimOut);
	free(contOut);
	free(contig - 1);
	for (i = 0; i < DB_NREADS(ctx->db); i++)
		free(ctx->trim[i].correspID);

	free(ctx->trim);
}

static int contig_handler(void* _ctx, Overlap* ovl, int novl)
{
	TrimContigContext* ctx = (TrimContigContext*) _ctx;

	int i = 0;
	int cumBasesA;
	int cumBasesB;
	int gapBasesA;
	int gapBasesB;
	int dupBasesA;
	int dupBasesB;
	int contained = -1;

	gapBasesA = gapBasesB = dupBasesA = dupBasesB = 0;

	int trim_ab, trim_ae;
	int trim_bb, trim_be;

	trim_ab = trim_bb = 0;
	trim_ae = DB_READ_LEN(ctx->db, ovl->aread);
	trim_be = DB_READ_LEN(ctx->db, ovl->bread);

	//todo do some sanity checks
	Overlap *o1 = ovl;
	Overlap *o2 = ovl;
	cumBasesA = o1->path.aepos - o1->path.abpos;
	cumBasesB = o1->path.bepos - o1->path.bbpos;

	for (i = 1; i < novl; i++)
	{
		o2 = ovl + i;
		assert(o1->bread == o2->bread);
		assert((o1->flags & OVL_COMP) == (o2->flags & OVL_COMP));

		cumBasesA += o2->path.aepos - o2->path.abpos;
		cumBasesB += o2->path.bepos - o2->path.bbpos;

		int tmp;

		if (o2->path.abpos > o1->path.aepos)
		{
			tmp = o2->path.abpos - o1->path.aepos;
			if (tmp > MAX_GAP)
			{
				fprintf(stderr, "WARNING: %d vs %d gap size to large a[%d, %d] - g%d - a[%d, %d]!\n", o1->aread, o1->bread, o1->path.abpos, o1->path.aepos, tmp, o2->path.abpos, o2->path.aepos);
			}
			gapBasesA += tmp;
		}
		else
		{
			dupBasesA += o1->path.aepos - o2->path.abpos;
		}

		if (o2->path.bbpos > o1->path.bepos)
		{
			tmp = o2->path.bbpos - o1->path.bepos;
			if (tmp > MAX_GAP)
			{
				fprintf(stderr, "WARNING: %d vs %d gap size to large b[%d, %d] - g%d - b[%d, %d]!\n", o1->aread, o1->bread, o1->path.bbpos, o1->path.bepos, tmp, o2->path.bbpos, o2->path.bepos);
			}
			gapBasesB += tmp;
		}
		else
		{
			dupBasesB += o1->path.bepos - o2->path.bbpos;
		}

		o1 = o2;
	}

	if (cumBasesA >= 0.5 * DB_READ_LEN(ctx->db, o1->aread))
	{
		fprintf(stderr, "WARNING: contig %d is more then 50%% contained in contig %d\n", o1->aread, o1->bread);
		contained = 0;
	}

	if (cumBasesB >= 0.5 * DB_READ_LEN(ctx->db, o1->bread))
	{
		fprintf(stderr, "WARNING: contig %d is more then 50%% contained in contig %d\n", o1->bread, o1->aread);
		if (contained == 0)
			contained = 2;		// both contained in each other !!!!!!!
		else
			contained = 1;
	}

	if (o1->path.abpos > MAX_TRIM && o2->path.aepos < DB_READ_LEN(ctx->db,o1->aread) - MAX_TRIM)
	{
		fprintf(stderr, "WARNING: LAS chain coordinates of contig %d [%d, %d] is out of MAX_TRIM [%d, %d]\n", o1->aread, o1->path.abpos, o2->path.aepos, MAX_TRIM, DB_READ_LEN(ctx->db,o1->aread) - MAX_TRIM);
	}

	if (o1->path.bbpos > MAX_TRIM && o2->path.bepos < DB_READ_LEN(ctx->db,o1->bread) - MAX_TRIM)
	{
		fprintf(stderr, "WARNING: LAS chain coordinates of contig %d [%d, %d] is out of MAX_TRIM [%d, %d]\n", o1->bread, o1->path.bbpos, o2->path.bepos, MAX_TRIM, DB_READ_LEN(ctx->db,o1->bread) - MAX_TRIM);
	}

	// ensure enough space for contigs IDs
	if (ctx->trim[o1->aread].curID == ctx->trim[o1->aread].numIDs)
	{
		ctx->trim[o1->aread].numIDs += 2;
		ctx->trim[o1->aread].correspID = (int*) realloc(ctx->trim[o1->aread].correspID, sizeof(int) * ctx->trim[o1->aread].numIDs);
		assert(ctx->trim[o1->aread].correspID != NULL);
	}

	if (ctx->trim[o1->bread].curID == ctx->trim[o1->bread].numIDs)
	{
		ctx->trim[o1->bread].numIDs += 2;
		ctx->trim[o1->bread].correspID = (int*) realloc(ctx->trim[o1->bread].correspID, sizeof(int) * ctx->trim[o1->bread].numIDs);
		assert(ctx->trim[o1->bread].correspID != NULL);
	}

	if (contained == 0)
	{
		ctx->trim[o1->aread].status |= CONTIG_IS_CONTAINED;
		ctx->trim[o1->aread].correspID[ctx->trim[o1->aread].curID] = o1->bread;
		ctx->trim[o1->aread].curID++;
	}
	else if (contained == 1)
	{
		ctx->trim[o1->bread].status |= CONTIG_IS_CONTAINED;
		ctx->trim[o1->bread].correspID[ctx->trim[o1->bread].curID] = o1->aread;
		ctx->trim[o1->bread].curID++;
	}
	else if (contained == 2)
	{
		ctx->trim[o1->aread].status |= CONTIG_IS_CONTAINED;
		ctx->trim[o1->bread].status |= CONTIG_IS_CONTAINED;

		for (i = 0; i < ctx->trim[o1->aread].curID; i++)
		{
			if (ctx->trim[o1->aread].correspID[i] == o1->bread)
				break;
		}
		if (i == ctx->trim[o1->aread].curID)
		{
			ctx->trim[o1->aread].correspID[ctx->trim[o1->aread].curID] = o1->bread;
			ctx->trim[o1->aread].curID++;
		}

		for (i = 0; i < ctx->trim[o1->bread].curID; i++)
		{
			if (ctx->trim[o1->bread].correspID[i] == o1->aread)
				break;
		}
		if (i == ctx->trim[o1->bread].curID)
		{
			ctx->trim[o1->bread].correspID[ctx->trim[o1->bread].curID] = o1->aread;
			ctx->trim[o1->bread].curID++;
		}
	}
	else
	{
//		int alen = DB_READ_LEN(ctx->db, ovl->aread);
		int blen = DB_READ_LEN(ctx->db, ovl->bread);

		/*  trim A at the beginning
		 * 	A			 -------->			OR			A			 -------->
		 * 	B	------->										B	<------
		 */
		if (ovl->path.abpos < DB_READ_LEN(ctx->db, ovl->aread) - o2->path.aepos)
		{
			if (novl == 1)
			{
				trim_ab = ovl->path.abpos + (ovl->path.aepos - ovl->path.abpos) / 2 + TRIM_OFFSET;

				if (ovl->flags & OVL_COMP)
				{
					trim_bb = blen - (ovl->path.bbpos + (ovl->path.bepos - ovl->path.bbpos) / 2) + TRIM_OFFSET;
				}
				else
				{
					trim_be = ovl->path.bbpos + ((ovl->path.bepos - ovl->path.bbpos) / 2) - TRIM_OFFSET;
				}
			}
			else // we have a chain with multiple overlaps
			{
				trim_ab = (o2->path.abpos) + TRIM_OFFSET;
				if (ovl->flags & OVL_COMP)
				{
					trim_bb = blen - (ovl->path.bepos) + TRIM_OFFSET;
				}
				else
				{
					trim_be = (ovl->path.bepos) - TRIM_OFFSET;
				}
			}
		}
		/*	trim A at the end
		 * 	A			 -------->						OR			A			 -------->
		 * 	B							------->							B						<-------
		 */
		else
		{
			if (novl == 1)
			{
				trim_ae = o2->path.abpos + ((o2->path.aepos - o2->path.abpos) / 2) - TRIM_OFFSET;
				if (ovl->flags & OVL_COMP)
				{
					trim_be = blen - (o2->path.bbpos + (o2->path.bepos - o2->path.bbpos) / 2) - TRIM_OFFSET;
				}
				else
				{
					trim_bb = o2->path.bbpos + (o2->path.bepos - o2->path.bbpos) / 2 + TRIM_OFFSET;
				}
			}
			else
			{
				trim_ae = ovl->path.aepos - TRIM_OFFSET;
				if (ovl->flags & OVL_COMP)
				{
					trim_be = blen - o2->path.bbpos - TRIM_OFFSET;
				}
				else
				{
					trim_bb = o2->path.bbpos + TRIM_OFFSET;
				}
			}
		}

		printf("CHAIN: %d vs %d (%c) (LEN %d %d)", ovl->aread, ovl->bread, (ovl->flags & OVL_COMP) ? 'c' : 'n', DB_READ_LEN(ctx->db, ovl->aread), DB_READ_LEN(ctx->db, ovl->bread));
		for (i = 0; i < novl; i++)
		{
			printf(" [%d, %d - %d, %d]", ovl[i].path.abpos, ovl[i].path.aepos, ovl[i].path.bbpos, ovl[i].path.bepos);
		}
		printf("\n");

		// set trim coordinates
		printf("   TRIM_COORD CONTIG %d -> [%d, %d]\n", ovl->aread, trim_ab, trim_ae);
		printf("   TRIM_COORD CONTIG %d -> [%d, %d]\n", ovl->bread, trim_bb, trim_be);

		if (ctx->trim[ovl->aread].status & CONTIG_TRIM)
		{
			printf("   %d --> already trimmed: [%d,%d] ", ovl->aread, ctx->trim[ovl->aread].beg, ctx->trim[ovl->aread].end);
			int ch = 0;
			if (ctx->trim[ovl->aread].beg < trim_ab)
			{
				ctx->trim[ovl->aread].beg = trim_ab;
				ch = 1;
			}
			if (ctx->trim[ovl->aread].end > trim_ae)
			{
				ctx->trim[ovl->aread].end = trim_ae;
				ch = 1;
			}
			if (ch)
			{
				printf("   changed to [%d,%d]\n", ctx->trim[ovl->aread].beg, ctx->trim[ovl->aread].end);
			}
			else
			{
				printf("   kept\n");
			}

			for (i = 0; i < ctx->trim[ovl->aread].curID; i++)
			{
				if (ctx->trim[ovl->aread].correspID[i] == ovl->bread)
					break;
			}
			if (i == ctx->trim[ovl->aread].curID)
			{
				ctx->trim[ovl->aread].correspID[ctx->trim[o1->aread].curID] = ovl->bread;
				ctx->trim[ovl->aread].curID++;
			}
		}
		else
		{
			ctx->trim[ovl->aread].beg = trim_ab;
			ctx->trim[ovl->aread].end = trim_ae;
			ctx->trim[ovl->aread].status |= CONTIG_TRIM;
			ctx->trim[ovl->aread].correspID[ctx->trim[ovl->aread].curID] = o1->bread;
			ctx->trim[ovl->aread].curID++;
		}

		if (ctx->trim[ovl->bread].status & CONTIG_TRIM)
		{
			printf("   %d --> already trimmed: [%d,%d] ", ovl->bread, ctx->trim[ovl->bread].beg, ctx->trim[ovl->bread].end);
			int ch = 0;
			if (ctx->trim[ovl->bread].beg < trim_bb)
			{
				ctx->trim[ovl->bread].beg = trim_bb;
				ch = 1;
			}
			if (ctx->trim[ovl->bread].end > trim_be)
			{
				ctx->trim[ovl->bread].end = trim_be;
				ch = 1;
			}
			if (ch)
			{
				printf("   changed to [%d,%d]\n", ctx->trim[ovl->bread].beg, ctx->trim[ovl->bread].end);
			}
			else
			{
				printf("   kept\n");
			}
			for (i = 0; i < ctx->trim[ovl->bread].curID; i++)
			{
				if (ctx->trim[ovl->bread].correspID[i] == ovl->aread)
					break;
			}
			if (i == ctx->trim[ovl->bread].curID)
			{
				ctx->trim[ovl->bread].correspID[ctx->trim[o1->bread].curID] = ovl->aread;
				ctx->trim[ovl->bread].curID++;
			}
		}
		else
		{
			ctx->trim[ovl->bread].beg = trim_bb;
			ctx->trim[ovl->bread].end = trim_be;
			ctx->trim[ovl->bread].status |= CONTIG_TRIM;
			ctx->trim[ovl->bread].correspID[ctx->trim[ovl->bread].curID] = o1->aread;
			ctx->trim[ovl->bread].curID++;
		}
	}
	return 1;
}

int main(int argc, char* argv[])
{
	HITS_DB db;
	TrimContigContext tctx;
	PassContext* pctx;
	FILE* fileOvlIn;

	bzero(&tctx, sizeof(TrimContigContext));

	tctx.db = &db;
	int c;
	opterr = 0;
	while ((c = getopt(argc, argv, "v")) != -1)
	{
		switch (c)
		{
			case 'v':
				usage();
				return 0;
				break;
			default:
				fprintf(stderr, "[ERROR] unknown option -%c\n", optopt);
				usage();
				exit(1);
		}
	}

	if (argc - optind != 3)
	{
		usage();
		exit(1);
	}

	char* pcPathReadsIn = argv[optind++];
	char* pcPathOverlapsIn = argv[optind++];
	char* pcPrefixContigsOut = argv[optind++];

	if ((fileOvlIn = fopen(pcPathOverlapsIn, "r")) == NULL)
	{
		fprintf(stderr, "could not open %s\n", pcPathOverlapsIn);
		exit(1);
	}

	if (Open_DB(pcPathReadsIn, &db))
	{
		fprintf(stderr, "could not open %s\n", pcPathReadsIn);
		exit(1);
	}

	pctx = pass_init(fileOvlIn, NULL);

	pctx->split_b = 1;
	pctx->load_trace = 0;
	pctx->unpack_trace = 0;
	pctx->data = &tctx;
	pctx->write_overlaps = 0;
	pctx->purge_discarded = 0;

	contig_pre(pctx, &tctx);

	pass(pctx, contig_handler);

	contig_post(&tctx, pcPrefixContigsOut);

	pass_free(pctx);

	// cleanup
	Close_DB(&db);
	fclose(fileOvlIn);

	return 0;

}
