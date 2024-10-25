/************************************************************************************\
*                                                                                    *
 * Copyright (c) 2014, Dr. Eugene W. Myers (EWM). All rights reserved.                *
 *                                                                                    *
 * Redistribution and use in source and binary forms, with or without modification,   *
 * are permitted provided that the following conditions are met:                      *
 *                                                                                    *
 *  · Redistributions of source code must retain the above copyright notice, this     *
 *    list of conditions and the following disclaimer.                                *
 *                                                                                    *
 *  · Redistributions in binary form must reproduce the above copyright notice, this  *
 *    list of conditions and the following disclaimer in the documentation and/or     *
 *    other materials provided with the distribution.                                 *
 *                                                                                    *
 *  · The name of EWM may not be used to endorse or promote products derived from     *
 *    this software without specific prior written permission.                        *
 *                                                                                    *
 * THIS SOFTWARE IS PROVIDED BY EWM ”AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,    *
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND       *
 * FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL EWM BE LIABLE   *
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES *
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS  *
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY      *
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     *
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN  *
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                                      *
 *                                                                                    *
 * For any issues regarding this software and its use, contact EWM at:                *
 *                                                                                    *
 *   Eugene W. Myers Jr.                                                              *
 *   Bautzner Str. 122e                                                               *
 *   01099 Dresden                                                                    *
 *   GERMANY                                                                          *
 *   Email: gene.myers@gmail.com                                                      *
 *                                                                                    *
 \************************************************************************************/

/*******************************************************************************************
 *
 *  Compressed data base module.  Auxiliary routines to open and manipulate a data base for
 *    which the sequence and read information are separated into two separate files, and the
 *    sequence is compressed into 2-bits for each base.  Support for tracks of additional
 *    information, and trimming according to the current partition.  Eventually will also
 *    support compressed quality information.
 *
 *  Author :  Gene Myers
 *  Date   :  July 2013
 *  Revised:  April 2014
 *
 ********************************************************************************************/

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/param.h>

#include "DB.h"

#ifdef HIDE_FILES
#define PATHSEP "/."
#else
#define PATHSEP "/"
#endif

/*******************************************************************************************
 *
 *  GENERAL UTILITIES
 *
 ********************************************************************************************/

char* Prog_Name;

#ifdef INTERACTIVE

char Ebuffer[ 1000 ];

#endif

int Count_Args(char *var)
{
	int cnt, lev;
	char *s;

	cnt = 1;
	lev = 0;
	for (s = var; *s != '\0'; s++)
		if (*s == ',')
		{
			if (lev == 0)
				cnt += 1;
		}
		else if (*s == '(')
			lev += 1;
		else if (*s == ')')
			lev -= 1;
	return (cnt);
}

void *Malloc(int64 size, char *mesg)
{
	void *p;

	if ((p = malloc(size)) == NULL)
	{
		if (mesg == NULL)
			EPRINTF(EPLACE, "%s: Out of memory\n", Prog_Name);
		else
			EPRINTF(EPLACE, "%s: Out of memory (%s)\n", Prog_Name, mesg);
	}
	return (p);
}

void *Realloc(void *p, int64 size, char *mesg)
{
	if (size <= 0)
		size = 1;
	if ((p = realloc(p, size)) == NULL)
	{
		if (mesg == NULL)
			EPRINTF(EPLACE, "%s: Out of memory\n", Prog_Name);
		else
			EPRINTF(EPLACE, "%s: Out of memory (%s)\n", Prog_Name, mesg);
	}
	return (p);
}

char *Strdup(char *name, char *mesg)
{
	char *s;

	if (name == NULL)
		return (NULL);
	if ((s = strdup(name)) == NULL)
	{
		if (mesg == NULL)
			EPRINTF(EPLACE, "%s: Out of memory\n", Prog_Name);
		else
			EPRINTF(EPLACE, "%s: Out of memory (%s)\n", Prog_Name, mesg);
	}
	return (s);
}

FILE *Fopen(char *name, char *mode)
{
	FILE *f;

	if (name == NULL || mode == NULL)
		return (NULL);
	if ((f = fopen(name, mode)) == NULL)
		EPRINTF(EPLACE, "%s: Cannot open %s for '%s'\n", Prog_Name, name, mode);
	return (f);
}

char *PathTo(char *name)
{
	char *path, *find;

	if (name == NULL)
		return (NULL);
	if ((find = rindex(name, '/')) != NULL)
	{
		*find = '\0';
		path = Strdup(name, "Extracting path from");
		*find = '/';
	}
	else
		path = Strdup(".", "Allocating default path");
	return (path);
}

char *Root(char *name, char *suffix)
{
	char *path, *find, *dot;
	int epos;

	if (name == NULL)
		return (NULL);
	find = rindex(name, '/');
	if (find == NULL)
		find = name;
	else
		find += 1;
	if (suffix == NULL)
	{
		dot = strchr(find, '.');
		if (dot != NULL)
			*dot = '\0';
		path = Strdup(find, "Extracting root from");
		if (dot != NULL)
			*dot = '.';
	}
	else
	{
		epos = strlen(find);
		epos -= strlen(suffix);
		if (epos > 0 && strcasecmp(find + epos, suffix) == 0)
		{
			find[epos] = '\0';
			path = Strdup(find, "Extracting root from");
			find[epos] = suffix[0];
		}
		else
			path = Strdup(find, "Allocating root");
	}
	return (path);
}

char *Catenate(char *path, char *sep, char *root, char *suffix)
{
	static char *cat = NULL;
	static int max = -1;
	int len;

	if (path == NULL || root == NULL || sep == NULL || suffix == NULL)
		return (NULL);
	len = strlen(path);
	len += strlen(sep);
	len += strlen(root);
	len += strlen(suffix);
	if (len > max)
	{
		max = ((int) (1.2 * len)) + 100;
		if ((cat = (char *) realloc(cat, max + 1)) == NULL)
		{
			EPRINTF(EPLACE, "%s: Out of memory (Making path name for %s)\n", Prog_Name, root);
			return (NULL);
		}
	}
	sprintf(cat, "%s%s%s%s", path, sep, root, suffix);
	return (cat);
}

