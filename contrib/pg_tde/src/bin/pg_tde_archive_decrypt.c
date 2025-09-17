#include "postgres_fe.h"

#include "access/xlog_internal.h"
#include "access/xlog_smgr.h"
#include "common/logging.h"
#include "common/percentrepl.h"

#include "access/pg_tde_fe_init.h"
#include "access/pg_tde_xlog_smgr.h"

#include <sys/stat.h>
#include <sys/statvfs.h>
#include <signal.h>

#define TMPFS_DIRECTORY "/dev/shm"

static char g_tmpdir[MAXPGPATH] = "";
static char g_tmppath[MAXPGPATH] = "";

static void
cleanup_tmp(void)
{
	if (g_tmppath[0] != '\0')
	{
		if (unlink(g_tmppath) < 0)
			pg_log_warning("could not remove file \"%s\": %m", g_tmppath);
		g_tmppath[0] = '\0';
	}
	if (g_tmpdir[0] != '\0')
	{
		if (rmdir(g_tmpdir) < 0)
			pg_log_warning("could not remove directory \"%s\": %m", g_tmpdir);
		g_tmpdir[0] = '\0';
	}
}

static void
signal_cleanup_and_exit(int sig)
{
	cleanup_tmp();
	_exit(128 + sig);
}

static bool
check_free_space_sufficient_bytes(const char *path, uint64 requiredBytes, uint64 *freeBytesOut)
{
	struct statvfs vfs;
	if (statvfs(path, &vfs) != 0)
		return false;
	uint64 freeBytes = (uint64) vfs.f_bavail * (uint64) vfs.f_frsize;
	if (freeBytesOut)
		*freeBytesOut = freeBytes;
	return freeBytes >= requiredBytes;
}

static bool
is_segment(const char *filename)
{
	return strspn(filename, "0123456789ABCDEF") == XLOG_FNAME_LEN &&
		(filename[XLOG_FNAME_LEN] == '\0' || strcmp(filename + XLOG_FNAME_LEN, ".partial") == 0);
}

static void
write_decrypted_segment(const char *segpath, const char *segname, const char *tmppath)
{
	int			segfd;
	int			tmpfd;
	off_t		fsize;
	int			r;
	int			w;
	TimeLineID	tli;
	XLogSegNo	segno;
	PGAlignedXLogBlock buf;
	off_t		pos = 0;

	segfd = open(segpath, O_RDONLY | PG_BINARY, 0);
	if (segfd < 0)
		pg_fatal("could not open file \"%s\": %m", segpath);

	tmpfd = open(tmppath, O_CREAT | O_WRONLY | PG_BINARY, 0666);
	if (tmpfd < 0)
		pg_fatal("could not open file \"%s\": %m", tmppath);

	/*
	 * WalSegSz extracted from the first page header but it might be
	 * encrypted. But we need to know the segment seize to decrypt it (it's
	 * required for encryption offset calculations). So we get the segment
	 * size from the file's actual size. XLogLongPageHeaderData->xlp_seg_size
	 * there is "just as a cross-check" anyway.
	 */
	fsize = lseek(segfd, 0, SEEK_END);
	XLogFromFileName(segname, &tli, &segno, fsize);

	r = xlog_smgr->seg_read(segfd, buf.data, XLOG_BLCKSZ, pos, tli, segno, fsize);

	if (r == XLOG_BLCKSZ)
	{
		XLogLongPageHeader longhdr = (XLogLongPageHeader) buf.data;
		int			walsegsz = longhdr->xlp_seg_size;

		if (walsegsz != fsize)
			pg_fatal("mismatch of segment size in WAL file \"%s\" (header: %d bytes, file size: %ld bytes)",
					 segname, walsegsz, fsize);

		if (!IsValidWalSegSize(walsegsz))
		{
			pg_log_error(ngettext("invalid WAL segment size in WAL file \"%s\" (%d byte)",
								  "invalid WAL segment size in WAL file \"%s\" (%d bytes)",
								  walsegsz),
						 segname, walsegsz);
			pg_log_error_detail("The WAL segment size must be a power of two between 1 MB and 1 GB.");
			exit(1);
		}
	}
	else if (r < 0)
		pg_fatal("could not read file \"%s\": %m",
				 segpath);
	else
		pg_fatal("could not read file \"%s\": read %d of %d",
				 segpath, r, XLOG_BLCKSZ);

	pos += r;

	w = write(tmpfd, buf.data, XLOG_BLCKSZ);

	if (w < 0)
		pg_fatal("could not write file \"%s\": %m", tmppath);
	else if (w != r)
		pg_fatal("could not write file \"%s\": wrote %d of %d",
				 tmppath, w, r);

	while (1)
	{
		r = xlog_smgr->seg_read(segfd, buf.data, XLOG_BLCKSZ, pos, tli, segno, fsize);

		if (r == 0)
			break;
		else if (r < 0)
			pg_fatal("could not read file \"%s\": %m", segpath);

		pos += r;

		w = write(tmpfd, buf.data, r);

		if (w < 0)
			pg_fatal("could not write file \"%s\": %m", tmppath);
		else if (w != r)
			pg_fatal("could not write file \"%s\": wrote %d of %d",
					 tmppath, w, r);
	}

	close(tmpfd);
	close(segfd);
}

