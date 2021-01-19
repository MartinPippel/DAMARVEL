/*
 * LAfilterDepth.c
 *
 *  Created on: 19 Jan 2021
 *      Author: pippel
 */

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

#define DEF_ARG_T TRACK_TRIM
#define DEF_ARG_TT 0

typedef struct
{
	// stats counters
	int nFilteredLas;
	int depth;
	float erate;
	int sort;		// sort: 0 by error rate
							// sort: 1 by suffix-prefix overlaps
							// sort: 2 by alignment length
	int verbose;
	int do_trim;

	HITS_DB *db;
	HITS_TRACK *trackTrim;

	int useRLoader;
	TRIM *trim;
	Read_Loader *rl;

	ovl_header_twidth twidth;

	Overlap **ovl_sorted;
	int omax;

	int *coverageHist;

} FilterContext;

static int loader_handler(void *_ctx, Overlap *ovl, int novl)
{
	FilterContext *ctx = (FilterContext*) _ctx;
	Read_Loader *rl = ctx->rl;

	static int firstCall = 1;

	int i;
	for (i = 0; i < novl; i++)
	{
		int b = ovl[i].bread;

		int trim_b_left, trim_b_right;

		if (ctx->trackTrim)
			get_trim(ctx->db, ctx->trackTrim, b, &trim_b_left, &trim_b_right);
		else
		{
			if (ctx->trackTrim == NULL && firstCall)
			{
				printf("[WARNING] - Read loader is used without trim track. This can cause issues!\n");
				firstCall = 0;
			}

			trim_b_left = 0;
			trim_b_right = DB_READ_LEN(ctx->db, b);
		}

		if (ovl[i].flags & OVL_COMP)
		{
			int tmp = trim_b_left;
			int blen = DB_READ_LEN(ctx->db, ovl[i].bread);
			trim_b_left = blen - trim_b_right;
			trim_b_right = blen - tmp;
		}

		if (trim_b_left >= trim_b_right)
		{
			continue;
		}

		int bbt = MAX(trim_b_left, ovl[i].path.bbpos);
		int bet = MIN(trim_b_right, ovl[i].path.bepos);

		if (bbt >= bet)
		{
			continue;
		}

		if (bbt == ovl[i].path.bbpos && bet == ovl[i].path.bepos)
		{
			continue;
		}

		bbt = MAX(trim_b_left, ovl[i].path.bbpos);
		bet = MIN(trim_b_right, ovl[i].path.bepos);

		if (bbt < bet && (bbt != ovl[i].path.bbpos || bet != ovl[i].path.bepos))
		{
			rl_add(rl, ovl[i].aread);
			rl_add(rl, ovl[i].bread);

			continue;
		}

		int bepos = ovl[i].path.bepos;

		if (bepos > bet)
		{
			rl_add(rl, ovl[i].aread);
			rl_add(rl, ovl[i].bread);
		}
	}

	return 1;
}

static void filter_pre(PassContext *pctx, FilterContext *fctx)
{
	if (fctx->verbose)
	{
		printf( ANSI_COLOR_GREEN "PASS filtering\n" ANSI_COLOR_RESET);
		printf( ANSI_COLOR_RED "Options\n");
		printf("  max depth: %d\n", fctx->depth);
		printf("  max eRate: %f\n", fctx->erate);
		printf("  sort LAS: %d\n", fctx->sort);
		printf("  useReadLoader: %d\n", fctx->useRLoader);
		if (fctx->trackTrim)
			printf("  trim track: %s\n", fctx->trackTrim->name);
		printf("  do trim: %d\n", fctx->do_trim);
		printf("  purgeLas: %d\n", pctx->purge_discarded);
		printf("\n" ANSI_COLOR_RESET);
	}

	fctx->twidth = pctx->twidth;

	fctx->ovl_sorted = malloc(sizeof(Overlap*) * fctx->omax);

	// trim

	if (fctx->do_trim)
	{
		fctx->trim = trim_init(fctx->db, pctx->twidth, fctx->trackTrim, fctx->rl);
	}

	fctx->coverageHist = malloc(sizeof(int) * (1 + DB_READ_MAXLEN(fctx->db) / fctx->twidth));
	bzero(fctx->coverageHist, sizeof(int) * (1 + DB_READ_MAXLEN(fctx->db) / fctx->twidth));
}

static void filter_post(FilterContext *ctx)
{
	if (ctx->verbose)
	{
		if (ctx->trim)
		{
			printf("trimmed %'lld of %'lld overlaps\n", ctx->trim->nTrimmedOvls, ctx->trim->nOvls);
			printf("trimmed %'lld of %'lld bases\n", ctx->trim->nTrimmedBases, ctx->trim->nOvlBases);
		}
		if (ctx->nFilteredLas)
		{
			printf("overlaps discarded         %10d\n", ctx->nFilteredLas);
		}
	}

	free(ctx->ovl_sorted);

	if (ctx->trim)
	{
		trim_close(ctx->trim);
	}
}