char *Numbered_Suffix(char *left, int num, char *right)
{
	static char *suffix = NULL;
	static int max = -1;
	int len;

	if (left == NULL || right == NULL)
		return (NULL);
	len = strlen(left);
	len += strlen(right) + 40;
	if (len > max)
	{
		max = ((int) (1.2 * len)) + 100;
		if ((suffix = (char *) realloc(suffix, max + 1)) == NULL)
		{
			EPRINTF(EPLACE, "%s: Out of memory (Making number suffix for %d)\n", Prog_Name, num);
			return (NULL);
		}
	}
	sprintf(suffix, "%s%d%s", left, num, right);
	return (suffix);
}

#define COMMA ','

//  Print big integers with commas/periods for better readability

void Print_Number(int64 num, int width, FILE* out)
{
	if (width == 0)
	{
		if (num < 1000ll)
			fprintf(out, "%lld", num);
		else if (num < 1000000ll)
			fprintf(out, "%lld%c%03lld", num / 1000ll, COMMA, num % 1000ll);
		else if (num < 1000000000ll)
			fprintf(out, "%lld%c%03lld%c%03lld", num / 1000000ll,
			COMMA, (num % 1000000ll) / 1000ll, COMMA, num % 1000ll);
		else
			fprintf(out, "%lld%c%03lld%c%03lld%c%03lld", num / 1000000000ll,
			COMMA, (num % 1000000000ll) / 1000000ll,
			COMMA, (num % 1000000ll) / 1000ll, COMMA, num % 1000ll);
	}
	else
	{
		if (num < 1000ll)
			fprintf(out, "%*lld", width, num);
		else if (num < 1000000ll)
		{
			if (width <= 4)
				fprintf(out, "%lld%c%03lld", num / 1000ll, COMMA, num % 1000ll);
			else
				fprintf(out, "%*lld%c%03lld", width - 4, num / 1000ll, COMMA, num % 1000ll);
		}
		else if (num < 1000000000ll)
		{
			if (width <= 8)
				fprintf(out, "%lld%c%03lld%c%03lld", num / 1000000ll, COMMA, (num % 1000000ll) / 1000ll,
				COMMA, num % 1000ll);
			else
				fprintf(out, "%*lld%c%03lld%c%03lld", width - 8, num / 1000000ll, COMMA, (num % 1000000ll) / 1000ll,
				COMMA, num % 1000ll);
		}
		else
		{
			if (width <= 12)
				fprintf(out, "%lld%c%03lld%c%03lld%c%03lld", num / 1000000000ll, COMMA, (num % 1000000000ll) / 1000000ll, COMMA, (num % 1000000ll) / 1000ll,
						COMMA, num % 1000ll);
			else
				fprintf(out, "%*lld%c%03lld%c%03lld%c%03lld", width - 12, num / 1000000000ll, COMMA, (num % 1000000000ll) / 1000000ll, COMMA,
						(num % 1000000ll) / 1000ll, COMMA, num % 1000ll);
		}
	}
}

//  Return the number of digits, base 10, of num

int Number_Digits(int64 num)
{
	int digit;

	digit = 0;
	while (num >= 1)
	{
		num /= 10;
		digit += 1;
	}
	return (digit);
}

/*******************************************************************************************
 *
 *  READ COMPRESSION/DECOMPRESSION UTILITIES
 *
 ********************************************************************************************/

//  Compress read into 2-bits per base (from [0-3] per byte representation
void Compress_Read(int len, char* s)
{
	int i;
	char c, d;
	char *s0, *s1, *s2, *s3;

	s0 = s;
	s1 = s0 + 1;
	s2 = s1 + 1;
	s3 = s2 + 1;

	c = s1[len];
	d = s2[len];
	s0[len] = s1[len] = s2[len] = 0;

	for (i = 0; i < len; i += 4)
		*s++ = (char) ((s0[i] << 6) | (s1[i] << 4) | (s2[i] << 2) | s3[i]);

	s1[len] = c;
	s2[len] = d;
}

//  Uncompress read form 2-bits per base into [0-3] per byte representation

void Uncompress_Read(int len, char* s)
{
	int i, tlen, byte;
	char *s0, *s1, *s2, *s3;
	char* t;

	s0 = s;
	s1 = s0 + 1;
	s2 = s1 + 1;
	s3 = s2 + 1;

	tlen = (len - 1) / 4;

	t = s + tlen;
	for (i = tlen * 4; i >= 0; i -= 4)
	{
		byte = *t--;
		s0[i] = (char) ((byte >> 6) & 0x3);
		s1[i] = (char) ((byte >> 4) & 0x3);
		s2[i] = (char) ((byte >> 2) & 0x3);
		s3[i] = (char) (byte & 0x3);
	}
	s[len] = 4;
}

//  Convert read in [0-3] representation to ascii representation (end with '\n')

void Lower_Read(char* s)
{
	static char letter[4] =
	{ 'a', 'c', 'g', 't' };

	for (; *s != 4; s++)
		*s = letter[(int) *s];
	*s = '\0';
}

void Upper_Read(char* s)
{
	static char letter[4] =
	{ 'A', 'C', 'G', 'T' };

	for (; *s != 4; s++)
		*s = letter[(int) *s];
	*s = '\0';
}

//  Convert read in ascii representation to [0-3] representation (end with 4)

void Number_Read(char* s)
{
	static char number[128] =
	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
			0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };

	for (; *s != '\0'; s++)
		*s = number[(int) *s];
	*s = 4;
}

void Number_Arrow(char *s)
{ static char arrow[128] =
    { 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 0, 1, 2, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 2,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
    };

  for ( ; *s != '\0'; s++)
    *s = arrow[(int) *s];
  *s = 4;
}

/*******************************************************************************************
 *
 *  DB OPEN, TRIM & CLOSE ROUTINES
 *
 ********************************************************************************************/

// Open the given database or dam, "path" into the supplied HITS_DB record "db". If the name has
//   a part # in it then just the part is opened.  The index array is allocated (for all or
//   just the part) and read in.
// Return status of routine:
//    -1: The DB could not be opened for a reason reported by the routine to EPLACE
//     0: Open of DB proceeded without mishap
//     1: Open of DAM proceeded without mishap
int Open_DB(char* path, HITS_DB* db)
{
	return Open_DB_Block(path, db, -1);
}

