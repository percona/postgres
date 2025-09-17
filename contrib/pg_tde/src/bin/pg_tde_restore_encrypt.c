#include "postgres_fe.h"

#include "access/xlog_internal.h"
#include "access/xlog_smgr.h"
#include "common/logging.h"
#include "common/percentrepl.h"

#include "access/pg_tde_fe_init.h"
#include "access/pg_tde_xlog_smgr.h"

#include "catalog/pg_control.h"

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

/* Try to derive data directory by stripping "/pg_wal/..." from the target path. */
static bool
get_data_dir_from_targetpath(const char *targetpath, char *dataDirOut, size_t outLen)
{
    const char *needle = "/" XLOGDIR "/"; /* "/pg_wal/" */
    const char *pos = strstr(targetpath, needle);
    if (pos == NULL)
        return false;
    size_t dirLen = (size_t) (pos - targetpath);
    if (dirLen == 0 || dirLen >= outLen)
        return false;
    memcpy(dataDirOut, targetpath, dirLen);
    dataDirOut[dirLen] = '\0';
    return true;
}

/* Read xlog_seg_size from pg_control in the given data directory. */
static bool
read_wal_segment_size_from_control(const char *dataDir, uint32 *segSizeOut)
{
    char controlPath[MAXPGPATH];
    int fd;
    char buffer[PG_CONTROL_FILE_SIZE];
    ControlFileData ControlFile;

    snprintf(controlPath, sizeof(controlPath), "%s/%s", dataDir, XLOG_CONTROL_FILE);
    fd = open(controlPath, O_RDONLY | PG_BINARY, 0);
    if (fd < 0)
        return false;
    if (read(fd, buffer, PG_CONTROL_FILE_SIZE) != PG_CONTROL_FILE_SIZE)
    {
        close(fd);
        return false;
    }
    close(fd);

    memcpy(&ControlFile, buffer, sizeof(ControlFileData));
    if (!IsValidWalSegSize(ControlFile.xlog_seg_size))
        return false;
    *segSizeOut = ControlFile.xlog_seg_size;
    return true;
}

/*
 * Partial WAL segments are archived but never automatically fetched from the
 * archive by the restore_command. We support them here for symmetry though
 * since if someone would want to fetch a partial segment from the archive and
 * write it to pg_wal then they would want it encrypted.
 */
static bool
is_segment(const char *filename)
{
	return strspn(filename, "0123456789ABCDEF") == XLOG_FNAME_LEN &&
		(filename[XLOG_FNAME_LEN] == '\0' || strcmp(filename + XLOG_FNAME_LEN, ".partial") == 0);
}

static void
write_encrypted_segment(const char *segpath, const char *segname, const char *tmppath)
{
	int			tmpfd;
	int			segfd;
	PGAlignedXLogBlock buf;
	int			r;
	int			w;
	int			pos = 0;
	XLogLongPageHeader longhdr;
	int			walsegsz;
	TimeLineID	tli;
	XLogSegNo	segno;

	tmpfd = open(tmppath, O_RDONLY | PG_BINARY, 0);
	if (tmpfd < 0)
		pg_fatal("could not open file \"%s\": %m", tmppath);

	segfd = open(segpath, O_CREAT | O_WRONLY | PG_BINARY, 0666);
	if (segfd < 0)
		pg_fatal("could not open file \"%s\": %m", segpath);

	r = read(tmpfd, buf.data, XLOG_BLCKSZ);

	if (r < 0)
		pg_fatal("could not read file \"%s\": %m", tmppath);
	else if (r != XLOG_BLCKSZ)
		pg_fatal("could not read file \"%s\": read %d of %d",
				 tmppath, r, XLOG_BLCKSZ);

	longhdr = (XLogLongPageHeader) buf.data;
	walsegsz = longhdr->xlp_seg_size;

	if (!IsValidWalSegSize(walsegsz))
	{
		pg_log_error(ngettext("invalid WAL segment size in WAL file \"%s\" (%d byte)",
							  "invalid WAL segment size in WAL file \"%s\" (%d bytes)",
							  walsegsz),
					 segname, walsegsz);
		pg_log_error_detail("The WAL segment size must be a power of two between 1 MB and 1 GB.");
		exit(1);
	}

	XLogFromFileName(segname, &tli, &segno, walsegsz);

	TDEXLogSmgrInitWriteOldKeys();

	w = xlog_smgr->seg_write(segfd, buf.data, r, pos, tli, segno, walsegsz);

	if (w < 0)
		pg_fatal("could not write file \"%s\": %m", segpath);
	else if (w != r)
		pg_fatal("could not write file \"%s\": wrote %d of %d",
				 segpath, w, r);

	pos += w;

	while (1)
	{
		r = read(tmpfd, buf.data, XLOG_BLCKSZ);

		if (r == 0)
			break;
		else if (r < 0)
			pg_fatal("could not read file \"%s\": %m", tmppath);

		w = xlog_smgr->seg_write(segfd, buf.data, r, pos, tli, segno, walsegsz);

		if (w < 0)
			pg_fatal("could not write file \"%s\": %m", segpath);
		else if (w != r)
			pg_fatal("could not write file \"%s\": wrote %d of %d",
					 segpath, w, r);

		pos += w;
	}

	close(segfd);
	close(tmpfd);
}

