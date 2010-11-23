#!/usr/bin/perl

use Getopt::Long;
use Time::ParseDate;
use FileHandle;
use DBI;

$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";

$user='cs339';
$pass='cs339';
$db='cs339';

$oracle_user='drp925';
$oracle_pass='o3d7f737e';

$close=1;

$field1='close';
$field2='close';

&GetOptions( "field1=s" => \$field1,
		"field2=s" => \$field2,
		"from=s" => \$from,
		"to=s" => \$to,
		"simple" => \$simple,
		"corrcoeff"=>\$docorrcoeff);

if (defined $from) { $from=parsedate($from." 00:00:00 GMT");}
if (defined $to) { $to=parsedate($to." 00:00:00 GMT"); }


$#ARGV>=1 or die "usage: get_covar.pl [--field1=field] [--field2=field] [--from=date] [--to=date] [--simple (two symbols only)] [--corrcoeff] SYMBOL SYMBOL+\n";

@symbols=@ARGV;


for ($i=0;$i<=$#symbols;$i++) {
	$s1=$symbols[$i];
	for ($j=$i; $j<=$#symbols; $j++) {
		$s2=$symbols[$j];

#first, get means and vars for the individual columns that match

		$sql = "select count(*),sum(l.$field1),std(l.$field1),sum(r.$field2),std(r.$field2) from StocksDaily l join StocksDaily r on  l.date=r.date where l.symbol='$s1' and r.symbol='$s2'";
		$sql.= " and l.date>=$from" if $from;
		$sql.= " and l.date<=$to" if $to;
#    print STDERR $sql, "\n";
		($count_s, $sum_f1_s,$std_f1_s, $sum_f2_s, $std_f2_s) = split(/\s+/, `mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"`);
		
		
		#from StockDaily
		$sql2 = "select count(*),sum(l.$field1),stddev(l.$field1),sum(r.$field2),stddev(r.$field2) from NewStocks l join NewStocks r on  l.datestamp=r.datestamp where l.symbol='$s1' and r.symbol='$s2'";
		$sql2.= " and l.datestamp>=$from" if $from;
		$sql2.= " and l.datestamp<=$to" if $to;
		my @newdata = ExecSQL($oracle_user,$oracle_pass,$sql2,undef) ;
		my $output2;
		
		foreach my $d (@newdata){
		    $output2 = join("	", @{$d});
		}
		
		($count_n, $sum_f1_n,$std_f1_n, $sum_f2_n, $std_f2_n)=split(/\s+/,$output2);
		
		 #combined mean, std for each symbol
		my ($count, $mean_f1,$std_f1, $mean_f2, $std_f2);
		
		if($count_s != undef && $count_n != undef){
			$count = $count_s + $count_n;
		}
		elsif($count_s != undef){
			$count = $count_s;
		}
		elsif($count_n != undef){
			$count = $count_n;
		}
		
		#mean for sym1
		if($sum_f1_s != undef && $sum_f1_n != undef){
			$mean_f1 = ($sum_f1_s + $sum_f1_n)/ ($count_s + $count_n);
		}
		elsif($sum_f1_s != undef){
			$mean_f1 = $sum_f1_s/$count_s;
		}
		elsif($sum_f1_n != undef){
			$mean_f1 = $sum_f1_n/$count_n;
		}
		
		#mean for sym2
		if($sum_f2_s != undef && $sum_f2_n != undef){
			$mean_f2 = ($sum_f2_s + $sum_f2_n)/ ($count_s + $count_n);
		}
		elsif($sum_f2_s != undef){
			$mean_f2 = $sum_f2_s/$count_s;
		}
		elsif($sum_f2_n != undef){
			$mean_f2 = $sum_f2_n/$count_n;
		}
		
		#std for sym1
		if($std_f1_s != undef && $std_f1_n != undef){
			$std_f1 = sqrt(((($count_s -1) * $std_f1_s * $std_f1_s) + (($count_n-1) * $std_f1_n * $std_f1_n))/($count_s + $count_n - 2));
		}
	        elsif($std_f1_s != undef){
			$std_f1 = $std_f1_s;
		}
		elsif($std_f1_n != undef){
			 $std_f1 = $std_f1_n;
		}
                #std for sym2
		if($std_f2_s != undef && $std_f2_n != undef){
			$std_f2 = sqrt(((($count_s -1) * $std_f2_s * $std_f2_s) + (($count_n-1) * $std_f2_n * $std_f2_n))/($count_s + $count_n - 2));
		}
	        elsif($std_f2_s != undef){
			$std_f2 = $std_f2_s;
		}
		elsif($std_f2_n != undef){
			 $std_f2 = $std_f2_n;
		}
		#print "$mean_f1 $mean_f2 $std_f1 $std_f2"."\n";
#skip this pair if there isn't enough data

#    print STDERR $count,"\n";

		if ($count<30) { # not enough data
			$covar{$s1}{$s2}='NODAT';
			$corrcoeff{$s1}{$s2}='NODAT';
		} else {

#otherwise get the covariance

			$sql = "select sum((l.$field1 - $mean_f1)*(r.$field2 - $mean_f2)) from StocksDaily l join StocksDaily r on  l.date=r.date where l.symbol='$s1' and r.symbol='$s2'";
			$sql.= " and l.date>=$from" if $from;
			$sql.= " and l.date<=$to" if $to;
#      print STDERR $sql, "\n";
			($sum_s{$s1}{$s2}) =  split(/\s+/, `mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"`);
                        
			$sql2 = "select sum((l.$field1 - $mean_f1)*(r.$field2 - $mean_f2)) from NewStocks l join NewStocks r on  l.datestamp=r.datestamp where l.symbol='$s1' and r.symbol='$s2'";
			$sql2.= " and l.datestamp>=$from" if $from;
			$sql2.= " and l.datestamp<=$to" if $to;
			#print "sum_s: ".$sum_s{$s1}{$s2}."\n";
			$tmp1 = $sum_s{$s1}{$s2};
			my @newdata2 = ExecSQL($oracle_user,$oracle_pass,$sql2,undef) ;
			my $output2;
			foreach my $d (@newdata2){
				$output2 = join("	", @{$d});
			}
			($sum_n{$s1}{$s2})= split(/\s+/,$output2);
			$tmp2 = $sum_n{$s1}{$s2};
			#print "sum_n: ".$sum_n{$s1}{$s2}."\n";
		
			$covar{$s1}{$s2} = ($tmp1 + $tmp2)/($count_s + $count_n);
			
#and the correlationcoeff
			
			$corrcoeff{$s1}{$s2} = $covar{$s1}{$s2}/($std_f1*$std_f2);
			
			
			
			
			
		}
	}
}