static void
usage(const char *progname)
{
	printf(_("%s wraps an archive command to give the command unencrypted WAL.\n\n"), progname);
	printf(_("Usage:\n"));
	printf(_("  %s [OPTION]\n"), progname);
	printf(_("  %s DEST-NAME SOURCE-PATH ARCHIVE-COMMAND\n"), progname);
	printf(_("\nOptions:\n"));
	printf(_("  -V, --version   output version information, then exit\n"));
	printf(_("  -?, --help      show this help, then exit\n"));
	printf(_("  DEST-NAME       name of the WAL file to send to archive\n"));
	printf(_("  SOURCE-PATH     path of the source WAL segment to decrypt\n"));
	printf(_("  ARCHIVE-COMMAND archive command to wrap, %%p will be replaced with the\n"
			 "                  absolute path of the decrypted WAL segment, %%f with the name\n"));
	printf(_("\n"));
	printf(_("Note that any %%f or %%p parameter in ARCHIVE-COMMAND will have to be escaped\n"
			 "as %%%%f or %%%%p respectively if used as archive_command in postgresql.conf.\n"
			 "e.g.\n"
			 "  archive_command='%s %%f %%p \"cp %%%%p /mnt/server/archivedir/%%%%f\"'\n"
			 "or\n"
			 "  archive_command='%s %%f %%p \"pgbackrest --stanza=your_stanza archive-push %%%%p\"'\n"
			 "\n"), progname, progname);
}

