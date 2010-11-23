#!/usr/bin/perl

use Getopt::Long;
use Time::ParseDate;
use FileHandle;
use DBI;



$user='cs339';
$pass='cs339';
$db='cs339';

$oracle_user='drp925';
$oracle_pass='o3d7f737e';

$close=1;
$field='close';

&GetOptions( "field=s" => \$field,
	     "from=s" => \$from,
	     "to=s" => \$to);

if (defined $from) { $from=parsedate($from. " 00:00:00 GMT");}
if (defined $to) { $to=parsedate($to." 00:00:00 GMT"); }

$#ARGV>=0 or die "usage: get_info.pl [--field=field] [--from=date] [--to=date] SYMBOL+\n";


print "<table><tr><td>";
print join("</td><td>","symbol","field","num","mean","std","min","max","cov"),"\n";
print "</td></tr>";

#print $from."\n";
#print $to."\n";
while ($symbol=shift) {

  #print $symbol."\n";
  $sql = "select count($field), sum($field), std($field), min($field), max($field)  from StocksDaily where symbol='$symbol'";
  $sql.= " and date>=$from" if $from;
  $sql.= " and date<=$to" if $to;
  
  $sq2 = "select count($field), sum($field), stddev($field), min($field), max($field)  from NewStocks where symbol='$symbol'";
  $sq2.= " and datestamp>=$from" if $from;
  $sq2.= " and datestamp<=$to" if $to;

  #  print STDERR $sql,"\n";

  my $output1=`mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"`;
  my @newdata = ExecSQL($oracle_user,$oracle_pass,$sq2, undef) ;
  my $output2;
  foreach my $d (@newdata){
      $output2 = join("	", @{$d});
  }
 
   #from StocksDaily
  ($n1,$sum1,$std1,$min1,$max1)=split(/\s+/,$output1);
  
  #from NewStocks
  ($n2,$sum2,$std2,$min2,$max2)=split(/\s+/,$output2);
  
  #Variables for combining data from both tables
  $n, $mean, min, max, $std;
  
  #count calculations
  if($n1 != undef && $n2 != undef){
      $n = $n1 + $n2;
  }
  elsif($n1 != null){
     $n = $n1;
  }
  elsif($n2 != undef){
     $n = $n2;
  }
  
  #mean calculation
  if($sum1 != undef && $sum2 != undef){
      $mean = ($sum1 + $sum2)/($n1 + $n2);
  }
  elsif($sum1 != undef){
     $mean = $sum1/$n1;
  }
  elsif($sum2 != undef){
     $mean = $sum2/$n2;
  }
  
  #min calculation
  if($min1 != undef && $min2 != undef){
     $min = ($min1 <= $min2 ? $min1 : $min2);
  }
  elsif($min1 != undef){
     $min = $min1;
  }
  elsif($min2 != undef){
     $min = $min2;
  }
  
  #max calculation
  if($max1 != undef && $max2 != undef){
     $max = ($max1 >= $max2 ? $max1 : $max2);
  }
  elsif($max1 != undef){
     $max = $max1;
  }
  elsif($min2 != undef){
     $max = $max2; 
  }
  
  #std calculation
  if($std1 != undef && $std2 != undef){
     $std = sqrt(((($n1-1) * $std1 * $std1) + (($n2-1) * $std2 * $std2))/($n1 + $n2 - 2));
  }
  elsif($std1 != undef){
     $std = $std1;
  }
  elsif($std2 != undef){
     $std = $std2;
  }
  
  my $cov = $std/$mean;      
  #print $min;
  print "<tr><td>";
  print join("</td><td>",$symbol,$field, $n, $mean, $std, $min, $max, $cov),"\n";

  #print "$symbol,$field, $n, $mean, $std, $min, $max, $cov";
  print "</td></tr>";
}

print "</table>";
#print "\n";

sub ExecSQL {
	my ($user, $passwd, $querystring, $type, @fill) =@_;
#	if ($show_sqlinput) { 
# if we are recording inputs, just push the query string and fill list onto the 
# global sqlinput list
#		push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
#	}
	my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
	if (not $dbh) { 
# if the connect failed, record the reason to the sqloutput list (if set)
# and then die.
		#if ($show_sqloutput) { 
			#push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
		#}
		die "Can't connect to database because of ".$DBI::errstr;
	}
	my $sth = $dbh->prepare($querystring);
	if (not $sth) { 
#
# If prepare failed, then record reason to sqloutput and then die
#
		#if ($show_sqloutput) { 
		#	push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
		#}
		my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
	if (not $sth->execute(@fill)) { 
#
# if exec failed, record to sqlout and die.
		#if ($show_sqloutput) { 
		#	push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
		#}
		my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
#
# The rest assumes that the data will be forthcoming.
#
#
	my @data;
	if (defined $type and $type eq "ROW") { 
		@data=$sth->fetchrow_array();
		$sth->finish();
		if ($show_sqloutput) {push @sqloutput, MakeTable("ROW",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	my @ret;
	while (@data=$sth->fetchrow_array()) {
		push @ret, [@data];
	}
	if (defined $type and $type eq "COL") { 
		@data = map {$_->[0]} @ret;
		$sth->finish();
		#if ($show_sqloutput) {push @sqloutput, MakeTable("COL",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	$sth->finish();
	#if ($show_sqloutput) {push @sqloutput, MakeTable("2D",undef,@ret);}
	$dbh->disconnect();
	return @ret;
}
