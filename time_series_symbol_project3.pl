#!/usr/bin/perl -w

use Getopt::Long;
use DBI;

$#ARGV>=0 or die "usage: time_series_symbol_project.pl [--o=op. modifiers] [--oo=op. modifier args] [--m=model] [--mo=model args] date steps-ahead symbol+ \n";

$oracle_user='drp925';
$oracle_pass='o3d7f737e';

$o = "";
$oo = "";
$m = "";
$mo = "";
&GetOptions("o=s" => \$o,
            "oo=s" => \$oo,
            "m=s" => \$m,
            "mo=s" => \$mo);

if($m eq ""){
    die "no model chosen";
}
elsif(($o ne "") && ($oo ne "")){
    $model=join(" ",$o, $oo, $m, $mo);
}
elsif($mo ne ""){
    print "Came here\n";
    $model=join(" ",$m, $mo);
}
else{
    $model=$m;
}


print "model: ".$model."\n";
$date=shift;
#print $date."\n";
$steps=shift;
#print $steps."\n";

#foreach my $a (@ARGV){
#    print "a: ".$a."\n";
#}
#
#make the data array
$d = $date;
$numPredictions = $steps;
my @dateArray;
@predictedArray = (("") x $numPredictions);

for($k = 0; $k < $numPredictions; $k++){
    push(@dateArray, $d);
     $d = $d + (24*60*60);
    # print $predictedArray[$k]."\n";
}

#foreach my $d (@dateArray){
#    print $d."\n";
#}


while($symbol=shift){
    my ($q, $e) = getQuantity($symbol,$date);
    if($e){
        print "Could not get quantity: $e";
    }
    #print "q ".$q."\n";
    #$filename = _data.in;
    system "perl get_data.pl --close $symbol --to=$date > _data.in";
    system "./time_series_project _data.in $steps $model > predict.txt";
    
    
    $data_file="predict.txt";
    open(DAT, $data_file) || die("Could not open file!"); 
    @data= <DAT>;
    close(DAT);
    $len = scalar(@data);
    $end = $len - $steps;
    my @predictlines;
    my $i = $end;
    while($i < $len){
        #print $data[i]."\n";
        push(@predictlines, $data[$i]);
        $i = $i + 1;
    }
    #predict value * quantity
    for($m=0; $m < $numPredictions; $m++){
        my($a1, $a2, $a3) = split(/\s+/,$predictlines[$m]);
        $predictedArray[$m].= ($q*$a3)." | ";
        #print $predictlines[$m];
        #print "\t";
        #print $predictedArray[$m]; 
        #print "\n";
    }
   
}#end of while loop

#dump the portfolio prediction to file
$fname = "_pp.in";
open (MYFILE, ">".$fname);
for($n=0; $n < $numPredictions; $n++){
    @pA = split(/ | /, $predictedArray[$n]);
    my $sum = 0;
    foreach $a(@pA){
        if($a ne "|"){
            $sum = $sum + $a;
        }
    }
    print MYFILE $dateArray[$n];
    print MYFILE "\t";
    print MYFILE $sum;
    print MYFILE "\n";
}

sub getQuantity{
    my ($sym, $date)=@_;
	my @col;
	eval { @col=ExecSQL($oracle_user,$oracle_pass,"select sum(quantity) from Holdings where datestamp <= ? and symbol=?",'COL',$date, $sym); };
	if($@){
		return (undef, $@);
	}
	else{
		return ($col[0], $@);
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