// sort comparators
// sort by erate
static int cmp_ovls_erate(const void *a, const void *b)
{
	Overlap *o1 = *(Overlap**) a;
	Overlap *o2 = *(Overlap**) b;

	float e1 = (200. * o1->path.diffs) / ((o1->path.aepos - o1->path.abpos) + (o1->path.bepos - o1->path.bbpos));
	float e2 = (200. * o2->path.diffs) / ((o2->path.aepos - o2->path.abpos) + (o2->path.bepos - o2->path.bbpos));

	float cmp = e1 - e2;

	if (cmp == 0) // evaluate length, longest first
	{
		cmp = (o2->path.aepos - o2->path.abpos) - (o1->path.aepos - o1->path.abpos);
	}

	if (cmp < 0)
		return -1;
	else if (cmp > 0)
		return 1;
	return 0;
}
// sort by length
static int cmp_ovls_length(const void *a, const void *b)
{
	Overlap *o1 = *(Overlap**) a;
	Overlap *o2 = *(Overlap**) b;

	return (o2->path.aepos - o2->path.abpos) - (o1->path.aepos - o1->path.abpos);
}

static void sort_overlaps(FilterContext *ctx, Overlap *ovl, int novl)
{
	// check if sort buffer is large enough
	if (novl >= ctx->omax)
	{
		ctx->omax = 1.2 * novl + 100;
		ctx->ovl_sorted = realloc(ctx->ovl_sorted, sizeof(Overlap*) * ctx->omax);
	}

	int i;
	for (i = 0; i < novl; i++)
	{
		ctx->ovl_sorted[i] = ovl + i;
	}

	switch (ctx->sort)
	{
		case 0:
			qsort(ctx->ovl_sorted, novl, sizeof(Overlap*), cmp_ovls_erate);
			break;
		case 1:
			qsort(ctx->ovl_sorted, novl, sizeof(Overlap*), cmp_ovls_length);
			break;
		default:
			fprintf(stderr, "[WARNING] Unknown sort option: %d. Skip sorting!", ctx->sort);
			break;
	}
}

static void filter_byDepth(FilterContext *ctx, Overlap *ovl, int novl)
{
	int i = 0;
	int j;

	int ndiscarded = 0;
	if (ctx->erate >= 0)
	{
		for (i = 0; i < novl; i++)
		{
			Overlap *o = ovl + i;
			if ((200. * o->path.diffs) / ((o->path.aepos - o->path.abpos) + (o->path.bepos - o->path.bbpos)) > ctx->erate)
			{
				ndiscarded++;
				o->flags |= OVL_DISCARD;
				if (ctx->verbose > 1)
				{
					printf(" DISCARD OVL ERATE: %d vs %d a[%d,%d] b[%d,%d] %.2f\n", o->aread, o->bread, o->path.abpos, o->path.aepos, o->path.bbpos, o->path.bepos, (200. * o->path.diffs) / ((o->path.aepos - o->path.abpos) + (o->path.bepos - o->path.bbpos)));
				}
				ctx->nFilteredLas++;
			}
		}
	}

	if (novl - ndiscarded <= ctx->depth)
		return;

	bzero(ctx->coverageHist, sizeof(int) * (1 + DB_READ_MAXLEN(ctx->db) / ctx->twidth));
	int abidx, aeidx;
	int abrmd, aermd;

	int nkept = 0;
	for (i = 0; i < novl; i++)
	{
		Overlap *o = ctx->ovl_sorted[i];
		abidx = o->path.abpos / ctx->twidth;
		abrmd = o->path.abpos % ctx->twidth;
		aeidx = o->path.aepos / ctx->twidth;
		aermd = o->path.aepos % ctx->twidth;

		if (abrmd && abrmd > (int) (0.2 * ctx->twidth))
		{
			abidx++;
		}

		if (o->path.aepos < DB_READ_LEN(ctx->db, o->aread) && aermd < ctx->twidth - (int) (0.2 * ctx->twidth))
		{
			aeidx--;
		}

		if (nkept > ctx->depth) // check if we need to add this overlap
		{
			int nAboveDepth = 0;
			int skipForSure = 0;
			for (j = abidx; j < aeidx; j++)
			{
				if (ctx->coverageHist[j] + 1 >= 1.2 * ctx->depth)
				{
					skipForSure = 1;
					break;
				}
				if (ctx->coverageHist[j] + 1 >= ctx->depth)
				{
					nAboveDepth++;
				}
			}
			// ignore overlap if more than 50% of segments are already above max coverage
			if (skipForSure || nAboveDepth > (int) 0.5 * (aeidx - abidx + 1))
			{
				o->flags |= OVL_DISCARD;
				if (ctx->verbose > 1)
				{
					printf(" DISCARD OVL HGH_COV: %d vs %d a[%d,%d] b[%d,%d] %.2f\n", o->aread, o->bread, o->path.abpos, o->path.aepos, o->path.bbpos, o->path.bepos, (200. * o->path.diffs) / ((o->path.aepos - o->path.abpos) + (o->path.bepos - o->path.bbpos)));
				}
				continue;
			}
		}
		for (j = abidx; j < aeidx; j++)
		{
			ctx->coverageHist[j]++;
		}
		o->flags |= OVL_TEMP;
		nkept++;
		if (ctx->verbose > 1)
		{
			printf(" KEEP OVL: %d vs %d a[%d,%d] b[%d,%d] %.2f\n", o->aread, o->bread, o->path.abpos, o->path.aepos, o->path.bbpos, o->path.bepos, (200. * o->path.diffs) / ((o->path.aepos - o->path.abpos) + (o->path.bepos - o->path.bbpos)));
		}
	}
}

