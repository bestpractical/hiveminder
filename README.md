# Dependencies

 * PostgreSQL 8.1 or newer

 * Perl <= 5.12; later versions of perl (5.16 and later are known-bad)
   may cause Template::Declare elements to be repeated, due to changes
   in perl's overloading and stringification handling.

 * DBD::Pg < 3.3.0; version 3.3.0 changed how Unicode was handled, in a
   way that the current Jifty codes does not support.  Version 3.2.1 is
   available from
   https://cpan.metacpan.org/authors/id/T/TU/TURNSTEP/DBD-Pg-3.2.1.tar.gz

 * Latest Jifty (1.50430) and Jifty-DBI (0.78), and all dependencies
   found by running `perl Makefile.PL`


# Setting up and running

 1. `./bin/jifty schema --setup`
 2. `perl Makefile.PL`
    This step will likely require that additional dependencies be
    installed.
 3. `make`
 4. `make test`
 5. `./bin/jifty server`


# Known test failures

 * `t/15a-task-notifications.t` (whitespace changes)

 * `t/20-incoming-mail.t` (string comparison)

 * `t/40c-bulk-projects.t` (height/width attributes)

 * `t/70-im.t` and `t/70b-im.t` ("tomorrow" vs specific date)

 * `t/75-imap.t` (log framework changes?)

 * `t/99-pod-coverage.t` (DJabberd::Bot::Hiveminder coverage)