int Open_DB_Block(char* path, HITS_DB* db, int part)
{
	HITS_DB dbcopy;
	char *root, *pwd, *bptr, *fptr, *cat;
	int nreads;
	FILE *index, *dbvis;
	int status, plen, isdam;
	int ufirst, ulast;

	status = -1;
	dbcopy = *db;

	plen = strlen(path);
	if (strcmp(path + (plen - 4), ".dam") == 0)
		root = Root(path, ".dam");
	else
		root = Root(path, ".db");
	pwd = PathTo(path);

	bptr = rindex(root, '.');

	if (part == -1)
	{
		if (bptr != NULL && bptr[1] != '\0' && bptr[1] != '-')
		{
			part = strtol(bptr + 1, &fptr, 10);
			if (*fptr != '\0' || part == 0)
				part = 0;
			else
				*bptr = '\0';
		}
		else
			part = 0;
	}
	else
	{
		if (bptr != NULL && bptr[1] != '\0' && bptr[1] != '-')
		{
			*bptr = '\0';
		}
	}

	isdam = 0;
	cat = Catenate(pwd, "/", root, ".db");
	if (cat == NULL)
		return (-1);
	if ((dbvis = fopen(cat, "r")) == NULL)
	{
		cat = Catenate(pwd, "/", root, ".dam");
		if (cat == NULL)
			return (-1);
		if ((dbvis = fopen(cat, "r")) == NULL)
		{
			EPRINTF( EPLACE, "%s: Could not open database %s\n", Prog_Name, path);
			goto error;
		}
		isdam = 1;
	}

	if ((index = Fopen(Catenate(pwd, PATHSEP, root, ".idx"), "r")) == NULL)
		goto error1;
	if (fread(db, sizeof(HITS_DB), 1, index) != 1)
	{
		EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
		goto error2;
	}

	// sanity check, freq must add up to 1

	float sum = db->freq[0] + db->freq[1] + db->freq[2] + db->freq[3];
	if (sum < 0.99 || sum > 1.01)
	{
		EPRINTF( EPLACE, "%s: Index file frequencies sum to %.2f. File corrupt.\n", Prog_Name, sum);
		goto error2;
	}

	// sanity check, make sure filesize and HITS_READ record count match

	struct stat st;
	stat(Catenate(pwd, PATHSEP, root, ".idx"), &st);
	if ((unsigned int) db->ureads != (st.st_size - sizeof(HITS_DB)) / sizeof(HITS_READ))
	{
		EPRINTF( EPLACE, "%s: Index file size and record count mismatch %u expected %zu present\n", Prog_Name, db->ureads,
				(size_t) (st.st_size - sizeof(HITS_DB)) / sizeof(HITS_READ));
		goto error2;
	}

	{
		int p, nblocks, nfiles;
		int64 size;
		char fname[MAX_NAME], prolog[MAX_NAME];

		nblocks = 0;
		if (fscanf(dbvis, DB_NFILE, &nfiles) != 1)
		{
			EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
			goto error2;
		}
		for (p = 0; p < nfiles; p++)
			if (fscanf(dbvis, DB_FDATA, &ulast, fname, prolog) != 3)
			{
				EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
				goto error2;
			}
		if (fscanf(dbvis, DB_NBLOCK, &nblocks) != 1)
		{
			if (part != 0)
			{
				EPRINTF( EPLACE, "%s: DB %s has not yet been partitioned, cannot request a block !\n", Prog_Name, root);
				goto error2;
			}
		}
		else
		{
			if (fscanf(dbvis, DB_PARAMS, &size) != 1)
			{
				EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
				goto error2;
			}
			if (part > nblocks)
			{
				EPRINTF( EPLACE, "%s: DB %s has only %d blocks\n", Prog_Name, root, nblocks);
				goto error2;
			}
		}

		if (part > 0)
		{
			for (p = 1; p <= part; p++)
				if (fscanf(dbvis, DB_BDATA, &ufirst) != 1)
				{
					EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
					goto error2;
				}
			if (fscanf(dbvis, DB_BDATA, &ulast) != 1)
			{
				EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
				goto error2;
			}
		}
		else
		{
			ufirst = 0;
			ulast = db->ureads;
		}
	}

	db->tracks = NULL;
	db->part = part;
	db->ufirst = ufirst;

	nreads = ulast - ufirst;
	if (part <= 0)
	{
		db->reads = (HITS_READ*) Malloc(sizeof(HITS_READ) * (nreads + 2), "Allocating Open_DB index");
		db->reads += 1;
		if (fread(db->reads, sizeof(HITS_READ), nreads, index) != (size_t) nreads)
		{
			EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
			free(db->reads);
			goto error2;
		}
	}
	else
	{
		HITS_READ* reads;
		int i, r, maxlen;
		int64 totlen;

		reads = (HITS_READ*) Malloc(sizeof(HITS_READ) * (nreads + 2), "Allocating Open_DB index");
		reads += 1;

		fseeko(index, sizeof(HITS_READ) * ufirst, SEEK_CUR);
		if (fread(reads, sizeof(HITS_READ), nreads, index) != (size_t) nreads)
		{
			EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
			free(reads);
			goto error2;
		}

		totlen = 0;
		maxlen = 0;
		for (i = 0; i < nreads; i++)
		{
			r = reads[i].rlen;
			totlen += r;
			if (r > maxlen)
				maxlen = r;
		}

		db->maxlen = maxlen;
		db->totlen = totlen;
		db->reads = reads;
	}

	((int*) (db->reads))[-1] = ulast - ufirst; //  Kludge, need these for DB part

	db->nreads = nreads;
	db->path = Strdup(Catenate(pwd, PATHSEP, root, ""), "Allocating Open_DB path");
	if (db->path == NULL)
		goto error2;
	db->bases = NULL;
	db->loaded = 0;

	status = isdam;

	error2: fclose(index);
	error1: fclose(dbvis);
	error: if (bptr != NULL)
		*bptr = '.';

	free(pwd);
	free(root);

	if (status < 0)
		*db = dbcopy;

	return (status);
}

// Shut down an open 'db' by freeing all associated space, including tracks and QV structures,
//   and any open file pointers.  The record pointed at by db however remains (the user
//   supplied it and so should free it).

void Close_DB(HITS_DB* db)
{
	HITS_TRACK *t, *p;

	if (db->loaded)
	{
		free(((char*) (db->bases)) - 1);
		db->bases = NULL;
	}
	else if (db->bases != NULL)
	{
		fclose((FILE*) db->bases);
		db->bases = NULL;
	}

	if (db->reads != NULL)
	{
		free(db->reads - 1);
		db->reads = NULL;
	}

	free(db->path);
	db->path = NULL;

	Close_QVs(db);

	for (t = db->tracks; t != NULL; t = p)
	{
		p = t->next;
		free(t->anno);
		free(t->data);
		free(t->name);
		free(t);
	}

	db->tracks = NULL;
}

