#!/usr/bin/perl -w

use Getopt::Long;
use Time::ParseDate;
use Time::CTime;
use FileHandle;
use DBI;


$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";


$oracle_user='drp925';
$oracle_pass='o3d7f737e';

$dbuser='ikh831';
$dbpass='o29de7c3f';


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

print @symbolist;

foreach $stock (@symbolist) {
	$quant = ExecSQL($dbuser,$dbpass, "select sum(quantity) from Holdings where datestamp<=$to and symbol='$stock'");
	push (@quantities,$quant);
}
#select sum(quantity) from Holdings where datestamp<=? and symbol=?",$to, $stock

foreach $quanti (@quantities) {
	print $quanti,"\t";
}

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
	$closeclause .= "$quantities[$i] * $c\.close + ";
	$fromclause .= "StocksDaily as $c, ";

	$fromclause_ora .= "NewStocks $c, ";

	$symbolsclause .= "$c\.symbol = '$symbolist[$i]' and ";
	$dateclause .= "$c\.date=".chr(ord($c)+1)."\.date and ";

	$dateclause_ora .= "$c\.datestamp=".chr(ord($c)+1)."\.datestamp and ";

	$symbols .= "symbol='$symbolist[$i]' or ";
}
$closeclause .= "$quantities[$i] * $c\.close";
$fromclause .= "StocksDaily as $c";

$fromclause_ora .= "NewStocks $c";

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

push @fields_ora, "$c\.datestamp" if !$nodate;
push @fields_ora, "open" if $open;
push @fields_ora, "high" if $high;
push @fields_ora, "low" if $low;
push @fields, "volume" if $vol;

$sql = "select ".join(",",@fields).", ($closeclause) from ";
$sql .= $fromclause." where ".$symbolsclause.$dateclause;
#$sql.= " where $symbols";
$sql.= "$c\.date>=$from" if $from;
$sql.= " and $c\.date<=$to" if $to;
$sql.= " order by $c\.date";

print $sql,"\n";

$exec = "mysql --batch --silent --user=$user --password=$pass --database=$db --execute=\"$sql\"";

$exec .= ">_plot.in" if $plot;

system $exec;

$sql2 = "select ".join(",",@fields_ora).", ($closeclause) from ";
$sql2 .= $fromclause_ora." where ".$symbolsclause.$dateclause_ora;
$sql2 .= "$c\.datestamp>=$from" if $from;
$sql2 .= " and $c\.datestamp<=$to" if $to;
$sql2 .= " order by $c\.datestamp";

print "\n",$sql2,"\n";

@newdata = ExecSQL($oracle_user,$oracle_pass,$sql2) ;

if($plot) {

	open(FILE, ">>_plot.in");

	foreach $row(@newdata) {
		$printrow = join("	", @{$row});
		print FILE "$printrow\n";
	}
	close(FILE);
}


#if ($plot) {
#  open(GNUPLOT, "|gnuplot");
#  GNUPLOT->autoflush(1);
#  print GNUPLOT "set title '$symbol'\nset xlabel 'time'\nset ylabel 'data'\n";
#  print GNUPLOT "plot '_plot.in'\n";
#  STDIN->autoflush(1);
#  <STDIN>;
#}


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

sub getQuantity{
	#my ($sym, $date)=@_;
	my @col;
	eval { @col=ExecSQL($oracle_user,$oracle_pass,"select sum(quantity) from Holdings where datestamp<=? and symbol=?",$to, $stock); };
	if($@){
		return (undef, $@);
	}
	else{
		return ($col[0]);
	}
}
