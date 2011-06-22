#!perl
use strict;
use warnings FATAL => 'all';
use Errno ();
use POSIX ();
use POSIX::pselect;
use Time::HiRes ();

use Test::More tests => 5;

sub doit {
    my $got_usr1 = 0;
    # setup sighandler and block SIGUSR1
    local $SIG{USR1} = sub { $got_usr1 = 1 };
    POSIX::sigprocmask(POSIX::SIG_BLOCK(),
        POSIX::SigSet->new(POSIX::SIGUSR1()));
    # send SIGUSR1 to myself
    my $pid = fork || do {
        Time::HiRes::sleep(0.1);
        kill POSIX::SIGUSR1(), getppid
            or die "Cannot send SIGUSR1 to the parent: $!";
        exit(0);
    };
    ok ! $got_usr1, 'did not get SIGUSR1';
    # perform a pselect
    my $now = Time::HiRes::time();
    my $ret = POSIX::pselect::pselect(undef, undef, undef, 1, do {
        my $ss = POSIX::SigSet->new;
        $ss->fillset;
        $ss->delset(POSIX::SIGUSR1());
        $ss;
    });
    while (wait() != $pid) {}
    cmp_ok $ret, '<=', 0;
    is $! + 0, Errno::EINTR(), '$! == EINTR';
    ok $got_usr1, 'got SIGUSR1';
    my $elapsed = Time::HiRes::time - $now;
    cmp_ok $elapsed, '<', 0.5;
}

doit();

done_testing;
