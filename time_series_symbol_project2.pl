#!/usr/bin/perl -w

use Getopt::Long;

$#ARGV>=2 or die "usage: time_series_symbol_project.pl symbol date steps-ahead model \n";

$symbol=shift;
#print $symbol."\n";
$date=shift;
#print $date."\n";
$steps=shift;
#print $steps."\n";

#foreach my $a (@ARGV){
#    print "a: ".$a."\n";
#}
$model=join(" ",@ARGV);


#$filename = _data.in;
system "perl get_data.pl --close $symbol --to=$date > _data.in";



system "./time_series_project _data.in $steps $model > predict.txt";

#foreach my $l (@output){
 #   print $l
  # print "\n";
#}
$data_file="predict.txt";
open(DAT, $data_file) || die("Could not open file!"); 
@data= <DAT>;
close(DAT);
#foreach my $d(@data){
#    print "----------\n";
#    print $d;
#    print "----------\n";
#}


$len = scalar(@data);
#print "len: ".$len."\n";
$end = $len - $steps;
#print "end: ".$end."\n";
my @predictlines;
my $i = $end;
while($i < $len){
    #print "----------\n";
   # print $data[$i];
    push(@predictlines, $data[$i]);
    $i = $i + 1;
}

open (MYFILE, '> _plot.in');

foreach my $p (@predictlines){
    #print "----------\n";
    #print $p;
    my($a1, $a2, $a3) = split(/\s+/,$p);
    print MYFILE $a3;
   # print $a3;
    print MYFILE "\n";
}
close(MYFILE);
