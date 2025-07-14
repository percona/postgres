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
write_encrypted_segment(const char *segpath, const char *segname, int piperd)
{
	int			fd;
	PGAlignedXLogBlock buf;
	int			r;
	int			w;
	int			pos = 0;
	XLogLongPageHeader longhdr;
	int			WalSegSz;
	TimeLineID	tli;
	XLogSegNo	segno;

	fd = open(segpath, O_CREAT | O_WRONLY | PG_BINARY, 0666);
	if (fd < 0)
		pg_fatal("could not open file \"%s\": %m", segpath);

	r = read(piperd, buf.data, XLOG_BLCKSZ);

	/* TODO: Handle interrupts? */
	if (r < 0)
		pg_fatal("could not read from pipe: %m");
	else if (r != XLOG_BLCKSZ)
		pg_fatal("could not read from pipe: read %d of %d",
				 r, XLOG_BLCKSZ);

	longhdr = (XLogLongPageHeader) buf.data;
	WalSegSz = longhdr->xlp_seg_size;

	if (!IsValidWalSegSize(WalSegSz))
	{
		pg_log_error(ngettext("invalid WAL segment size in WAL file \"%s\" (%d byte)",
							  "invalid WAL segment size in WAL file \"%s\" (%d bytes)",
							  WalSegSz),
					 segname, WalSegSz);
		pg_log_error_detail("The WAL segment size must be a power of two between 1 MB and 1 GB.");
		exit(1);
	}

	XLogFromFileName(segname, &tli, &segno, WalSegSz);

	TDEXLogSmgrInitWriteReuseKey();

	w = xlog_smgr->seg_write(fd, buf.data, r, pos, tli, segno, WalSegSz);

	if (w < 0)
		pg_fatal("could not write file \"%s\": %m", segpath);
	else if (w != r)
		pg_fatal("could not write file \"%s\": wrote %d of %d",
				 segpath, w, r);

	pos += w;

	while (1)
	{
		r = read(piperd, buf.data, XLOG_BLCKSZ);

		if (r == 0)
			break;
		else if (r < 0)
			pg_fatal("could not read from pipe: %m");

		w = xlog_smgr->seg_write(fd, buf.data, r, pos, tli, segno, WalSegSz);

		if (w < 0)
			pg_fatal("could not write file \"%s\": %m", segpath);
		else if (w != r)
			pg_fatal("could not write file \"%s\": wrote %d of %d",
					 segpath, w, r);

		pos += w;
	}

	close(fd);
	close(piperd);
}

int
main(int argc, char *argv[])
{
	char	   *segname;
	char	   *targetpath;
	char	   *sep;
	char	   *targetname;
	char		stdoutdir[MAXPGPATH] = "/tmp/pgtdewrapXXXXXX";
	char		stdoutpath[MAXPGPATH];
	char	   *s;
	bool		issegment;
	int			pipefd[2];
	pid_t		child;
	int			status;
	int			r;

	pg_logging_init(argv[0]);

	if (argc < 4)
		pg_fatal("too few arguments");

	segname = argv[1];
	targetpath = argv[2];

	pg_tde_fe_init("pg_tde");
	TDEXLogSmgrInit();

	sep = strrchr(targetpath, '/');

	if (sep != NULL)
		targetname = sep + 1;
	else
		targetname = targetpath;

	issegment = strlen(segname) == 24;

	if (issegment)
	{
		if (mkdtemp(stdoutdir) == NULL)
			pg_fatal("could not create temporary directory \"%s\": %m", stdoutdir);

		/* TODO: Handle truncation */
		s = strcpy(stdoutpath, stdoutdir);
		s = strcpy(s, "/");
		strcpy(s, targetname);

		if (pipe(pipefd) < 0)
			pg_fatal("could not create pipe: %m");

		if (symlink("/dev/stdout", stdoutpath) < 0)
			pg_fatal("could not create symlink \"%s\": %m", stdoutpath);

		for (int i = 2; i < argc; i++)
			if (strcmp(targetpath, argv[i]) == 0)
				argv[i] = stdoutpath;
	}

	child = fork();
	if (child == 0)
	{
		if (issegment)
		{
			close(1);
			dup2(pipefd[1], 1);
			close(pipefd[0]);
			close(pipefd[1]);
		}

		if (execvp(argv[3], argv + 3) < 0)
			pg_fatal("exec failed: %m");
	}
	else if (child < 0)
		pg_fatal("could not create background process: %m");

	if (issegment)
	{
		close(pipefd[1]);
		write_encrypted_segment(targetpath, segname, pipefd[0]);
	}

	r = waitpid(child, &status, 0);
	if (r == (pid_t) -1)
		pg_fatal("could not wait for child process: %m");
	if (r != child)
		pg_fatal("child %d died, expected %d", (int) r, (int) child);
	if (status != 0)
		pg_fatal("%s", wait_result_to_str(status));

	if (issegment && unlink(stdoutpath) < 0)
		pg_log_warning("could not remove file \"%s\": %m", stdoutpath);
	if (issegment && rmdir(stdoutdir) < 0)
		pg_log_warning("could not remove directory \"%s\": %m", stdoutdir);

	return 0;
}
