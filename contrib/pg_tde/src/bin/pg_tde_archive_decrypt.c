#include "postgres_fe.h"

#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>

#include "access/xlog_internal.h"
#include "access/xlog_smgr.h"
#include "common/logging.h"

#include "access/pg_tde_fe_init.h"
#include "access/pg_tde_xlog_smgr.h"

static void
write_decrypted_segment(const char *segpath, const char *segname, int pipewr)
{
	int			fd;
	off_t		fsize;
	int			r;
	TimeLineID	tli;
	XLogSegNo	segno;
	PGAlignedXLogBlock buf;
	off_t		pos = 0;

	fd = open(segpath, O_RDONLY | PG_BINARY, 0);
	if (fd < 0)
		pg_fatal("could not open file \"%s\": %m", segname);

	/*
	 * WalSegSz extracted from the first page header but it might be
	 * encrypted. But we need to know the segment seize to decrypt it (it's
	 * required for encryption offset calculations). So we get the segment
	 * size from the file's actual size. XLogLongPageHeaderData->xlp_seg_size
	 * there is "just as a cross-check" anyway.
	 */
	fsize = lseek(fd, 0, SEEK_END);
	XLogFromFileName(segname, &tli, &segno, fsize);

	r = xlog_smgr->seg_read(fd, buf.data, XLOG_BLCKSZ, pos, tli, segno, fsize);

	if (r == XLOG_BLCKSZ)
	{
		XLogLongPageHeader longhdr = (XLogLongPageHeader) buf.data;
		int			WalSegSz = longhdr->xlp_seg_size;

		if (WalSegSz != fsize)
			pg_fatal("mismatch of segment size in WAL file \"%s\" (header: %d bytes, file size: %ld bytes)",
					 segname, WalSegSz, fsize);

		if (!IsValidWalSegSize(WalSegSz))
		{
			pg_log_error(ngettext("invalid WAL segment size in WAL file \"%s\" (%d byte)",
								  "invalid WAL segment size in WAL file \"%s\" (%d bytes)",
								  WalSegSz),
						 segname, WalSegSz);
			pg_log_error_detail("The WAL segment size must be a power of two between 1 MB and 1 GB.");
			exit(1);
		}
	}
	else if (r < 0)
		pg_fatal("could not read file \"%s\": %m",
				 segname);
	else
		pg_fatal("could not read file \"%s\": read %d of %d",
				 segname, r, XLOG_BLCKSZ);

	pos += XLOG_BLCKSZ;

	/* TODO: handle interrupted write */
	r = write(pipewr, buf.data, XLOG_BLCKSZ);
	if (r != XLOG_BLCKSZ)
		pg_fatal("could not read pipe: %m");

	while (1)
	{
		r = xlog_smgr->seg_read(fd, buf.data, XLOG_BLCKSZ, pos, tli, segno, fsize);

		if (r == 0)
			break;
		else if (r < 0)
			pg_fatal("could not read file \"%s\": %m", segname);
		else if (r != XLOG_BLCKSZ)
			pg_fatal("could not read file \"%s\": read %d of %d",
					 segname, r, XLOG_BLCKSZ);

		pos += XLOG_BLCKSZ;

		/* TODO: handle interrupted write */
		r = write(pipewr, buf.data, XLOG_BLCKSZ);
		if (r != XLOG_BLCKSZ)
			pg_fatal("could not read pipe: %m");
	}

	close(fd);
	close(pipewr);
}

int
main(int argc, char *argv[])
{
	char	   *segpath;
	char	   *sep;
	char	   *segname;
	char		stdindir[MAXPGPATH] = "/tmp/pgtdewrapXXXXXX";
	char		stdinpath[MAXPGPATH];
	char	   *s;
	bool		issegment;
	int			pipefd[2];
	pid_t		child;
	int			status;
	int			r;

	pg_logging_init(argv[0]);

	if (argc < 3)
		pg_fatal("too few arguments");

	segpath = argv[1];

	pg_tde_fe_init("pg_tde");
	TDEXLogSmgrInit();

	sep = strrchr(segpath, '/');

	if (sep != NULL)
		segname = sep + 1;
	else
		segname = segpath;

	issegment = strlen(segname) == 24;

	if (issegment)
	{
		if (mkdtemp(stdindir) == NULL)
			pg_fatal("could not create temporary directory \"%s\": %m", stdindir);

		/* TODO: Handle truncation */
		s = strcpy(stdinpath, stdindir);
		s = strcpy(s, "/");
		strcpy(s, segname);

		if (pipe(pipefd) < 0)
			pg_fatal("could not create pipe: %m");

		if (symlink("/dev/stdin", stdinpath) < 0)
			pg_fatal("could not create symlink \"%s\": %m", stdinpath);

		for (int i = 2; i < argc; i++)
			if (strcmp(segpath, argv[i]) == 0)
				argv[i] = stdinpath;
	}

	child = fork();
	if (child == 0)
	{
		if (issegment)
		{
			close(0);
			dup2(pipefd[0], 0);
			close(pipefd[0]);
			close(pipefd[1]);
		}

		if (execvp(argv[2], argv + 2) < 0)
			pg_fatal("exec failed: %m");
	}
	else if (child < 0)
		pg_fatal("could not create background process: %m");

	if (issegment)
	{
		close(pipefd[0]);
		write_decrypted_segment(segpath, segname, pipefd[1]);
	}

	r = waitpid(child, &status, 0);
	if (r == (pid_t) -1)
		pg_fatal("could not wait for child process: %m");
	if (r != child)
		pg_fatal("child %d died, expected %d", (int) r, (int) child);
	if (status != 0)
		pg_fatal("%s", wait_result_to_str(status));

	if (issegment && unlink(stdinpath) < 0)
		pg_log_warning("could not remove file \"%s\": %m", stdinpath);
	if (issegment && rmdir(stdindir) < 0)
		pg_log_warning("could not remove directory \"%s\": %m", stdindir);

	return 0;
}
