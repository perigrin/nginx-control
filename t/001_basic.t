#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;
use Test::WWW::Mechanize;

BEGIN {
    use_ok('Lighttpd::Control');
}

my $ctl = Lighttpd::Control->new(
    config_file => [qw[ t conf lighttpd.dev.conf ]],
    pid_file    => 'lighttpd.control.pid',
);
isa_ok($ctl, 'Lighttpd::Control');

ok(!$ctl->is_server_running, '... the server process is not yet running');

$ctl->start;

diag "Wait a moment for lighttpd to start";
sleep(2);

ok($ctl->is_server_running, '... the server process is now running');

my $mech = Test::WWW::Mechanize->new;
$mech->get_ok('http://localhost:3333/' . $ctl->pid_file->basename);
$mech->content_contains($ctl->server_pid, '... got the content we expected');

$ctl->stop;

diag "Wait a moment for Lighttpd to stop";
sleep(2);

ok(!-e $ctl->pid_file, '... PID file has been removed by Lighttpd');
ok(!$ctl->is_server_running, '... the server process is no longer running');

