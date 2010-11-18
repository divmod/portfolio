#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);
use URI::Escape;
use Time::ParseDate;
use Time::CTime;
use DBI;

my $cgi = new CGI();

my $show_params=1;
my $show_sqlinput=1;
my $show_sqloutput=1;
my @sqlinput=();
my @sqloutput=();
#
$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";
# you need to override these for access to your database
#

#my $dbuser="drp925";
#my $dbpasswd="o3d7f737e";
#my $dbuser="jhb348";
#my $dbpasswd="ob5e18c77";
my $dbuser="ikh831";
my $dbpasswd="o29de7c3f";




print "Cache-Control: no-cache\n";
print "Expires: Thu, 13 Mar 2003 07:12:13 GMT\n";  # ie, a long time ago
print "Content-Type: text/html\n\n";


print "<head><title>Statistical Analysis of a Portfolio</title></head>";

my $pid = param('pid');
my ($pname, $error) = PidToPortfolioName($pid);
if ($error) {
	print "Error in Getting Portfolio Name: $error";
}

#my $file = $cgi->param("uploadedfile");
#my $file = "plot.dat";
my $pid = param('pid');

my ($pname, $error1) = PidToPortfolioName($pid);
if ($error1) {
	print $error1;
}

print start_form(-name=>'analysis'),
			h2('Statistical Analysis of Portfolio ', $pname),
			"From Date (mm/dd/yyyy): ", textfield(-name=>'fromdate',default=>'09/07/1984'),p,
			"To Date (mm/dd/yyyy): ", textfield(-name=>'todate',default=>'06/30/2006'),p,
			"Field Type: ", popup_menu(-name=>'field',-values=>['open','high','low','close']),p,
			p,
			hidden(-name=>'postrun',-default=>['1']),
			hidden(-name=>'pid',-default=>['$pid']),
			submit,
			end_form;

if (param('postrun')) {
	my $symbol = param('symbol');
	my $period = param('period');
	my $pid = param('pid');
	my $enddate = param('todate').' 05:00:00 GMT';
	my $startdate = param('fromdate').' 05:00:00 GMT';
	my $field = param('field');
	my $fromdate = parsedate($startdate);
	my $todate = parsedate($enddate);


	my $i;
	my $stockslist;
	my $count;

	my (@stocks, $error2) = HoldingsFromPid($pid);
	if ($error2) {
		print "Error in getting holdings from portfolio: $error2";
	}

#foreach in stocks, join it as a string to put below
	foreach my $stock (@stocks) {
		$stockslist.=$stock." ";
		$count++;
	}

#	print $stockslist;

#	my @results =	`./get_info.pl --from='$fromdate' --to='$todate' --field=$field --plot $stockslist`;
	my @results = `./get_info.pl --from='$startdate' --to='$enddate' --field=$field --plot $stockslist`;  

#	print @results,p;
	print "<table>";
	for ($i = 0; $i < $count; $i++) {
		print "<tr><td>$results[$i]</td></tr>";
	}
	print "</table>";

#
# Generate debugging output if anything is enabled.
#
#
	if ($show_params || $show_sqlinput || $show_sqloutput) { 
		print hr, p, hr,p, h2('Debugging Output');
		if ($show_params) { 
			print h3('Parameters');
			print "<menu>";
			print map { "<li>$_ => ".param($_)} param();
			print "</menu>";
		}
		if ($show_sqlinput || $show_sqloutput) { 
			my $max= $show_sqlinput ?  $#sqlinput : $#sqloutput;
			print h3('SQL');
			print "<menu>";
			for (my $i=0;$i<=$max;$i++) { 
				if ($show_sqlinput) { print "<li><b>Input:</b> $sqlinput[$i]";}
				if ($show_sqloutput) { print "<li><b>Output:</b> $sqloutput[$i]";}
			}
			print "</menu>";
		}
	} 


	print $cgi->end_html();

	exit;

}
sub PidToPortfolioName {
#	my $pid = @_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select name from Portfolio where pid=?","COL",$pid);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

sub HoldingsFromPid {
#	my $pid = @_;
	my @cols;
	eval {@cols=ExecSQL($dbuser,$dbpasswd,"select distinct symbol from Holdings where id=?","COL",$pid);};
	if ($@) {
		return (undef, $@);
	}
	else {
		return (@cols,$@);
	}
}

sub ExecSQL {
	my ($user, $passwd, $querystring, $type, @fill) =@_;
	if ($show_sqlinput) { 
		push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
	}
	my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
	if (not $dbh) { 
		if ($show_sqloutput) { 
			push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
		}
		die "Can't connect to database because of ".$DBI::errstr;
	}
	my $sth = $dbh->prepare($querystring);
	if (not $sth) { 
		if ($show_sqloutput) { 
			push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
		}
		my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}

	if (not $sth->execute(@fill)) { 
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


