#!/usr/bin/perl

use Getopt::Long;
use Time::ParseDate;
use FileHandle;

$user='cs339';
$pass='cs339';
$db='cs339';

$dbuser='jhb348';
$dbpasswd='ob5e18c77';

$close=1;
$field1='close';
$field2='close';

&GetOptions( "from=s" => \$from,
		"to=s" => \$to);

if (defined $from) { $from = parsedate($from); }
if (defined $to) { $to = parsedate($to); }

$#ARGV=1 or die "usage get_beta.pl [--from=date] [--to=date] SYMBOL\n";