// Return the size in bytes of the memory occupied by a given DB

int64 sizeof_DB(HITS_DB *db)
{ int64       s;
  HITS_TRACK *t;

  s = sizeof(HITS_DB)
    + sizeof(HITS_READ)*(db->nreads+2)
    + strlen(db->path)+1
    + (db->totlen+db->nreads+4);

  t = db->tracks;
  if (t != NULL && strcmp(t->name,".@qvs") == 0)
    { HITS_QV *q = (HITS_QV *) t;
      s += sizeof(HITS_QV)
         + sizeof(uint16) * db->nreads
         + q->ncodes * sizeof(QVcoding)
         + 6;
      t = t->next;
    }

  for (; t != NULL; t = t->next)
    { s += sizeof(HITS_TRACK)
         + strlen(t->name)+1
         + t->size * (db->nreads+1);
      if (t->data != NULL)
        { if (t->size == 8)
            s += sizeof(int)*((int64 *) t->anno)[db->nreads];
          else //  t->size == 4
            s += sizeof(int)*((int *) t->anno)[db->nreads];
        }
    }

  return (s);
}

/*******************************************************************************************
 *
 *  QV LOAD & CLOSE ROUTINES
 *
 ********************************************************************************************/

HITS_DB* Active_DB = NULL; //  Last db/qv used by "Load_QVentry"
HITS_QV* Active_QV;        //    Becomes invalid after closing

int Load_QVs(HITS_DB* db)
{
	FILE *quiva, *istub, *indx;
	char* root;
	uint16* table;
	HITS_QV* qvtrk;
	QVcoding *coding, *nx;
	int ncodes;

	if (db->tracks != NULL && strcmp(db->tracks->name, ".@qvs") == 0)
		return (0);

	if (db->reads[db->nreads - 1].coff < 0)
	{
		EPRINTF( EPLACE, "%s: The requested QVs have not been added to the DB!\n", Prog_Name);
		EXIT(1);
	}

	//  Open .qvs, .idx, and .db files

	quiva = Fopen(Catenate(db->path, "", "", ".qvs"), "r");
	if (quiva == NULL)
		return (-1);

	istub = NULL;
	indx = NULL;
	table = NULL;
	coding = NULL;
	qvtrk = NULL;

	root = rindex(db->path, '/') + 2;
	istub = Fopen(Catenate(PathTo(db->path), "/", root, ".db"), "r");
	if (istub == NULL)
		goto error;

	{
		int first, last, nfiles;
		char prolog[MAX_NAME], fname[MAX_NAME];
		int i, j;

		if (fscanf(istub, DB_NFILE, &nfiles) != 1)
		{
			EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
			goto error;
		}

		if (db->part > 0)
		{
			int pfirst, plast;
			int fbeg, fend;
			int n, k;
			FILE* indx;

			//  Determine first how many and which files span the block (fbeg to fend)

			pfirst = db->ufirst;
			plast = pfirst + db->nreads;

			first = 0;
			for (fbeg = 0; fbeg < nfiles; fbeg++)
			{
				if (fscanf(istub, DB_FDATA, &last, fname, prolog) != 3)
				{
					EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
					goto error;
				}
				if (last > pfirst)
					break;
				first = last;
			}
			for (fend = fbeg + 1; fend <= nfiles; fend++)
			{
				if (last >= plast)
					break;
				if (fscanf(istub, DB_FDATA, &last, fname, prolog) != 3)
				{
					EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
					goto error;
				}
				first = last;
			}

			indx = Fopen(Catenate(db->path, "", "", ".idx"), "r");
			ncodes = fend - fbeg;
			coding = (QVcoding*) Malloc(sizeof(QVcoding) * ncodes, "Allocating coding schemes");
			table = (uint16*) Malloc(sizeof(uint16) * db->nreads, "Allocating QV table indices");
			if (indx == NULL || coding == NULL || table == NULL)
			{
				ncodes = 0;
				goto error;
			}

			//  Carefully get the first coding scheme (its offset is most likely in a HITS_RECORD
			//    in .idx that is *not* in memory).  Get all the other coding schemes normally and
			//    assign the tables # for each read in the block in "tables".

			rewind(istub);
			if (fscanf(istub, DB_NFILE, &nfiles) != DB_NFILE_FIELDS)
			{
				EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
				ncodes = 0;
				goto error;
			}

			first = 0;
			for (n = 0; n < fbeg; n++)
			{
				if (fscanf(istub, DB_FDATA, &last, fname, prolog) != DB_FDATA_FIELDS)
				{
					EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
					ncodes = 0;
					goto error;
				}
				first = last;
			}

			for (n = fbeg; n < fend; n++)
			{
				if (fscanf(istub, DB_FDATA, &last, fname, prolog) != DB_FDATA_FIELDS)
				{
					EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
					ncodes = 0;
					goto error;
				}

				i = n - fbeg;
				if (first < pfirst)
				{
					HITS_READ read;

					fseeko(indx, sizeof(HITS_DB) + sizeof(HITS_READ) * first, SEEK_SET);
					if (fread(&read, sizeof(HITS_READ), 1, indx) != 1)
					{
						EPRINTF( EPLACE, "%s: Index file (.idx) of %s is junk\n", Prog_Name, root);
						ncodes = i;
						goto error;
					}
					fseeko(quiva, read.coff, SEEK_SET);
					nx = Read_QVcoding(quiva);
					if (nx == NULL)
					{
						ncodes = i;
						goto error;
					}
					coding[i] = *nx;
				}
				else
				{
					fseeko(quiva, db->reads[first - pfirst].coff, SEEK_SET);
					nx = Read_QVcoding(quiva);
					if (nx == NULL)
					{
						ncodes = i;
						goto error;
					}
					coding[i] = *nx;
					db->reads[first - pfirst].coff = ftello(quiva);
				}

				j = first - pfirst;
				if (j < 0)
					j = 0;
				k = last - pfirst;
				if (k > db->nreads)
					k = db->nreads;
				while (j < k)
					table[j++] = (uint16) i;

				first = last;
			}

			fclose(indx);
			indx = NULL;
		}

		else
		{ //  Load in coding scheme for each file, adjust .coff of first read in the file, and
		  //    record which table each read uses

			ncodes = nfiles;
			coding = (QVcoding*) Malloc(sizeof(QVcoding) * nfiles, "Allocating coding schemes");
			table = (uint16*) Malloc(sizeof(uint16) * db->nreads, "Allocating QV table indices");
			if (coding == NULL || table == NULL)
				goto error;

			first = 0;
			for (i = 0; i < nfiles; i++)
			{
				if (fscanf(istub, DB_FDATA, &last, fname, prolog) != 3)
				{
					EPRINTF( EPLACE, "%s: Stub file (.db) of %s is junk\n", Prog_Name, root);
					goto error;
				}

				fseeko(quiva, db->reads[first].coff, SEEK_SET);
				nx = Read_QVcoding(quiva);
				if (nx == NULL)
				{
					ncodes = i;
					goto error;
				}
				coding[i] = *nx;
				db->reads[first].coff = ftello(quiva);

				for (j = first; j < last; j++)
					table[j] = (uint16) i;

				first = last;
			}
		}

		//  Allocate and fill in the HITS_QV record and add it to the front of the
		//    track list

		qvtrk = (HITS_QV*) Malloc(sizeof(HITS_QV), "Allocating QV pseudo-track");
		if (qvtrk == NULL)
			goto error;
		qvtrk->name = Strdup(".@qvs", "Allocating QV pseudo-track name");
		if (qvtrk->name == NULL)
			goto error;
		qvtrk->next = db->tracks;
		db->tracks = (HITS_TRACK*) qvtrk;
		qvtrk->ncodes = ncodes;
		qvtrk->table = table;
		qvtrk->coding = coding;
		qvtrk->quiva = quiva;
	}

	fclose(istub);
	return (0);

	error: if (qvtrk != NULL)
		free(qvtrk);
	if (table != NULL)
		free(table);
	if (coding != NULL)
	{
		int i;
		for (i = 0; i < ncodes; i++)
			Free_QVcoding(coding + i);
		free(coding);
	}
	if (indx != NULL)
		fclose(indx);
	if (istub != NULL)
		fclose(istub);
	fclose(quiva);
	EXIT(1);
}