int
main(int argc, char *argv[])
{
	const char *progname;
	char	   *targetname;
	char	   *sourcepath;
	char	   *command;
	char	   *sep;
	char	   *sourcename;
	char		tmpdir[MAXPGPATH] = TMPFS_DIRECTORY "/pg_tde_archiveXXXXXX";
	char		tmppath[MAXPGPATH];
	bool		issegment;
	int			rc;

	pg_logging_init(argv[0]);
	progname = get_progname(argv[0]);

	if (argc > 1)
	{
		if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-?") == 0)
		{
			usage(progname);
			exit(0);
		}
		if (strcmp(argv[1], "--version") == 0 || strcmp(argv[1], "-V") == 0)
		{
			puts("pg_tde_archive_decrypt (PostgreSQL) " PG_VERSION);
			exit(0);
		}
	}

	if (argc != 4)
	{
		pg_log_error("wrong number of arguments, 3 expected");
		pg_log_error_detail("Try \"%s --help\" for more information.", progname);
		exit(1);
	}

	targetname = argv[1];
	sourcepath = argv[2];
	command = argv[3];

	pg_tde_fe_init("pg_tde");
	TDEXLogSmgrInit();

	sep = strrchr(sourcepath, '/');

	if (sep != NULL)
		sourcename = sep + 1;
	else
		sourcename = sourcepath;

	issegment = is_segment(targetname);

	if (issegment)
	{
		char	   *s;
		struct stat st;
		uint64 requiredBytes = 0;
		uint64 freeBytes = 0;

		/*
		 * Estimate how much tmpfs space we need to hold the decrypted WAL file.
		 *
		 * Preferred path: use the size of the encrypted source file. For full
		 * segments this equals the WAL segment size (e.g., 16MB, 64MB). For
		 * partial segments it will be smaller, which is fine because we only
		 * decrypt and write as many bytes as exist in the source.
		 */
		if (stat(sourcepath, &st) == 0 && S_ISREG(st.st_mode))
			requiredBytes = (uint64) st.st_size;
		else
		{
			/*
			 * Fallback when stat fails or source is not a regular file: assume at
			 * least one WAL block (XLOG_BLCKSZ, typically 16KB). This case is not
			 * expected in normal operation, but avoids a zero-size estimate.
			 */
			requiredBytes = (uint64) XLOG_BLCKSZ;
		}

		/*
		 * Add a fixed safety margin (4MB).
		 *
		 * Rationale:
		 * - Provides headroom for directory entries, filesystem metadata and
		 *   small helper buffers so we don't hit ENOSPC mid-write.
		 * - Covers minor discrepancies (e.g., trailing partial page, alignment).
		 * - When the base is a full segment (commonly 16MB), 4MB is a small
		 *   relative slack (25%). When the base comes from the minimal fallback
		 *   (16KB), the large relative slack is intentional: the fallback is used
		 *   only when we cannot size the source, and in practice WAL segments are
		 *   much larger than 16KB. The extra headroom errs on the side of
		 *   failing fast rather than starting a write that will soon exhaust
		 *   tmpfs.
		 */
		requiredBytes += (uint64) (4 * 1024 * 1024);

		if (!check_free_space_sufficient_bytes(TMPFS_DIRECTORY, requiredBytes, &freeBytes))
		{
			pg_log_error("insufficient temporary space in '%s' for decrypted WAL (required: %llu bytes, free: %llu bytes)",
					 TMPFS_DIRECTORY, (unsigned long long) requiredBytes, (unsigned long long) freeBytes);
			exit(1);
		}

		if (mkdtemp(tmpdir) == NULL)
			pg_fatal("could not create temporary directory \"%s\": %m", tmpdir);

		s = stpcpy(tmppath, tmpdir);
		s = stpcpy(s, "/");
		stpcpy(s, sourcename);

		/* register for cleanup on exit and on signals */
		snprintf(g_tmpdir, sizeof(g_tmpdir), "%s", tmpdir);
		snprintf(g_tmppath, sizeof(g_tmppath), "%s", tmppath);
		atexit(cleanup_tmp);
		signal(SIGINT, signal_cleanup_and_exit);
		signal(SIGTERM, signal_cleanup_and_exit);

		command = replace_percent_placeholders(command,
											   "ARCHIVE-COMMAND", "fp",
											   targetname, tmppath);

		write_decrypted_segment(sourcepath, targetname, tmppath);
	}
	else
		command = replace_percent_placeholders(command,
											   "ARCHIVE-COMMAND", "fp",
											   targetname, sourcepath);
	rc = system(command);

	if (rc != 0)
	{
		if (rc == -1)
			pg_fatal("ARCHIVE-COMMAND \"%s\" failed: %m", command);
		else if (WIFEXITED(rc))
			pg_fatal("ARCHIVE-COMMAND \"%s\" failed with exit code %d",
					 command, WEXITSTATUS(rc));
		else if (WIFSIGNALED(rc))
			pg_fatal("ARCHIVE-COMMAND \"%s\" was terminated by signal %d: %s",
					 command, WTERMSIG(rc), pg_strsignal(WTERMSIG(rc)));
		else
			pg_fatal("ARCHIVE-COMMAND \"%s\" exited with unrecognized status %d",
					 command, rc);
	}

	free(command);

	/* No explicit cleanup here; atexit(cleanup_tmp) handles normal process exit. */

	return 0;
}
