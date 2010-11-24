#!/usr/bin/perl -w 
use POSIX;

$#ARGV==2 or die "usage: hindsight.pl symbol initialquantity fromdate\n";

($symbol, $initialquantity,$fromdate) = @ARGV;


open(STOCK, "./get_data.pl --high --low  $symbol --from $fromdate |");

$cash=0;
$stock=$initialquantity;
$lasthigh=0;
$lastlow=0;  

while (<STOCK>) { 
  chomp;
  @data=split;
  $stockhigh=$data[1];
  $stocklow=$data[2];

  if($stock == 0) {
    if ($lastlow lt $stocklow) {
       $stock = floor($cash/$lastlow); 
       $price = $lastlow * $stock; 
       $cash = $cash - $price; 
    }
  } else {
    if ($lasthigh gt $stockhigh) {
       $price = $stock*$lasthigh;
       $cash = $cash + $price;
       $stock = 0;
    }
  } 

  $lasthigh=$stockhigh;
  $lastlow=$stocklow;  
}

close(STOCK);

$quantity = $stock;
$laststockvalue = $stock*$lasthigh;
$totalvalue = $cash + $laststockvalue;
		
print "$totalvalue $laststockvalue $cash $quantity";
		