// Close the QV stream, free the QV pseudo track and all associated memory

void Close_QVs(HITS_DB* db)
{
	HITS_TRACK* track;
	HITS_QV* qvtrk;
	int i;

	Active_DB = NULL;

	track = db->tracks;
	if (track != NULL && strcmp(track->name, ".@qvs") == 0)
	{
		qvtrk = (HITS_QV*) track;
		for (i = 0; i < qvtrk->ncodes; i++)
			Free_QVcoding(qvtrk->coding + i);
		free(qvtrk->coding);
		free(qvtrk->table);
		fclose(qvtrk->quiva);
		db->tracks = track->next;
		free(track);
	}
	return;
}

/*******************************************************************************************
 *
 *  TRACK LOAD & CLOSE ROUTINES
 *
 ********************************************************************************************/

//  Return status of track:
//     0: Track is for DB
//    -1: Track is not the right size of DB
//    -2: Could not find the track
int Check_Track(HITS_DB* db, char* track)
{
	FILE* afile;
	int tracklen, size, ispart;
	int ureads;
	int newTrack = 0;

	afile = NULL;

	if (db->part > 0)
	{
		afile = fopen(Catenate(db->path, Numbered_Suffix(".", db->part, "."), track, ".anno"), "r");
		ispart = 1;
	}
	if (afile == NULL)
	{
		afile = fopen(Catenate(db->path, Numbered_Suffix(".", db->part, "."), track, ".a2"), "r");
		ispart = 1;
		newTrack = 1;
	}

	if (afile == NULL)
	{
		afile = fopen(Catenate(db->path, ".", track, ".anno"), "r");
		ispart = 0;
	}
	if (afile == NULL)
	{
		afile = fopen(Catenate(db->path, ".", track, ".a2"), "r");
		ispart = 0;
		newTrack = 1;
	}

	if (afile == NULL)
		return (-2);

	if (fread(&tracklen, sizeof(int), 1, afile) != 1)
		return (-1);
	if (fread(&size, sizeof(int), 1, afile) != 1)
		return (-1);

	fclose(afile);

	if (ispart && !newTrack)
		ureads = ((int*) (db->reads))[-1];
	else
		ureads = db->ureads;

	if (tracklen == ureads)
		return (0);
	else
		return (-1);
}

// If track is not already in the db's track list, then allocate all the storage for it,
//   read it in from the appropriate file, add it to the track list, and return a pointer
//   to the newly created HITS_TRACK record.  If the track does not exist or cannot be
//   opened for some reason, then NULL is returned.

