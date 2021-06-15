#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/param.h>
#include <unistd.h>

#include "lib/colors.h"
#include "lib/oflags.h"
#include "lib/pass.h"
#include "lib/tracks.h"
#include "lib/utils.h"

#include "dalign/align.h"
#include "db/DB.h"

// constants

#define DEF_ARG_O  0
#define DEF_ARG_E  100

// toggles

#define VERBOSE
#undef DEBUG

typedef struct
{
    HITS_DB* db;

    int min_aln_len;
    int max_erate;

    // mask pass
    char* cov_read_active;

} MaskContext;


static void usage()
{
    printf( "usage:   [-t <track>] [-boe <int>] <db> <overlaps>\n" );
  //  printf( "options:  -t ... track name (" TRACK_REPEATS ")\n" );

    printf( "          -o ... min overlap length (default: %d)\n", DEF_ARG_O);
    printf( "          -e ... max erate [0-100] (default: %d)\n", DEF_ARG_E);
//   printf( "          -b ... track block\n" );
}

static void pre_mask( MaskContext* ctx )
{
#ifdef VERBOSE
    printf( ANSI_COLOR_GREEN "PASS estimate coverage\n" ANSI_COLOR_RESET );
#endif

    ctx->cov_read_active = (char*)malloc( DB_READ_MAXLEN( ctx->db ) );

}

static void post_mask( MaskContext* ctx )
{
    free( ctx->cov_read_active );
}

static int handler_mask( void* _ctx, Overlap* ovl, int novl )
{
    MaskContext* ctx = (MaskContext*)_ctx;

    int ovlArlen = DB_READ_LEN( ctx->db, ovl->aread );

    int i;

    bzero( ctx->cov_read_active, DB_READ_MAXLEN( ctx->db ) );

    for ( i = 0; i < novl; i++ )
    {
        if ( !( DB_READ_FLAGS( ctx->db, ovl[ i ].bread ) & DB_BEST ) || ( ovl[ i ].flags & OVL_DISCARD ) )
        {
            continue;
        }

        if ( ovl[ i ].aread == ovl[ i ].bread )
            continue;

        if ( ovl[i].path.aepos - ovl[i].path.abpos < ctx->min_aln_len )
        {
            continue;
        }

        if ( (200.*ovl[i].path.diffs / ((ovl[i].path.aepos - ovl[i].path.abpos)+(ovl[i].path.bepos - ovl[i].path.bbpos))) > ctx->max_erate)
		{
			continue;
		}

        memset( ctx->cov_read_active + ovl[ i ].path.abpos, 1, ovl[ i ].path.aepos - ovl[ i ].path.abpos );
    }

    int m_beg=-1;
    int m_end=-1;
    for ( i = 0; i < ovlArlen; i++ )
    {
    	if(ctx->cov_read_active[ i ])
    	{
			if(m_beg == -1)
			{
				m_beg = i;
				m_end = i;
			}
			else
			{
				m_end = i;
			}
    	}
    	else
    	{
    		if(m_beg != -1)
    		{
    			printf("%d %d %d\n", ovl->aread, m_beg, m_end);
    			m_beg = m_end = -1;
    		}
    	}
    }

    return 1;
}


int main( int argc, char* argv[] )
{
    HITS_DB db;
    PassContext* pctx;
    MaskContext rctx;
    FILE* fileOvlIn;

    bzero( &rctx, sizeof( MaskContext ) );
    rctx.db = &db;

    // process arguments

    rctx.min_aln_len    = DEF_ARG_O;
    rctx.max_erate      = DEF_ARG_E;

    int c;

    opterr = 0;

    while ( ( c = getopt( argc, argv, "o:e:" ) ) != -1 )
    {
        switch ( c )
        {
            case 'o':
                rctx.min_aln_len = atoi(optarg);
                break;

            case 'e':
                rctx.max_erate = atoi(optarg);
                break;

            default:
                usage();
                exit( 1 );
        }
    }

    if ( argc - optind != 2 )
    {
        usage();
        exit( 1 );
    }

    char* pcPathReadsIn  = argv[ optind++ ];
    char* pcPathOverlaps = argv[ optind++ ];

    if ( ( fileOvlIn = fopen( pcPathOverlaps, "r" ) ) == NULL )
    {
        fprintf( stderr, "could not open '%s'\n", pcPathOverlaps );
        exit( 1 );
    }


    // init

    pctx = pass_init( fileOvlIn, NULL );

    pctx->split_b      = 0;
    pctx->load_trace   = 1;
    pctx->unpack_trace = 1;
    pctx->data         = &rctx;

    Open_DB( pcPathReadsIn, &db );

    // passes

    pre_mask( &rctx );
	pass( pctx, handler_mask );
	post_mask( &rctx );

    // cleanup

    pass_free( pctx );

    fclose( fileOvlIn );

    Close_DB( &db );

    return 0;
}
