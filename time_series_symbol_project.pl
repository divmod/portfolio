#!/usr/bin/perl -w

use Getopt::Long;

$#ARGV>=2 or die "usage: time_series_symbol_project.pl symbol steps-ahead model \n";

$symbol=shift;
$steps=shift;
$model=join(" ",@ARGV);

system "./get_data.pl --nodate --close $symbol > _data.in";
system "./time_series_project _data.in $steps $model 2>/dev/null";