if ($simple && $#symbols==1) {
	$s1=$symbols[0];
	$s2=$symbols[1];
	if ($docorrcoeff) {
		print $corrcoeff{$s1}{$s2} eq "NODAT" ? "NODAT" : sprintf('%3.2f',$corrcoeff{$s1}{$s2});
	} else {
		print $covar{$s1}{$s2} eq "NODAT" ? "NODAT" : sprintf('%3.2f',$covar{$s1}{$s2});
	}
	print "\n";
} else {
	print "<pre>";
	if ($docorrcoeff) {
		print "<table><tr><td>Correlation Coefficient Matrix\n</td></tr>";
	} else {
		print "<table<tr><td>Covariance Matrix\n</td></tr>";
	}
	print "<tr><td>Rows: $field1\n</td></tr><tr><td>Cols: $field2\n\n</td></tr>";

	print "<tr><td>";

	print join("</td><td>","-----",@symbols),"\n";

	print "</td></tr>";

	for ($i=0;$i<=$#symbols;$i++) {
		$s1=$symbols[$i];

		print "<tr>";

		print "<td>$s1</td>";
		for ($j=0; $j<=$#symbols;$j++) {
			if ($i>$j) {
				print "<td>.</td>";
			} else {
				$s2=$symbols[$j];
				if ($docorrcoeff) {
					print "<td>";
					print "\t", $corrcoeff{$s1}{$s2} eq "NODAT" ? "NODAT" : sprintf('%3.2f',$corrcoeff{$s1}{$s2});
					print "</td>";
				} else {
					print "<td>";
					print "\t", $covar{$s1}{$s2} eq "NODAT" ? "NODAT" : sprintf('%3.2f',$covar{$s1}{$s2});
					print "</td>";
				}
			}
		}
		print "</tr>";
		print "</pre>";
	
	}
	
}

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
		#if ($show_sqloutput) {push @sqloutput, MakeTable("ROW",undef,@data);}
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

