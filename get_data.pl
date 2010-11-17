#!/usr/bin/perl -w

use Getopt::Long;
use Time::ParseDate;
use Time::CTime;
use FileHandle;

$user='cs339';
$pass='cs339';
$db='cs339';

$close=1;

$nodate=0;
$open=0;
$high=0;
$low=0;
$close=0;
$vol=0;
$from=0;
$to=0;
$plot=0;

&GetOptions( "nodate"=>\$nodate,
             "open" => \$open,
	     "high" => \$high,
	     "low" => \$low,
	     "close" => \$close,
	     "vol" => \$vol,
	     "from=s" => \$from,
	     "to=s" => \$to,
	     "plot" => \$plot);

#if (defined $from) { $from=parsedate($from); }
#if (defined $to) { $to=parsedate($to); }


$#ARGV==0 or die "usage: get_data.pl [--open] [--high] [--low] [--close] [--vol] [--from=date] [--too=date] [--plot] SYMBOL\n";

$symbol=shift;

push @fields, "date" if !$nodate;
push @fields, "open" if $open;
push @fields, "high" if $high;
push @fields, "low" if $low;
push @fields, "close" if $close;
push @fields, "volume" if $vol;



$sql = "select ".join(",",@fields). " from StocksDaily";
$sql.= " where symbol='$symbol'";
$sql.= " and date>=$from" if $from;
$sql.= " and date<=$to" if $to;
$sql.= " order by date";

#print STDERR $sql,"\n";

$exec = "mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"";

$exec .= ">_plot.in" if $plot;

system $exec;

if ($plot) {
  open(GNUPLOT, "|gnuplot");
  GNUPLOT->autoflush(1);
  print GNUPLOT "set title '$symbol'\nset xlabel 'time'\nset ylabel 'data'\n";
  print GNUPLOT "plot '_plot.in'\n";
  STDIN->autoflush(1);
  <STDIN>;
}


