#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);
use URI::Escape;
use Time::ParseDate;
use Time::CTime;
use DBI;


my $dbuser="ikh831";
my $dbpasswd="o29de7c3f";
#my $dbuser="drp925";
#my $dbpasswd="o3d7f737e";
#my $dbuser="jhb348";
#my $dbpasswd="ob5e18c77";
my @sqlinput=();
my @sqloutput=();
my $show_sqlinput=1;
my $show_sqloutput=1;
my $show_params=1;


$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";



my $cgi = new CGI();

print "Cache-Control: no-cache\n";
print "Expires: Thu, 13 Mar 2003 07:12:13 GMT\n";  # ie, a long time ago
print "Content-Type: text/html\n\n";


my $pid = param('pid');
my ($pname, $error) = PidToPortfolioName($pid);

print start_form(-name=>'StockHistory'),
			h2('Get Historical Data for Portfolio ', $pname),

			"To Date (mm/dd/yyyy): ", textfield(-name=>'todate',default=>'06/30/2006'),p,
			"Time Interval Ago: ", 
			radio_group(-name=>'period', -values=>['Day','Week','Month','Quarter','Year', '5 Years'], -default=>'Day'),
			p,
			hidden(-name=>'postrun',-default=>['1']),
			hidden(-name=>'pid',-default=>['$pid']),
			submit,
			end_form;

if (param('postrun')) {
	my $pid = param('pid');
	my $period = param('period');
	my $enddate = param('todate').' 05:00:00 GMT';
	my $fromdate;
	my $todate = parsedate($enddate);

	my $size;
	my $stocklist;

	my (@stocks, $error2) = HoldingsFromPid($pid);
	if ($error2) {
		print "Error in getting holdings from portfolio: $error2";
	}

	if ($period eq 'Day') {
		$fromdate = parsedate($enddate) - (24 * 60 * 60);
	}
	elsif ($period eq 'Week') {
		$fromdate = parsedate($enddate) - (7 * 24 * 60 * 60);
	}
	elsif ($period eq 'Quarter') {
		$fromdate = parsedate($enddate) - (90 * 24 * 60 * 60);
	}
	elsif ($period eq 'Month') {
		$fromdate = parsedate($enddate) - (30 * 24 * 60 * 60);
	}
	elsif ($period eq 'Year') {
		$fromdate = parsedate($enddate) - (365 * 24 * 60 * 60);
	}
	elsif ($period eq '5 Years') {
		$fromdate = parsedate($enddate) - (5 * 365 * 24 * 60 * 60) + 1;
	}
	$size = scalar @stocks;
	$stocklist = join(" ",@stocks);
	my @results =	`./get_data_multi.pl --from='$fromdate' --to='$todate' --close --plot $stocklist`;
#	print @results;

#	`./get_data.pl --close $symbol --plot`;
#	system("/usr/bin/perl 'get_data.pl --close $symbol --plot'");
#	system './get_data.pl --close $symbol --plot';
#	open(my $STOCK, "./get_data.pl --close $symbol --plot |");

	GraphAndPrint('_plot.in');

	print $cgi->end_html();

	exit;

}

sub GraphAndPrint
{
	my ($name) = @_;
	my ($graphfile)="$name.png";

	print "<b>Graph</b><p><img src =\"" . GnuPlot($name,$graphfile) ."\"><p>\n";

	print "<b>Data</b><p><pre>";
	print "Unix Time";
#	for (my $i = 0; $i < (scalar @stocks); $i++) {
#		print "\t$stocks[$i]";
#	}
	print "\tPortfolio Value";
	print "\n";
	open (FILE,$name);
	while (<FILE>) { 
		print $_;
	}
	close(FILE);
	print "</pre>";
}


sub GnuPlot
{

	my ($datafile, $outputfile)=@_;
	my $i;
	
	open(GNUPLOT,"|gnuplot");
	print GNUPLOT "set terminal png\n";
	print GNUPLOT "set output \"$outputfile\"\n";
	print GNUPLOT "set xdata time\n";
	print GNUPLOT "set timefmt \"%s\"\n";
	print GNUPLOT "set format x \"%m/%d/%y\"\n";
	print GNUPLOT "set xlabel 'Date'\n";
	print GNUPLOT "set ylabel 'Price Per Unit'\n";
	print GNUPLOT "plot \"$datafile\" using 1:2 title 'Portfolio Value' with linespoints\n";
#	print GNUPLOT "plot ";
#	for ($i = 2; $i < scalar @stocks; $i++) {
#		print GNUPLOT "\"$datafile\" using 1:$i title '$stocks[$i - 2]' with linespoints, \\\n";
#	}
#	print GNUPLOT "\"$datafile\" using 1:$i title '$stocks[$i-2]' with linespoints\n";
	close(GNUPLOT);
	return $outputfile;
}

sub PidToPortfolioName {
#	my $ppid = @_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select name from Portfolio where pid='$pid'","COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

sub HoldingsFromPid {
#	my $ppid = @_;
	my @cols;
	eval {@cols=ExecSQL($dbuser,$dbpasswd,"select distinct symbol from Holdings where id=?","COL",$pid);};
	if ($@) {
		return (undef, $@);
	}
	else {
		return (@cols,$@);
	}
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

