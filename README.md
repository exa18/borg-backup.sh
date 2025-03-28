# borg-backup.sh

A simple shell script for driving [Borg Backup][1].


## Usage

Make a borg-backup.conf from the provided template, e.g:

    ## Read from /etc/borg-backup.conf by default.
    ## Override by passing in CONFIG=/path/to.conf in the environment.
    ##
    ## This file is sourced by the shell.
    
    ###############################################################################
    ## Mandatory: Target destination for backups. Directory must exist.
    ##
    TARGET=backup@fancy-backup-server:/backups/${HOSTNAME}
    
    ###############################################################################
    ## Mandatory: Backup name list
    ##
    BACKUPS='homes etc'
    
    ###############################################################################
    ## Mandatory: Backup configuration.
    ##
    ## One per backup name. Any borg create argument other than archive name is valid.
    ##
    BACKUP_homes='/home/freaky -e /home/freaky/Maildir/mutt-cache'
    BACKUP_etc='/etc /usr/local/etc'

    ###############################################################################
    ## Optional: Global prune configuration
    ##
    # PRUNE='-H 24 -d 14 -w 8 -m 6'
    
    ###############################################################################
    ## Optional: Per-backup prune configuration.
    ##
    ## These override the global configuration for individual backups.
    #
    # PRUNE_etc='--keep-hourly=72 --keep-daily=365'
    
    ###############################################################################
    ## Optional: A passphrase to derive an encryption key from.
    ##
    ## Be wary of permissions on this file.
    ##
    # PASSPHRASE='ambiguous antelope capacitor paperclip'
    ##
    ## Or override the global password with individual
    ##
    # PASSPHRASE_homes='incorrect zebra generator clip'
    
    ###############################################################################
    ## Optional: Compression
    ##
    ## See 'borg help compression' for available options.
    ##
    ## This script defaults to zstd as of 0.7.0.
    ##
    # COMPRESSION='zstd'
    
    ###############################################################################
    ## Optional: Compact threshold in percent
    ##
    # COMPACT_THRESHOLD='10'
    
    ###############################################################################
    ## Optional: Suffix for backups name
    ##
    # SUFFIX='.borg'


This will produce two independent Borg archives.  If using a remote host over SSH,
consider [locking down the public key][2], and using [append-only mode][3] to limit
the damage a compromised client can cause.

Initialize repositories:

    $ borg-backup.sh init

And create your initial snapshots:

    $ borg-backup.sh create

Any time you want to make a new backup, re-run the create command (ideally using cron or
other scheduler).  Borg will create a new snapshot, adding only new data.

To list archives:

    $ borg-backup.sh list

And to extract - in this case, `/etc/rc.conf` from the `etc` backup `etc-2017-02-21T20:00Z`:

    $ borg-backup.sh extract etc ::etc-2017-02-21T20:00Z etc/rc.conf --stdout

To prune old backups:

    $ borg-backup.sh prune

To recover space after one or more prune operations:

    $ borg-backup.sh compact

To verify the repository and all archive metadata:

    $ borg-backup.sh check

Or the repository and the last archive:

    $ borg-backup.sh quickcheck

Or only the repository (a purely server-side check):

    $ borg-backup.sh repocheck

To change passphrase if repo initialized with (note: global PASSPHRASE if set isn't remove)
then new passphrase is added and old is removed from config.
Also need to provide sudo privs while changing to authorize move new config to /etc.

    $ borg-backup.sh changepass


For any Borg operation not covered explicitly, borg-backup.sh provides a `borg`
subcommand, which passes through the argument list to borg, having set up the
environment for the given repository.  Refer to the [Borg documentation][4] for detailed
usage instructions.

## See Also

ZFS users may find [zfsnapr](https://github.com/Freaky/zfsnapr) of interest for creating
consistent point-in-time backups from snapshots.

## Alternatives

If you want something a bit fancier, [borgmatic][5] is worth a look.


[1]: https://borgbackup.readthedocs.io/
[2]: https://borgbackup.readthedocs.io/en/stable/deployment.html#restrictions
[3]: https://borgbackup.readthedocs.io/en/stable/usage.html#append-only-mode
[4]: https://borgbackup.readthedocs.io/en/stable/usage.html
[5]: https://github.com/witten/borgmatic
