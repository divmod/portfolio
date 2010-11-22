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
#if (defined $from) { $from=$from; }
#if (defined $to) { $to=$to; }

$#ARGV>=0 or die "usage: get_data_multi.pl [--open] [--high] [--low] [--close] [--vol] [--from=date] [--too=date] [--plot] SYMBOL+\n";

while ($symbol=shift) {
	push(@symbolist,"$symbol");
}
$size = scalar @symbolist;

#select t.date, t.close + a.close 
#from StocksDaily as t, StocksDaily as a 
#where t.symbol='GOOG' and a.symbol='GOOG' 
#and t.date=a.date;



# select t.date, 
# t.close, a.close 
# from StocksDaily as t, StocksDaily as a 
# where 
# t.symbol = 'GOOG' and a.symbol = 'GOOG' 
# and t.date=a.date ;
#for ($i=26, $c='a' ; $i ; $i--, $c=chr(ord($c)+1) ) { printf("$c\n"); }

for ($i = 0, $c='a'; $i < $size-1; $i++, $c=chr(ord($c)+1) ) {
#	$closeclause .= "$c\.close, ";
	$closeclause .= "$c\.close + ";
	$fromclause .= "StocksDaily as $c, ";
	$symbolsclause .= "$c\.symbol = '$symbolist[$i]' and ";
	$dateclause .= "$c\.date=".chr(ord($c)+1)."\.date and ";
	$symbols .= "symbol='$symbolist[$i]' or ";
}
$closeclause .= "$c\.close";
$fromclause .= "StocksDaily as $c";
$symbolsclause .= "$c\.symbol = '$symbolist[$i]' and ";
#$dateclause .= "$c\.date";
$symbols .= "symbol='$symbolist[$i]'";

print "select $c\.date, ";
#print "sum(";
print $closeclause;
#print ")";
print " from ";
print $fromclause;
print " where ";
print $symbolsclause;
print $dateclause;
print "\n";

push @fields, "$c\.date" if !$nodate;
push @fields, "open" if $open;
push @fields, "high" if $high;
push @fields, "low" if $low;
#push @fields, "close" if $close;
push @fields, "volume" if $vol;

$sql = "select ".join(",",@fields).", ($closeclause) from ";
$sql .= $fromclause." where ".$symbolsclause.$dateclause;
#$sql.= " where $symbols";
$sql.= "$c\.date>=$from" if $from;
$sql.= " and $c\.date<=$to" if $to;
$sql.= " order by $c\.date";

print STDERR $sql,"\n";

$exec = "mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"";

$exec .= ">_plot.in" if $plot;

system $exec;

#if ($plot) {
#  open(GNUPLOT, "|gnuplot");
#  GNUPLOT->autoflush(1);
#  print GNUPLOT "set title '$symbol'\nset xlabel 'time'\nset ylabel 'data'\n";
#  print GNUPLOT "plot '_plot.in'\n";
#  STDIN->autoflush(1);
#  <STDIN>;
#}