HITS_TRACK* Load_Track(HITS_DB* db, char* track)
{
	FILE *afile, *dfile;
	int tracklen, size;
	int nreads, ispart;
	int ureads;
	void* anno;
	void* data;
	char* name;
	HITS_TRACK* record;

	if (track[0] == '.')
	{
		EPRINTF( EPLACE, "%s: Track name, '%s', cannot begin with a .\n", Prog_Name, track);
		EXIT(NULL);
	}

	for (record = db->tracks; record != NULL; record = record->next)
		if (strcmp(record->name, track) == 0)
			return (record);

	afile = NULL;
	if (db->part)
	{
		afile = fopen(Catenate(db->path, Numbered_Suffix(".", db->part, "."), track, ".anno"), "r");
		ispart = 1;
	}
	if (afile == NULL)
	{
		afile = fopen(Catenate(db->path, ".", track, ".anno"), "r");
		ispart = 0;
	}
	if (afile == NULL)
	{
		EPRINTF( EPLACE, "%s: Track '%s' does not exist\n", Prog_Name, track);
		return ( NULL);
	}

	dfile = NULL;
	anno = NULL;
	data = NULL;
	record = NULL;

	if (ispart)
		name = Catenate(db->path, Numbered_Suffix(".", db->part, "."), track, ".data");
	else
		name = Catenate(db->path, ".", track, ".data");
	if (name == NULL)
		goto error;
	dfile = fopen(name, "r");

	if (fread(&tracklen, sizeof(int), 1, afile) != 1)
	{
		EPRINTF( EPLACE, "%s: Track '%s' annotation file is junk\n", Prog_Name, track);
		goto error;
	}
	if (fread(&size, sizeof(int), 1, afile) != 1)
	{
		EPRINTF( EPLACE, "%s: Track '%s' annotation file is junk\n", Prog_Name, track);
		goto error;
	}
	if (size <= 0)
	{
		EPRINTF( EPLACE, "%s: Track '%s' annotation file is junk\n", Prog_Name, track);
		goto error;
	}

	if (ispart)
		ureads = ((int*) (db->reads))[-1];
	else
		ureads = db->ureads;

	if (tracklen != ureads)
	{
		EPRINTF( EPLACE, "%s: Track '%s' not same size as database (track: %d, db: %d)!\n", Prog_Name, track, tracklen, ureads);
		goto error;
	}
	if (!ispart && db->part > 0)
		fseeko(afile, size * db->ufirst, SEEK_CUR);
	nreads = db->nreads;

	anno = (void*) Malloc(size * (nreads + 1), "Allocating Track Anno Vector");
	if (anno == NULL)
		goto error;

	if (dfile != NULL)
	{
		int64 *anno8, off8, dlen;
		int *anno4, off4;
		int i;

		if (fread(anno, size, nreads + 1, afile) != (size_t) (nreads + 1))
		{
			EPRINTF( EPLACE, "%s: Track '%s' annotation file is junk\n", Prog_Name, track);
			goto error;
		}

		if (size == 4)
		{
			anno4 = (int*) anno;
			off4 = anno4[0];
			if (off4 != 0)
			{
				for (i = 0; i <= nreads; i++)
					anno4[i] -= off4;
				fseeko(dfile, off4, SEEK_SET);
			}
			dlen = anno4[nreads];
			data = (void*) Malloc(dlen, "Allocating Track Data Vector");
		}
		else
		{
			anno8 = (int64*) anno;
			off8 = anno8[0];
			if (off8 != 0)
			{
				for (i = 0; i <= nreads; i++)
					anno8[i] -= off8;
				fseeko(dfile, off8, SEEK_SET);
			}
			dlen = anno8[nreads];
			data = (void*) Malloc(dlen, "Allocating Track Data Vector");
		}
		if (data == NULL)
			goto error;
		if (dlen > 0)
		{
			if (fread(data, dlen, 1, dfile) != 1)
			{
				EPRINTF( EPLACE, "%s: Track '%s' data file size mismatch. Expected %lld\n", Prog_Name, track, dlen);
				goto error;
			}
		}
		fclose(dfile);
		dfile = NULL;
	}
	else
	{
		if (fread(anno, size, nreads, afile) != (size_t) nreads)
		{
			EPRINTF( EPLACE, "%s: Track '%s' annotation file is junk\n", Prog_Name, track);
			goto error;
		}
		data = NULL;
	}

	fclose(afile);

	record = (HITS_TRACK*) Malloc(sizeof(HITS_TRACK), "Allocating Track Record");
	if (record == NULL)
		goto error;
	record->name = Strdup(track, "Allocating Track Name");
	if (record->name == NULL)
		goto error;
	record->data = data;
	record->anno = anno;
	record->size = size;

	if (db->tracks != NULL && strcmp(db->tracks->name, ".@qvs") == 0)
	{
		record->next = db->tracks->next;
		db->tracks->next = record;
	}
	else
	{
		record->next = db->tracks;
		db->tracks = record;
	}

	return (record);

	error: if (record == NULL)
		free(record);
	if (data != NULL)
		free(data);
	if (anno != NULL)
		free(anno);
	if (dfile != NULL)
		fclose(dfile);
	fclose(afile);
	EXIT(NULL);
}

void Close_Track(HITS_DB* db, char* track)
{
	HITS_TRACK *record, *prev;

	prev = NULL;
	for (record = db->tracks; record != NULL; record = record->next)
	{
		if (strcmp(record->name, track) == 0)
		{
			free(record->anno);
			free(record->data);
			free(record->name);
			if (prev == NULL)
				db->tracks = record->next;
			else
				prev->next = record->next;
			free(record);
			return;
		}
		prev = record;
	}
	return;
}

/*******************************************************************************************
 *
 *  READ BUFFER ALLOCATION AND READ ACCESS
 *
 ********************************************************************************************/

// Allocate and return a buffer big enough for the largest read in 'db', leaving room
//   for an initial delimiter character
char* New_Read_Buffer(HITS_DB* db)
{
	char* read;

	read = (char*) Malloc(db->maxlen + 4, "Allocating New Read Buffer");
	if (read == NULL)
		EXIT(NULL);
	return (read + 1);
}

// Load into 'read' the i'th read in 'db'.  As an upper case ASCII string if ascii is 2, as a
//   lower-case ASCII string is ascii is 1, and as a numeric string over 0(A), 1(C), 2(G), and
//   3(T) otherwise.
//
// **NB**, the byte before read will be set to a delimiter character!

int Load_Read(HITS_DB* db, int i, char* read, int ascii)
{
	FILE* bases = (FILE*) db->bases;
	int64 off;
	int len, clen;
	HITS_READ* r = db->reads;

	if (i >= db->nreads)
	{
		EPRINTF( EPLACE, "%s: Index out of bounds (Load_Read)\n", Prog_Name);
		EXIT(1);
	}
	if (bases == NULL)
	{
		bases = Fopen(Catenate(db->path, "", "", ".bps"), "r");
		if (bases == NULL)
			EXIT(1);
		db->bases = (void*) bases;
	}

	off = r[i].boff;
	len = r[i].rlen;

	if (ftello(bases) != off)
		fseeko(bases, off, SEEK_SET);
	clen = COMPRESSED_LEN(len);
	if (clen > 0)
	{
		if (fread(read, clen, 1, bases) != 1)
		{
			EPRINTF( EPLACE, "%s: Failed read of .bps file (Load_Read)\n", Prog_Name);
			EXIT(1);
		}
	}
	Uncompress_Read(len, read);
	if (ascii == 1)
	{
		Lower_Read(read);
		read[-1] = '\0';
	}
	else if (ascii == 2)
	{
		Upper_Read(read);
		read[-1] = '\0';
	}
	else
		read[-1] = 4;
	return (0);
}

