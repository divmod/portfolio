#!/usr/bin/perl -w

# market_value.pl
#
# Automates for every date in the MySQL StocksDaily table, the computation of the market average of that day
# 
# Get all of the unique dates in StocksDaily
# For each date, average all of the stocks' close values 
# Insert this into a new table, MarketDaily
# Which has the date and the market average of that date
#

#$mydow = "where symbol='MMM' or symbol='AA' or symbol='AXP'  or symbol='T'  or symbol='BAC'  or symbol='BA'  or symbol='CAT'  or symbol='CVX' or symbol='CSCO' or symbol='KO' or symbol='DD' or symbol='XOM' or symbol='GE' or symbol='HPQ' or symbol='HD' or symbol='INTC' or symbol='IBM' or symbol='JNJ' or symbol='JPM' or symbol='KFT' or symbol='MCD' or symbol='MRK' or symbol='MSFT' or symbol='PFE' or symbol='PG' or symbol='TRV' or symbol='UTX' or symbol='VZ' or symbol='WMT' or symbol='DIS'";
#$mydow2 = where (symbol='MMM'  or symbol='AXP' or symbol='T' or symbol='BA' or symbol='CAT' or symbol='KO' or symbol='XOM' or symbol='IBM' or symbol='JNJ' or symbol='PG' or symbol='UTX' or symbol='WMT'


use DBI;
use Time::ParseDate;
use POSIX;

$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";

my $dbuser="jhb348";
my $dbpasswd="ob5e18c77";

($mindate,$error1) = GetEarliestDate();
if ($error1) {
	print "Error getting the min date\n";
}
($maxdate,$error2) = GetLastDate();
if ($error2) {
	print "Error getting the max date\n";
}

# 60 seconds/minute * 60 minutes/hour * 24 hours/day

(@dates,$error3) = Get25Dates($mindate);
if ($error3) {
	print "Error getting 25 dates\n";
}

#print join(" ",@dates),"\n";

$size = scalar @dates;

while ($mindate < $maxdate) {

	for ($i = 0; $i < 25; $i++) {
		print "Currently operating on date: $dates[$i]\n";
		($price,$avgerr) = CalculateAverage($dates[$i]);
		if ($avgerr) {
			print "Error in computing average close for the day\n";
		}
		else {
			$error = PopulateMarketDaily($dates[$i],$price);
		}
		if ($error) {
			print "Error populating MarketDaily table for date $mindate\n";
		}
	}

#	foreach $date (@dates) {
#		print "Currently operating on date: $date\n";
#		($price,$avgerr) = CalculateAverage($date);
#		if ($avgerr) {
#			print "Error in computing average close for the day";
#		}
#		$error = PopulateMarketDaily($date,$price);
#		if ($error) {
#			print "Error populating MarketDaily table for date $mindate\n";
#		}
#	}
	$mindate = $dates[24];

#	print "Reassigned mindate to $dates[24]\n";
	(@dates,$error3) = Get25Dates($mindate);
	if ($error3) {
		print "Error getting 25 dates\n";
	}
}


sub GetEarliestDate {
	my @cols;
	eval{@cols=ExecMySQL("select min(date) from StocksDaily","COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($cols[0],$@);
	}
}

sub GetLastDate {
	my @cols;
	eval{@cols=ExecMySQL("select max(date) from StocksDaily","COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($cols[0],$@);
	}
}

sub Get25Dates {
	my ($startdate) = @_;
	my @cols;
	eval{@cols=ExecMySQL("select distinct date from StocksDaily where date>? order by date limit 25","COL",$startdate);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return(@cols,$@);
	}
}

# GetDates function is too big to run!
sub GetDates {
	my ($mindate,$date) = @_;
	my @cols;
#	eval{@cols=ExecMySQL("select date from StocksDaily","COL");};
	eval{@cols=ExecMySQL("select date from StocksDaily where date>=? and date<=?","COL",$mindate,$date);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return (@cols,$@);
	}
}

sub CalculateAverage {
	my ($date) = @_;
	my @avgs;
	eval {@avgs=ExecMySQL("select avg(close) from StocksDaily where date=? and (symbol='MMM' or symbol='AA' or symbol='AXP'  
	or symbol='T'  or symbol='BAC'  or symbol='BA'  or symbol='CAT' or symbol='CVX' or symbol='CSCO' or symbol='KO' 
	or symbol='DD' or symbol='XOM' or symbol='GE' or symbol='HPQ' or symbol='HD' or symbol='INTC' or symbol='IBM' 
	or symbol='JNJ' or symbol='JPM' or symbol='KFT' or symbol='MCD' or symbol='MRK' or symbol='MSFT' or symbol='PFE' 
	or symbol='PG' or symbol='TRV' or symbol='UTX' or symbol='VZ' or symbol='WMT' or symbol='DIS')","COL",$date);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($avgs[0],$@);
	}
}

sub PopulateMarketDaily {
	my ($date,$close) = @_;
	eval {ExecSQL($dbuser,$dbpasswd,"insert into MarketDaily(datestamp,close) values(?,?)",undef, $date, $close);};
	return $@;
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
		if ($show_sqloutput) {push @sqloutput, MakeTable("COL",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	$sth->finish();
	if ($show_sqloutput) {push @sqloutput, MakeTable("2D",undef,@ret);}
	$dbh->disconnect();
	return @ret;
}

sub ExecMySQL {
	my ($querystring, $type, @fill) =@_;
	my $user = "cs339";
	my $passwd = "cs339";
	my $db = "cs339";
	if ($show_sqlinput) { 
# if we are recording inputs, just push the query string and fill list onto the 
# global sqlinput list
		push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
	}
	my $dbh = DBI->connect("DBI:mysql:$db",$user,$passwd);
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
		if ($show_sqloutput) {push @sqloutput, MakeTable("COL",undef,@data);}
		$dbh->disconnect();
		return @data;
	}
	$sth->finish();
	if ($show_sqloutput) {push @sqloutput, MakeTable("2D",undef,@ret);}
	$dbh->disconnect();
	return @ret;
}

sub MakeTable {
	my ($type,$headerlistref,@list)=@_;
	my $out;
#
# Check to see if there is anything to output
#
	if ((defined $headerlistref) || ($#list>=0)) {
# if there is, begin a table
#
		$out="<table border>";
#
# if there is a header list, then output it in bold
#
		if (defined $headerlistref) { 
			$out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
		}
#
# If it's a single row, just output it in an obvious way
#
		if ($type eq "ROW") { 
#
# map {code} @list means "apply this code to every member of the list
# and return the modified list.  $_ is the current list member
#
			$out.="<tr>".(map {"<td>$_</td>"} @list)."</tr>";
		} elsif ($type eq "COL") { 
#
# ditto for a single column
#
			$out.=join("",map {"<tr><td>$_</td></tr>"} @list);
		} else { 
#
# For a 2D table, it's a bit more complicated...
#
			$out.= join("",map {"<tr>$_</tr>"} (map {join("",map {"<td>$_</td>"} @{$_})} @list));
		}
		$out.="</table>";
	} else {
# if no header row or list, then just say none.
		$out.="(none)";
	}
	return $out;
}

