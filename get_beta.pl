#!/usr/bin/perl

use Getopt::Long;
use Time::ParseDate;
use FileHandle;
use DBI;

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

$symbol=shift;
$s1=$symbol;

#first, get means and vars for the individual columns that match

$sql = "select count(*),avg(close),std(close) from StocksDaily where symbol='$symbol'";
$sql.= " and date>=$from" if $from;
$sql.= " and date<=$to" if $to;
#print $sql, "\n";
($count, $avg_stock, $std) =   split(/\s+/, `mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"`);

($avg_mrkt, $error) = GetAvgMarket($from,$to);
if ($error) {
	print $error,"\n";
}

($var_mrkt, $error) = GetVarMarket($from,$to);
if ($error) {
	print $error,"\n";
}

#print "Average of the market: ".$avg_mrkt,"\n";
#print "Variance of the market: ".$var_mrkt,"\n";

(@res2, $error) = GetDevMarket($from,$to,$avg_mrkt);
if ($error) {
	print $error,"\n";
}

$avgdev_mrkt = $res2[0];

#print "Average standard deviation of the market: ".$avgdev_mrkt,"\n";

#skip this pair if there isn't enough data

#print $count,"\n";

if ($count<30) { # not enough data
	$covar{$symbol}='NODAT';
} else {

#otherwise get the covariance

#covariance of stock, market
# (sum(stock-avg_stock) * market*avg_market) / n
#
# in order to do this:
# get n days from stockdaily and marketdaily
# 

	$sql_my = "select close from StocksDaily where symbol='$symbol'";
	$sql_my .= " and date>=$from" if $from;
	$sql_my .= " and date<=$to" if $to;
	$sql_my .= " order by date";
#	print $sql_my,"\n";

	@stocks = `mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql_my\"`;

	@markets = GetMarketCloses($from,$to);

	for ($i = 0; $i < $count; $i++) {
		$sum += (($stocks[$i]-$avg_stock)*($markets[$i]-$avg_mrkt));
	}

	$covar = $sum / $count;

#	$sql = "select (avg((close - $avg))*$avgdev_mrkt) from StocksDaily where symbol='$symbol'";
#	$sql.= " and date>=$from" if $from;
#	$sql.= " and date<=$to" if $to;
#  print $sql, "\n";
#	($covar{$symbol}) =  split(/\s+/, `mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"`);
}


print "Beta of the $symbol with the market: ";
	print $covar / $var_mrkt,"\n";

#end of script output

	sub GetMarketCloses {
		my ($from,$to) = @_;
		my $sql_ora = "select close from MarketDaily";
		if ($from && $to) {
			$sql_ora.= " where datestamp>=$from and datestamp<=$to";
		}
		else {
			$sql_ora.= " where datestamp>=$from" if $from;
			$sql_ora.= " where datestamp<=$to" if $to;
		}
		eval{@cols=ExecSQL($dbuser,$dbpasswd,$sql_ora,"COL");};
		if ($@) {
			return (undef,$@);
		}
		else {
			return (@cols);
		}
	}

sub GetAvgMarket {
	my ($from,$to) = @_;
	my $orasql = "select avg(close) from MarketDaily";
	if ($from && $to) {
		$orasql.= " where datestamp>=$from and datestamp<=$to";
	}
	else {
		$orasql.= " where datestamp>=$from" if $from;
		$orasql.= " where datestamp<=$to" if $to;
	}
	eval{@cols=ExecSQL($dbuser,$dbpasswd,$orasql,"COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($cols[0]);
	}
}


sub GetVarMarket {
	my ($from,$to) = @_;
	my $orasql = "select variance(close) from MarketDaily";
	if ($from && $to) {
		$orasql.= " where datestamp>=$from and datestamp<=$to";
	}
	else {
		$orasql.= " where datestamp>=$from" if $from;
		$orasql.= " where datestamp<=$to" if $to;
	}
	eval{@cols=ExecSQL($dbuser,$dbpasswd,$orasql,"COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($cols[0]);
	}
}


sub GetDevMarket {
	my ($from,$to,$avg_mrkt) = @_;
	my $orasql = "select stddev(close) from MarketDaily";
	if ($from && $to) {
		$orasql.= " where datestamp>=$from and datestamp<=$to";
	}
	else {
		$orasql.= " where datestamp>=$from" if $from;
		$orasql.= " where datestamp<=$to" if $to;
	}
#	eval{@cols=ExecSQL($dbuser,$dbpasswd,"select avg((close) - $avg_mrkt) from MarketDaily where datestamp>=$from and datestamp<=$to","COL");};
	eval{@cols=ExecSQL($dbuser,$dbpasswd,$orasql,"COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return (@cols,$@);
	}
}

sub ExecSQL {
	my ($user, $passwd, $querystring, $type, @fill) =@_;
	if ($show_sqlinput) { 
# if we are recording inputs, just push the query string and fill list onto the 
# global sqlinput list
		push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
	}
	my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
	if (not $dbh) { 
# if the connect failed, record the reason to the sqloutput list (if set)
# and then die.
		if ($show_sqloutput) { 
			push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
		}
		die "Can't connect to database because of ".$DBI::errstr;
	}
	my $sth = $dbh->prepare($querystring);
	if (not $sth) { 
#
# If prepare failed, then record reason to sqloutput and then die
#
		if ($show_sqloutput) { 
			push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
		}
		my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
	if (not $sth->execute(@fill)) { 
#
# if exec failed, record to sqlout and die.
		if ($show_sqloutput) { 
			push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
		}
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
		if ($show_sqloutput) {push @sqloutput, maketable("col",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	$sth->finish();
	if ($show_sqloutput) {push @sqloutput, maketable("2d",undef,@ret);}
	$dbh->disconnect();
	return @ret;
}