char* Load_Subread(HITS_DB* db, int i, int beg, int end, char* read, int ascii)
{
	FILE* bases = (FILE*) db->bases;
	int64 off;
	int len, clen;
	int bbeg, bend;
	HITS_READ* r = db->reads;

	if (i >= db->nreads)
	{
		EPRINTF( EPLACE, "%s: Index out of bounds (Load_Read)\n", Prog_Name);
		EXIT(NULL);
	}
	if (bases == NULL)
	{
		bases = Fopen(Catenate(db->path, "", "", ".bps"), "r");
		if (bases == NULL)
			EXIT(NULL);
		db->bases = (void*) bases;
	}

	bbeg = beg / 4;
	bend = (end - 1) / 4 + 1;

	off = r[i].boff + bbeg;
	len = end - beg;

	if (ftello(bases) != off)
		fseeko(bases, off, SEEK_SET);
	clen = bend - bbeg;
	if (clen > 0)
	{
		if (fread(read, clen, 1, bases) != 1)
		{
			EPRINTF( EPLACE, "%s: Failed read of .bps file (Load_Read)\n", Prog_Name);
			EXIT(NULL);
		}
	}
	Uncompress_Read(4 * clen, read);
	read += beg % 4;
	read[len] = 4;
	if (ascii == 1)
	{
		Lower_Read(read);
		read[-1] = '\0';
	}
	else if (ascii == 2)
	{
		Upper_Read(read);
		read[-1] = '\0';
	}
	else
		read[-1] = 4;

	return (read);
}

/*******************************************************************************************
 *
 *  QV BUFFER ALLOCATION QV READ ACCESS
 *
 ********************************************************************************************/

// Allocate and return a buffer of 5 vectors big enough for the largest read in 'db'
char** New_QV_Buffer(HITS_DB* db)
{
	char** entry;
	char* qvs;
	int i;

	qvs = (char*) Malloc(db->maxlen * 5, "Allocating New QV Buffer");
	entry = (char**) Malloc(sizeof(char*) * 5, "Allocating New QV Buffer");
	if (qvs == NULL || entry == NULL)
		EXIT(NULL);
	for (i = 0; i < 5; i++)
		entry[i] = qvs + i * db->maxlen;
	return (entry);
}

void Free_QV_Buffer(char** buf)
{
	free(buf[0]);
	free(buf);
}

// Load into entry the QV streams for the i'th read from db.  The parameter ascii applies to
//  the DELTAG stream as described for Load_Read.

int Load_QVentry(HITS_DB* db, int i, char** entry, int ascii)
{
	HITS_READ* reads;
	FILE* quiva;
	int rlen;

	if (db != Active_DB)
	{
		if (db->tracks == NULL || strcmp(db->tracks->name, ".@qvs") != 0)
		{
			EPRINTF( EPLACE, "%s: QV's are not loaded (Load_QVentry)\n", Prog_Name);
			EXIT(1);
		}
		Active_QV = (HITS_QV*) db->tracks;
		Active_DB = db;
	}
	if (i >= db->nreads)
	{
		EPRINTF( EPLACE, "%s: Index out of bounds (Load_QVentry)\n", Prog_Name);
		EXIT(1);
	}

	reads = db->reads;
	quiva = Active_QV->quiva;
	rlen = reads[i].rlen;

	fseeko(quiva, reads[i].coff, SEEK_SET);
	if (Uncompress_Next_QVentry(quiva, entry, Active_QV->coding + Active_QV->table[i], rlen))
		EXIT(1);

	if (ascii != 1)
	{
		char* deltag = entry[1];

		if (ascii != 2)
		{
			char x = deltag[rlen];
			deltag[rlen] = '\0';
			Number_Read(deltag);
			deltag[rlen] = x;
		}
		else
		{
			int j;
			int u = 'A' - 'a';

			for (j = 0; j < rlen; j++)
				deltag[j] = (char) (deltag[j] + u);
		}
	}

	return (0);
}

/*******************************************************************************************
 *
 *  BLOCK LOAD OF ALL READS (PRIMARILY FOR DALIGNER)
 *
 ********************************************************************************************/

// Allocate a block big enough for all the uncompressed sequences, read them into it,
//   reset the 'off' in each read record to be its in-memory offset, and set the
//   bases pointer to point at the block after closing the bases file.  If ascii is
//   non-zero then the reads are converted to ACGT ascii, otherwise the reads are left
//   as numeric strings over 0(A), 1(C), 2(G), and 3(T).
int Read_All_Sequences(HITS_DB* db, int ascii)
{
	FILE* bases;
	int nreads = db->nreads;
	HITS_READ* reads = db->reads;
	void (*translate)(char* s);

	char* seq;
	int64 o, off;
	int i, len, clen;

	bases = Fopen(Catenate(db->path, "", "", ".bps"), "r");
	if (bases == NULL)
		EXIT(1);

	seq = (char*) Malloc(db->totlen + nreads + 4, "Allocating All Sequence Reads");
	if (seq == NULL)
	{
		fclose(bases);
		EXIT(1);
	}

	*seq++ = 4;

	if (ascii == 1)
		translate = Lower_Read;
	else
		translate = Upper_Read;

	o = 0;
	for (i = 0; i < nreads; i++)
	{
		len = reads[i].rlen;
		off = reads[i].boff;
		if (ftello(bases) != off)
			fseeko(bases, off, SEEK_SET);
		clen = COMPRESSED_LEN(len);
		if (clen > 0)
		{
			if (fread(seq + o, clen, 1, bases) != 1)
			{
				EPRINTF( EPLACE, "%s: Read of .bps file failed (Read_All_Sequences)\n", Prog_Name);
				free(seq);
				fclose(bases);
				EXIT(1);
			}
		}
		Uncompress_Read(len, seq + o);
		if (ascii)
			translate(seq + o);
		reads[i].boff = o;
		o += (len + 1);
	}
	reads[nreads].boff = o;

	fclose(bases);

	db->bases = (void*) seq;
	db->loaded = 1;

	return (0);
}