static int filter_handler(void *_ctx, Overlap *ovl, int novl)
{
	FilterContext *ctx = (FilterContext*) _ctx;
	int j;

	if (ctx->trim)
	{
		for (j = 0; j < novl; j++)
		{
			trim_overlap(ctx->trim, ovl + j);
		}
	}

	// 1. sort overlaps
	sort_overlaps(ctx, ovl, novl);

	// 2. filter by coverage
	filter_byDepth(ctx, ovl, novl);

	return 1;

}

extern char *optarg;
extern int optind, opterr, optopt;

static void usage()
{
	fprintf(stderr, "[-pvTL] [-ds <int>] [-e <float>] [-t <track>] <db> <overlaps_in> <overlaps_out>\n");
	fprintf(stderr, "options: -v         ... verbose\n");
	fprintf(stderr, "         -d <int>   ... max coverage depth\n");
	fprintf(stderr, "         -e <float> ... max error rate\n");
	fprintf(stderr, "         -p         ... purge discarded overlaps\n");
	fprintf(stderr, "         -t         ... trim track name (%s)\n", DEF_ARG_T);
	fprintf(stderr, "         -T         ... trim overlaps (%d)\n", DEF_ARG_TT);
	fprintf(stderr, "         -L         ... two pass processing with read caching\n");
	fprintf(stderr, "         -s <int>   ... sort by 0 - error rate, 1 - alignment length \n");
}

int main(int argc, char *argv[])
{
	HITS_DB db;
	FilterContext fctx;
	PassContext *pctx;
	FILE *fileOvlIn;
	FILE *fileOvlOut;

	bzero(&fctx, sizeof(FilterContext));

	fctx.db = &db;
	fctx.erate = -1.0;

	char *arg_trimTrack = DEF_ARG_T;

	int arg_purge = 0;

	fctx.verbose = 0;

	int c;
	opterr = 0;
	while ((c = getopt(argc, argv, "pvTLd:s:e:t:")) != -1)
	{
		switch (c)
		{
			case 'p':
				arg_purge = 1;
				break;
			case 'v':
				fctx.verbose = 1;
				break;
			case 'T':
				fctx.do_trim = 1;
				break;
			case 'L':
				fctx.useRLoader = 1;
				break;
			case 'd':
				fctx.depth = atoi(optarg);
				break;
			case 's':
				fctx.sort = atoi(optarg);
				break;
			case 'e':
				fctx.erate = atof(optarg);
				break;
			case 't':
				arg_trimTrack = optarg;
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

	char *pcPathReadsIn = argv[optind++];
	char *pcPathOverlapsIn = argv[optind++];
	char *pcPathOverlapsOut = argv[optind++];

	if ((fileOvlIn = fopen(pcPathOverlapsIn, "r")) == NULL)
	{
		fprintf(stderr, "[ERROR] could not open %s\n", pcPathOverlapsIn);
		exit(1);
	}

	if ((fileOvlOut = fopen(pcPathOverlapsOut, "w")) == NULL)
	{
		fprintf(stderr, "[ERROR] could not open %s\n", pcPathOverlapsOut);
		exit(1);
	}

	if (Open_DB(pcPathReadsIn, &db))
	{
		fprintf(stderr, "[ERROR] could not open %s\n", pcPathReadsIn);
		exit(1);
	}

	fctx.trackTrim = track_load(&db, arg_trimTrack);

	if (!fctx.trackTrim && fctx.do_trim)
	{
		fprintf(stderr, "[WARNING] could not load track %s\n", arg_trimTrack);
		exit(1);
	}

	// passes

	if (fctx.useRLoader)
	{
		fctx.rl = rl_init(&db, 1);

		pctx = pass_init(fileOvlIn, NULL);

		pctx->data = &fctx;
		pctx->split_b = 1;
		pctx->load_trace = 0;

		pass(pctx, loader_handler);
		rl_load_added(fctx.rl);
		pass_free(pctx);
	}

	pctx = pass_init(fileOvlIn, fileOvlOut);

	pctx->split_b = 0;
	pctx->load_trace = 1;
	pctx->unpack_trace = 1;
	pctx->data = &fctx;
	pctx->write_overlaps = 1;
	pctx->purge_discarded = arg_purge;

	filter_pre(pctx, &fctx);

	pass(pctx, filter_handler);

	filter_post(&fctx);

	pass_free(pctx);

	// cleanup

	if (fctx.useRLoader)
	{
		rl_free(fctx.rl);
	}

	Close_DB(&db);
	fclose(fileOvlOut);
	fclose(fileOvlIn);

	return 0;
}