static void
usage(const char *progname)
{
	printf(_("%s wraps a restore command to encrypt its returned WAL.\n\n"), progname);
	printf(_("Usage:\n"));
	printf(_("  %s [OPTION]\n"), progname);
	printf(_("  %s SOURCE-NAME DEST-PATH RESTORE-COMMAND\n"), progname);
	printf(_("\nOptions:\n"));
	printf(_("  -V, --version   output version information, then exit\n"));
	printf(_("  -?, --help      show this help, then exit\n"));
	printf(_("  SOURCE-NAME     name of the WAL file to retrieve from archive\n"));
	printf(_("  DEST-PATH       path where the encrypted WAL segment should be written\n"));
	printf(_("  RESTORE-COMMAND restore command to wrap, %%p will be replaced with the path\n"
			 "                  where it should write the unencrypted WAL segment, %%f with\n"
			 "                  the WAL segment's name\n"));
	printf(_("\n"));
	printf(_("Note that any %%f or %%p parameter in RESTORE-COMMAND will have to be escaped\n"
			 "as %%%%f or %%%%p respectively if used as restore_command in postgresql.conf.\n"
			 "e.g.\n"
			 "  restore_command='%s %%f %%p \"cp /mnt/server/archivedir/%%%%f %%%%p\"'\n"
			 "or\n"
			 "  restore_command='%s %%f %%p \"pgbackrest --stanza=your_stanza archive-get %%%%f \\\"%%%%p\\\"\"'\n"
			 "\n"), progname, progname);
}

int
main(int argc, char *argv[])
{
	const char *progname;
	char	   *sourcename;
	char	   *targetpath;
	char	   *command;
	char	   *sep;
	char	   *targetname;
	char		tmpdir[MAXPGPATH] = TMPFS_DIRECTORY "/pg_tde_restoreXXXXXX";
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
			puts("pg_tde_restore_encrypt (PostgreSQL) " PG_VERSION);
			exit(0);
		}
	}

	if (argc != 4)
	{
		pg_log_error("wrong number of arguments, 3 expected");
		pg_log_error_detail("Try \"%s --help\" for more information.", progname);
		exit(1);
	}

	sourcename = argv[1];
	targetpath = argv[2];
	command = argv[3];

	pg_tde_fe_init("pg_tde");
	TDEXLogSmgrInit();

	sep = strrchr(targetpath, '/');

	if (sep != NULL)
		targetname = sep + 1;
	else
		targetname = targetpath;

	issegment = is_segment(sourcename);

	if (issegment)
	{
		char	   *s;
		uint64 requiredBytes = 0;
		uint64 freeBytes = 0;

		/*
		 * Estimate tmpfs space for the unencrypted file the restore command will
		 * write. Prefer an accurate value from the cluster's control file
		 * (xlog_seg_size). If we cannot determine it, fall back to 16MB.
		 */
		{
			/*
			 * Note: restore_command may be invoked repeatedly (one process per
			 * segment, with retries on failure). Reading pg_control here is an
			 * ~8KB I/O that will be page-cache hot after the first call and is
			 * negligible compared to downloading the WAL from a remote repository
			 * (e.g., S3 via pgBackRest) or reading it from a local archive, and the
			 * subsequent encrypt/write. We read pg_control rather than a WAL header
			 * because we must know the exact segment size before starting the wrapped
			 * restore to preflight /dev/shm capacity and avoid mid-write ENOSPC.
			 * Reading the WAL header would happen too late for that purpose.
			 */
			char dataDir[MAXPGPATH];
			uint32 segsz = 0;
			if (get_data_dir_from_targetpath(targetpath, dataDir, sizeof(dataDir)) &&
				read_wal_segment_size_from_control(dataDir, &segsz))
				requiredBytes = (uint64) segsz;
			else
				requiredBytes = (uint64) (16 * 1024 * 1024);
		}
		/* Fixed 4MB slack; see pg_tde_archive_decrypt.c for detailed rationale. */
		requiredBytes += (uint64) (4 * 1024 * 1024);

		if (!check_free_space_sufficient_bytes(TMPFS_DIRECTORY, requiredBytes, &freeBytes))
		{
			pg_log_error("insufficient temporary space in '%s' for restored WAL (required: %llu bytes, free: %llu bytes)",
					 TMPFS_DIRECTORY, (unsigned long long) requiredBytes, (unsigned long long) freeBytes);
			exit(1);
		}

		if (mkdtemp(tmpdir) == NULL)
			pg_fatal("could not create temporary directory \"%s\": %m", tmpdir);

		s = stpcpy(tmppath, tmpdir);
		s = stpcpy(s, "/");
		stpcpy(s, targetname);

		/* register for cleanup */
		snprintf(g_tmpdir, sizeof(g_tmpdir), "%s", tmpdir);
		snprintf(g_tmppath, sizeof(g_tmppath), "%s", tmppath);
		atexit(cleanup_tmp);
		signal(SIGINT, signal_cleanup_and_exit);
		signal(SIGTERM, signal_cleanup_and_exit);

		command = replace_percent_placeholders(command,
											   "RESTORE-COMMAND", "fp",
											   sourcename, tmppath);
	}
	else
		command = replace_percent_placeholders(command,
											   "RESTORE-COMMAND", "fp",
											   sourcename, targetpath);
	rc = system(command);

	if (rc != 0)
	{
		if (rc == -1)
			pg_fatal("RESTORE-COMMAND \"%s\" failed: %m", command);
		else if (WIFEXITED(rc))
			pg_fatal("RESTORE-COMMAND \"%s\" failed with exit code %d",
					 command, WEXITSTATUS(rc));
		else if (WIFSIGNALED(rc))
			pg_fatal("RESTORE-COMMAND \"%s\" was terminated by signal %d: %s",
					 command, WTERMSIG(rc), pg_strsignal(WTERMSIG(rc)));
		else
			pg_fatal("RESTORE-COMMAND \"%s\" exited with unrecognized status %d",
					 command, rc);
	}

	free(command);

	if (issegment)
	{
		write_encrypted_segment(targetpath, sourcename, tmppath);
		/* No explicit cleanup here; atexit(cleanup_tmp) handles normal process exit. */
	}

	return 0;
}