int List_DB_Files(char* path, void actor(char* path, char* extension))
{
	int status, plen, rlen, dlen;
	char *root, *pwd, *name;
	int isdam;
	DIR* dirp;
	struct dirent* dp;

	status = 0;
	pwd = PathTo(path);
	plen = strlen(path);
	if (strcmp(path + (plen - 4), ".dam") == 0)
		root = Root(path, ".dam");
	else
		root = Root(path, ".db");
	rlen = strlen(root);

	if (root == NULL || pwd == NULL)
	{
		free(pwd);
		free(root);
		EXIT(1);
	}

	if ((dirp = opendir(pwd)) == NULL)
	{
		EPRINTF( EPLACE, "%s: Cannot open directory %s (List_DB_Files)\n", Prog_Name, pwd);
		status = -1;
		goto error;
	}

	isdam = 0;
	while ((dp = readdir(dirp)) != NULL) //   Get case dependent root name (if necessary)
	{
		name = dp->d_name;
		if (strcmp(name, Catenate("", "", root, ".db")) == 0)
			break;
		if (strcmp(name, Catenate("", "", root, ".dam")) == 0)
		{
			isdam = 1;
			break;
		}
		if (strcasecmp(name, Catenate("", "", root, ".db")) == 0)
		{
			strncpy(root, name, rlen);
			break;
		}
		if (strcasecmp(name, Catenate("", "", root, ".dam")) == 0)
		{
			strncpy(root, name, rlen);
			isdam = 1;
			break;
		}
	}
	if (dp == NULL)
	{
		EPRINTF( EPLACE, "%s: Cannot find %s (List_DB_Files)\n", Prog_Name, pwd);
		status = -1;
		closedir(dirp);
		goto error;
	}

	if (isdam)
		actor(Catenate(pwd, "/", root, ".dam"), "dam");
	else
		actor(Catenate(pwd, "/", root, ".db"), "db");

	rewinddir(dirp); //   Report each auxiliary file
	while ((dp = readdir(dirp)) != NULL)
	{
		name = dp->d_name;
		dlen = strlen(name);
#ifdef HIDE_FILES
		if (name[0] != '.')
			continue;
		dlen -= 1;
		name += 1;
#endif
		if (dlen < rlen + 1)
			continue;
		if (name[rlen] != '.')
			continue;
		if (strncmp(name, root, rlen) != 0)
			continue;
		actor(Catenate(pwd, PATHSEP, name, ""), name + (rlen + 1));
	}
	closedir(dirp);

	error: free(pwd);
	free(root);
	return (status);
}

void Print_Read(char* s, int width)
{
	int i;

	if (s[0] < 4)
	{
		for (i = 0; s[i] != 4; i++)
		{
			if (i % width == 0 && i != 0)
				printf("\n");
			printf("%d", s[i]);
		}
		printf("\n");
	}
	else
	{
		for (i = 0; s[i] != '\0'; i++)
		{
			if (i % width == 0 && i != 0)
				printf("\n");
			printf("%c", s[i]);
		}
		printf("\n");
	}
}

int DB_block_range(char* db, int block, int* _beg, int* _end)
{
	int beg = *_beg = -1;
	int end = *_end = -1;

	if (block <= 0)
	{
		return 0;
	}

	FILE* fileDb;
	char* path = (char*) malloc(strlen(db) + 20);
	char* root = Root(db, NULL);

	sprintf(path, "%s.db", root);

	free(root);

	if ((fileDb = fopen(path, "r")) == NULL)
	{
		fprintf( stderr, "failed to open database\n");
		return -1;
	}

	char buf[PATH_MAX + 128];
	int in_ranges = 0;
	int curb = 0;

	while (!feof(fileDb))
	{
		if (!fgets(buf, PATH_MAX + 127, fileDb))
		{
			break;
		}

		if (in_ranges)
		{
			char* num = buf;
			while (!isdigit(*num))
			{
				num += 1;
			}

			beg = end;
			end = atoi(num);

			if (curb == block)
			{
				*_beg = beg;
				*_end = end;

				break;
			}

			curb += 1;
		}
		else if (strstr(buf, "size = "))
		{
			in_ranges = 1;
		}
	}

	free(path);
	fclose(fileDb);

	return (*_beg < *_end);
}

int DB_Blocks(char* db) // HEIDELBERG_MODIFICATION
{
	FILE* fileDb;
	char* path = (char*) malloc(strlen(db) + 20);

	char* dir  = PathTo(db);
	char* root = Root(db, ".db");

	sprintf(path, "%s/%s.db", dir, root);

	free(root);
	free(dir);

	if ((fileDb = fopen(path, "r")) == NULL)
	{
		fprintf( stderr, "failed to open database %s\n", db);
		return -1;
	}

	int nfiles;

	if (fscanf(fileDb, "files = %d\n", &nfiles) != 1)
	{
		fprintf( stderr, "format error in database file %s\n", db);
		return -1;
	}

	int i;

	for (i = 0; i < nfiles; i++)
	{
		char buffer[30001];

		if (fgets(buffer, 30000, fileDb) == NULL)
		{
			fprintf( stderr, "format error in database file %s \n", db);
			return -1;
		}
	}

	int nblocks;

	if (fscanf(fileDb, "blocks = %d\n", &nblocks) != 1)
	{
		fprintf( stderr, "could not locate 'blocks' entry in db  %s \n", db);
		return -1;
	}

	fclose(fileDb);
	free(path);

	return nblocks;
}

char* getDir(int RUN_ID, int subjectID) // HEIDELBERG_MODIFICATION
{
	char* out = malloc(35);

	if (subjectID == 0) // complete DB
	{
		out[0] = '.';
		out[1] = '\0';
		return out;
	}

	if (RUN_ID < 10)
	{
		if (subjectID < 10)
		{
			sprintf(out, "d00%d_0000%d", RUN_ID, subjectID);
		}
		else if (subjectID < 100)
		{
			sprintf(out, "d00%d_000%d", RUN_ID, subjectID);
		}
		else if (subjectID < 1000)
		{
			sprintf(out, "d00%d_00%d", RUN_ID, subjectID);
		}
		else if (subjectID < 10000)
		{
			sprintf(out, "d00%d_0%d", RUN_ID, subjectID);
		}
		else
		{
			sprintf(out, "d00%d_%d", RUN_ID, subjectID);
		}
	}
	else if (RUN_ID < 100)
	{
		if (subjectID < 10)
		{
			sprintf(out, "d0%d_0000%d", RUN_ID, subjectID);
		}
		else if (subjectID < 100)
		{
			sprintf(out, "d0%d_000%d", RUN_ID, subjectID);
		}
		else if (subjectID < 1000)
		{
			sprintf(out, "d0%d_00%d", RUN_ID, subjectID);
		}
		else if (subjectID < 10000)
		{
			sprintf(out, "d0%d_0%d", RUN_ID, subjectID);
		}
		else
		{
			sprintf(out, "d0%d_%d", RUN_ID, subjectID);
		}
	}
	else
	{
		if (subjectID < 10)
		{
			sprintf(out, "d%d_0000%d", RUN_ID, subjectID);
		}
		else if (subjectID < 100)
		{
			sprintf(out, "d%d_000%d", RUN_ID, subjectID);
		}
		else if (subjectID < 1000)
		{
			sprintf(out, "d%d_00%d", RUN_ID, subjectID);
		}
		else if (subjectID < 10000)
		{
			sprintf(out, "d%d_0%d", RUN_ID, subjectID);
		}
		else
		{
			sprintf(out, "d%d_%d", RUN_ID, subjectID);
		}
	}

	return out;
}
