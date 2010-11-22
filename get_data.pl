#!/usr/bin/perl -w

use Getopt::Long;
use Time::ParseDate;
use Time::CTime;
use FileHandle;
use DBI;

$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";



$user='cs339';
$pass='cs339';
$db='cs339';

$oracle_user='drp925';
$oracle_pass='o3d7f737e';

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

push @fields2, "datestamp" if !$nodate;
push @fields2, "open" if $open;
push @fields2, "high" if $high;
push @fields2, "low" if $low;
push @fields2, "close" if $close;
push @fields2, "volume" if $vol;

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

$sql2 = "select ".join(",",@fields2). " from NewStocks";
$sql2.= " where symbol='$symbol'";
$sql2.= " and datestamp>=$from" if $from;
$sql2.= " and datestamp<=$to" if $to;
$sql2.= " order by datestamp";

#print STDERR $sql,"\n";

$exec = "mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"";

$exec .= ">_plot.in" if $plot;

system $exec;




@newdata = ExecSQL($oracle_user,$oracle_pass,$sql2) ;

open(FILE, ">>_plot.in");

foreach $row(@newdata) {
	$printrow = join("	", @{$row});
	print FILE "$printrow\n";
}
close(FILE);

sub ExecSQL {
	my ($user, $passwd, $querystring,  @fill) =@_;
	my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
	if (not $dbh) {
# if the connect failed, record the reason to the sqloutput list (if set)
# and then die.
		die "Can't connect to database because of ".$DBI::errstr;
	}
	my $sth = $dbh->prepare($querystring);
	if (not $sth) {
#
# If prepare failed, then record reason to sqloutput and then die
#
		my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
	if (not $sth->execute(@fill)) {
#
# if exec failed, record to sqlout and die.
		my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
		$dbh->disconnect();
		die $errstr;
	}
#
# The rest assumes that the data will be forthcoming.
#
#
	my @data;
	my @ret;
	while (@data=$sth->fetchrow_array()) {
		push @ret, [@data];
	}
	$sth->finish();
	$dbh->disconnect();
	return @ret;
}




#if ($plot) {
#  open(GNUPLOT, "|gnuplot");
#  GNUPLOT->autoflush(1);
#  print GNUPLOT "set title '$symbol'\nset xlabel 'time'\nset ylabel 'data'\n";
#  print GNUPLOT "plot '_plot.in'\n";
#  STDIN->autoflush(1);
#  <STDIN>;
#}
