#!/usr/bin/perl -w

use Data::Dumper;
use Finance::Quote;
use Time::ParseDate;
use DBI;
$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";
$#ARGV>=0 or die "usage: quote.pl  filename\n";


@info=("date","time","high","low","close","open","volume");
$dbuser="drp925";
$dbpasswd="o3d7f737e";

$data_file=$ARGV[0];
open(DAT, $data_file) || die("Could not open file!"); 
@sym= <DAT>;
close(DAT);


foreach my $s (@sym){
  #print $s."\n";
  #$i++;
}


@group = split(/ /, $sym[0]);

$len = scalar(@group);
print "len :".$len."\n";
$i = 0;
while($i < $len){
    my @symbols;
    print "i: ".$i."\n";
    my $j;
    for($j =$i ; $j < $i + 25; $j++){
        push(@symbols, $group[$j]);	
    }
    foreach my $s (@symbols){
	if(defined($s)){
	    print $s."\n";
	}
    }
    my $con=Finance::Quote->new();

    $con->timeout(60);
    #print "came here\n";
    #@symbols = ("GOOG", "AAPL");
    my %quotes = $con->fetch("usa",@symbols);


    foreach $symbol (@symbols) {
        #print $symbol."\n";
        print $symbol,"\n=========\n";
        if (!defined($quotes{$symbol,"success"})) { 
        	print "No Data\n";
        }
        else {
            my @data;
	    foreach $key (@info) {
		if (defined($quotes{$symbol,$key})) {
        	    #print $key,"\t",$quotes{$symbol,$key},"\n";
        	    push(@data,$quotes{$symbol,$key});
		}
	    }
	    print "***\n";
	    my $k;
	    for($k = 0; $k < scalar(@data); $k++){
		print $data[$k]."\n";
	    }
	    print "***\n";
	    if(defined($quotes{$symbol, "date"})&& defined($quotes{$symbol, "high"}) && defined($quotes{$symbol, "low"}) && defined($quotes{$symbol, "close"}) && defined($quotes{$symbol, "open"}) && defined($quotes{$symbol, "volume"})){
	        print "Came here\n";
	        my $date = parsedate($data[0]." 05:00:00 GMT");
	        print "date: ".$date,"\n";
	        my $high = $data[2];
	        print "high: ".$high,"\n";
	        my $low = $data[3];
	        print "low: ".$low,"\n";
	        my $close = $data[4];
	        print "close: ".$close,"\n";
	        my $open = $data[5];
	        print "open: ".$open,"\n";
	        my $volume = $data[6];
	        print "volume: ".$volume,"\n";
	        my $error = AddToOurStocksDaily($symbol,$date, $high, $low, $close, $open, $volume);
	        if($error){
	            print "Could not add stock:$error";
	        }
	    }
	}
    }
    print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
    $i = $i + 25;
}

sub AddToOurStocksDaily{
  my ($symbol,$date, $open, $high, $low, $close, $volume)=@_;
  #INSERT INTO OurStocksDaily(symbol, datestamp, open, high, low, close,volume) VALUES;
  eval { ExecSQL($dbuser,$dbpasswd,"insert into NewStocks(symbol, datestamp, high, low, close, open, volume) values(?, ?, ?, ?, ?, ?, ?)",
		undef, $symbol,$date, $high, $low, $close, $open, $volume); };
  return $@;
}
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  #if ($show_sqlinput) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
   # push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  #}
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    #if ($show_sqloutput) { 
     # push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    #}
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    #if ($show_sqloutput) { 
     # push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    #}
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    #if ($show_sqloutput) { 
     # push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    #}
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  #my @data;
  #if (defined $type and $type eq "ROW") { 
  #  @data=$sth->fetchrow_array();
  #  $sth->finish();
  #  #if ($show_sqloutput) {push @sqloutput, MakeTable("ROW",undef,@data);}
  #  $dbh->disconnect();
  #  return @data;
  #}
  #my @ret;
  #while (@data=$sth->fetchrow_array()) {
  #  push @ret, [@data];
  #}
  #if (defined $type and $type eq "COL") { 
  #  @data = map {$_->[0]} @ret;
  #  $sth->finish();
  # # if ($show_sqloutput) {push @sqloutput, MakeTable("COL",undef,@data);}
  #  $dbh->disconnect();
  #  return @data;
  #}
  $sth->finish();
  #if ($show_sqloutput) {push @sqloutput, MakeTable("2D",undef,@ret);}
  $dbh->disconnect();
  #return @ret;
}