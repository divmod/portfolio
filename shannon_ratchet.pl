#!/usr/bin/perl -w 
use POSIX;

$#ARGV==3 or die "usage: shannon_ratchet.pl symbol initialcash tradingcost fromdate\n";

($symbol, $initialcash,$tradecost,$fromdate) = @ARGV;


$lastcash=$initialcash;
$laststock=0;
$lasttotal=$lastcash;
$lasttotalaftertradecost=$lasttotal;

open(STOCK, "./get_data.pl --close $symbol --from $fromdate |");


$cash=0;
$stock=0;
$total=0;
$totalaftertradecost=0;

$day=0;



while (<STOCK>) { 
  chomp;
  @data=split;
  $stockprice=$data[1];

  $currenttotal=$lastcash+$laststock*$stockprice;
  if ($currenttotal<=0) {
    exit;
  }
  
  $fractioncash=$lastcash/$currenttotal;
  $fractionstock=($laststock*$stockprice)/$currenttotal;
  $thistradecost=0;
  if ($fractioncash >= 0.5 ) {
    $redistcash=($fractioncash-0.5)*$currenttotal;
    if ($redistcash>0) {
      $cash=$lastcash-$redistcash;
      $stock=$laststock+$redistcash/$stockprice;
      $thistradecost=$tradecost;
    } else {
      $cash=$lastcash;
      $stock=$laststock;
    } 
  }  else {
    $redistcash=($fractionstock-0.5)*$currenttotal;
    if ($redistcash>0) {
      $cash=$lastcash+$redistcash;
      $stock=$laststock-$redistcash/$stockprice;
      $thistradecost=$tradecost;
    }
  }
  
  $total=$cash+$stock*$stockprice;
  $totalaftertradecost=($lasttotalaftertradecost-$lasttotal) - $thistradecost + $total; 
  $lastcash=$cash;
  $laststock=$stock;
  $lasttotal=$total;
  $lasttotalaftertradecost=$totalaftertradecost;

  $day++;
  

#  print STDERR "$day\t$stockprice\t$cash\t".($stock*$stockprice)."\t$stock\t$total\t$totalaftertradecost\n";
}

close(STOCK);


$quantity = ceil($laststock);
$laststockvalue = $laststock*$stockprice;

		
#print "Invested:                        \t$initialcash\n";
#print "Days:                            \t$day\n";
print "$lasttotal $laststockvalue $lastcash $quantity";
#return $lasttotal;
		

