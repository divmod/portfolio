#!/usr/bin/perl

use Getopt::Long;
use Time::ParseDate;
use FileHandle;

$user='cs339';
$pass='cs339';
$db='cs339';

$close=1;

$field='close';

&GetOptions( "field=s" => \$field,
	     "from=s" => \$from,
	     "to=s" => \$to);

if (defined $from) { $from=parsedate($from);}
if (defined $to) { $to=parsedate($to); }


$#ARGV>=0 or die "usage: get_info.pl [--field=field] [--from=date] [--to=date] SYMBOL+\n";

print join("\t","symbol","field","num","mean","std","min","max","cov"),"\n";

while ($symbol=shift) {
  
  $sql = "select count($field), avg($field), std($field), min($field), max($field)  from StocksDaily where symbol='$symbol'";
  $sql.= " and date>=$from" if $from;
  $sql.= " and date<=$to" if $to;

#  print STDERR $sql,"\n";

  $output=`mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"`;

  ($n,$mean,$std,$min,$max)=split(/\s+/,$output);

  print join("\t",$symbol,$field, $n, $mean, $std, $min, $max, $std/$mean),"\n";
}


