#!/usr/bin/perl -w

#
# Some debugging options
# all of this debugging info will be shown at the *end* of script
# execution.
#
# database input and output is paired into the two arrays noted
#
my $show_params=1;
my $show_cookies=1;
my $show_sqlinput=1;
my $show_sqloutput=1;
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);

# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;

#For ceiling function
use POSIX;
#
# The following is necessary so that DBD::Oracle can
# find its 
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

# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again.
#
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="PortfolioSession";

#
# Get the session input cookie, if any
#
my $inputcookiecontent = cookie($cookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $loginok=0;
my $logincomplain=0;
#
#
# Get action user wants to perform
#
my $action;
if (param("act")) { 
	$action=param("act");
# print h2($action);
} else {
	$action="login";
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login" || param('loginrun') || $action eq "users") { 
	if (param('loginrun')) { 
#
# Login attempt
#
# Ignore any input cookie.  Just validate user and
# generate the right output cookie, if any.
#
		($user,$password)=(param('user'),param('password'));
		if (ValidUser($user,$password)) { 
# if the user's info is OK, then give him a cookie
# that contains his username and password 
# the cookie will expire in one hour, forcing him to log in again
# after one hour of inactivity.
# Also, land him in the query screen
			$outputcookiecontent=join("/",$user,$password);
			$loginok=1;
		} else {
# uh oh.  Bogus login attempt.  Make him try again.
# don't give him a cookie
			$logincomplain=1;
			$action="login";
		}
	}
	elsif($action eq "users"){
		$deletecookie=1;
	}
	else {
#
# Just a login screen request. Still, ignore any cookie that's there.
#
	}
}
else {
#
# Not a login request or attempt.  Only let this past if
# there is a cookie, and the cookie has the right user/password
#
	if ($inputcookiecontent) {
# if the input cookie exists, then grab it and sanity check it
		($user,$password) = split(/\//,$inputcookiecontent);
		if (!ValidUser($user,$password)) { 
# Bogus cookie.  Make him log in again.
			$action="login";
# don't give him an output cookie
		} else {
# cookie is OK, give him back the refreshed cookie
			$outputcookiecontent=$inputcookiecontent;
		}
	} else {
#
# He has no cookie and must log in.
#
		$action="login";
	}
}


#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
	$deletecookie=1;
}




#
# OK, so now we have user/password
# and we *may* have a cookie.   If we have a cookie, we'll send it right 
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if ($outputcookiecontent) { 
	my $cookie=cookie(-name=>$cookiename,
			-value=>$outputcookiecontent,
			-expires=>($deletecookie ? '-1h' : '+1h'));
	print header(-expires=>'now', -cookie=>$cookie);
} else {
	print header(-expires=>'now');
}

#
# Now we finally begin spitting back HTML
#
#
print start_html('Portfolio');


if ($loginok) { 
	print "<h2>You have successfully logged in</h2>";
}

#
#
# The remainder here is essentially a giant switch statement based
# on $action.  In response to an action, we will put up one or more forms.
# Each form contains a hidden parameter that lets us know whether the 
# script is being called with form contents. If we are getting form contents
# we also generate the output following it
#
#


# LOGIN
#
# Login is a special case since we handle the filled out form up above
# in the cookie-handling code.  So, here we only put up the form.
# 
#
if ($action eq "login") { 
	if ($logincomplain) { 
		print "Login failed.  Try again.<p>";
	} 
	if ($logincomplain or !param('loginrun')) { 
		print start_form(-name=>'Login'),
					h2('Login to Portfolio Manager'),
					"Name:",textfield(-name=>'user'),	p,
					"Password:",password_field(-name=>'password'),p,
					hidden(-name=>'act',default=>['login']),
					hidden(-name=>'loginrun',default=>['1']),
					submit(-name=>'Login'),
					end_form;
	}
}

if ($action eq "logout") { 
	print "<h2>You have been successfully logged out</h2>";
}

##############PORTFOLIO##################################
if ($action eq "display") {
#
#   
	topPanel();

	my ($table,$error)=PortfoliosTable();
	if ($error) {
		print "Can't display your portfolios because: $error";
	} else {
		print "<h2>Your Portfolios</h2>$table";
	}

#Query for portfolios and display the info
#To be done by Irene



#Also give the option to create a new portfolio
#print h3('<a href="portfolio.pl?act=create" target="output">Create New Portfolio</a>');
#my ($count, $error1) = MysqlTest();
#if($error1){
#	print "Can't get count: $error1";
#}
#else{
#	print "count= ".$count;
#}
}

if($action eq "portfoliosummary") {
	my $pid = param('pid');
	my $strategy = param('strategy');
	my $cash = param('cash');
	my ($table,$error) = StocksTable($pid,$strategy,$cash);
	if ($error) {
		print "Can't display your stocks because: $error";
	} else {
		print "<h2>Your Stocks for Portfolio $pid</h2>$table";
	}
}
# CREATE
# Allows a user to create a new portfolio
if($action eq "create"){
	topPanel();
	print start_form(-name=>'Create'),
	      h2('Add Portfolio'),
	      "Portfolio Name:  ", textfield(-name=>'pname'),
	      p,
	      "Cash Amt:  ", textfield(-name=>'cashamt'),
	      p,
#	popup_menu(-name=>'strategy', -values=>['a', 'b', 'c'], -labels=>{'a' => 'buy n hold', 'b' => 'shannon rachet', 'c'=>'markov model'}, -default=>'a'), 
	      popup_menu(-name=>'strategy', -values=>['a', 'b'], -labels=>{'a' => 'buy n hold', 'b' => 'shannon rachet'}, -default=>'a'),
	      p,
	      hidden(-name=>'postrun',-default=>['1']),
	      hidden(-name=>'act',-default=>['create']), 
	      submit(-name=>'Submit'),
	      reset(),
	      end_form;
	if (param('postrun')) { 
#my $by=$user;
		my $pname=param('pname');
		my $cashamt=param('cashamt');
		my $strategy=param('strategy');
#print $strategy;
		my $s;
		if($strategy eq "a"){
			$s = "buy n hold";
		}
		elsif($strategy eq "b"){
			$s = "shannon rachet";
		}
#     elsif($strategy eq "c"){
#	$s = "markov model";
#      }
#print "came here\n";
		my $error=AddPortfolio($user, $pname, $cashamt,$strategy);
		if ($error) { 
			print "Can't post message because: $error";
		}
		else {
			print "<h3>Portfolio $pname with \$$cashamt and $s strategy was successfully created by $user</h3>";
			my ($pid, $error)=LookUpPortfolio($user, $pname);
#print "pid= ".$pid;
			if($error){
				print "Can't buy: $error";
			}
			else{
				print "<h3><a href=\"portfolio.pl?act=buy&pid=$pid\">Buy Stock</a></h3>";
			}
		}
	}

}#end Create

#BUY
# Buy Stock

if($action eq "buy"){
#(Print) Cash Available : XXXX
#Enter Investment Amount: 
#Enter Date Purchased: [default is today]
	my $pid = param('pid');
	my ($iamt, $stock, $m, $d, $y, $pdate, $date);
# my $page = param('page');
#if($page == 1){
#print "Page = 1";
	my ($cashamt, $error1) = AvailableCashInPortfolio($pid);
	if($error1){
		print "Can't get available amt:$error1";
	}

	my (@stocks, $error2) = GetStocks();
	if($error2){
		print "Can't stocks:$error2";
	}


	print start_form(-name=>'Buy'),
	      h2('Buy Stock'),
	      p,
	      "Select a Stock ",
	      p,
	      scrolling_list(-name=>'stock', -values=>[@stocks],-size=>10),
	      p,
	      "Available Cash: ".$cashamt,
	      p,
	      "Enter Investment Amount:  ", textfield(-name=>'iamt'),
	      p,
	      "Enter Date Purchased:  ", 
	      textfield(-name=>'month',-size=>2), "/",
	      textfield(-name=>'day',-size=>2),"/",
	      textfield(-name=>'year',-size=>4),"(mm/dd/yyyy)",
	      p,
	      hidden(-name=>'postrun',-default=>['1']),
	      hidden(-name=>'pid',-default=>[$pid]),
	      hidden(-name=>'act',-default=>['buy']),
	      submit(-name=>'Buy'), reset(),
	      end_form;


	if (param('postrun')){
		$iamt = param('iamt');
		$stock = param('stock');
		$m = param('month');
		$d = param('day');
		$y = param('year');
		$pdate = $m."/".$d."/".$y." 00:00:00 GMT";
		$date =  parsedate($pdate);
		my($exists1, $error3) = StockExistsOnDateM($date, $stock);
#my ($value, $ee) = test($stock);
		my($exists2, $e) = StockExistsOnDateO($date, $stock);
#print "exist2: ".$exists2;
		if(!$exists1 && !$exists2){
			print h2('This stock does not exist for the date entered. Try Again.');
		}

		else{
			my $deduct = $cashamt - $iamt;
			if($deduct < 0){
				$iamt = $cashamt;
			}
			my ($exactDate, $ee);

			my ($closePrice, $error4);
			if($exists1){
				($exactDate, $ee) = exactDateM($date, $stock);
				if($ee){
					print "Could get the exactDate: $ee";
				}
				($closePrice, $error4) = GetClosingPriceM($exactDate, $stock);
			}
			elsif($exists2){
				($exactDate, $ee) = exactDateO($date, $stock);
				if($ee){
					print "Could get the exactDate: $ee";
				}
				($closePrice, $error4) = GetClosingPriceO($exactDate, $stock);
#print "closePrice: ".$closePrice;
			}
			if($error4){
				print "Problem getting close price:$error4";
			}
			if($closePrice > $iamt){
				print "<h4>You have insufficient funds to buy stock $stock as the close strike price for one share on".gmtime($exactDate)." is \$$closePrice</h4>";
#print "<h3><a href=\"portfolio.pl?act=cashManagement&pid=$pid\">Add Cash to Portfolio</a></h3>";
			}
			else{
				my $quantity = floor($iamt/$closePrice);
#print "<h4>Quantity:".$quantity."</h4>";
				print "<h4>Stock Chosen:".$stock."</h4>";
				print "<h4>Close price on ".gmtime($exactDate)." is "."\$".$closePrice."</h4>";
				$iamt = $quantity * $closePrice;
				print "<h4>Investment Amount to be Deducted for ". $quantity." shares : "."\$".$iamt."</h4>";
				print "<h3><a href=\"portfolio.pl?act=confirmBuy&pid=$pid&stock=$stock&date=$exactDate&iamt=$iamt&quant=$quantity\">Confirm</a></h3>";
			}#end closePrice<= $iamt
		}#end stock exists for date

	}#end postrun
}#end action buy


if($action eq "confirmBuy"){
	topPanel();
	my($iamt, $stock, $pid,$date, $quantity);
	$iamt = param('iamt');
	$stock = param('stock');
	$date = param('date');
	$pid = param('pid');
	$quantity = param('quant');
	print start_form(-name=>'ConfirmBuy'),
	      h2('Successful Purchase Summary'),
	      "Date of Purchase: ".gmtime($date),
	      p,
	      "Stock Chosen:".$stock,
	      p,
	      "Investment Amount: ".$iamt,
	      p,
	      "Quantity Purchased: ".$quantity,
	      p,      
	      hidden(-name=>'pid',-default=>[$pid]),
	      hidden(-name=>'iamt',-default=>[$iamt]),
	      hidden(-name=>'stock',-default=>[$stock]),
	      hidden(-name=>'date',-default=>[$date]),
	      hidden(-name=>'quant',-default=>[$quantity]),
	      hidden(-name=>'act',-default=>['confirmBuy']),
	      end_form;


#check to see if $date and $stock already in Holdings is so then to an update instead of insert
	my ($exists, $error) = HoldingExists($pid, $date, $stock);
	if($error){
		print "problem checking if holding exists: $error";
	}
	if($exists){
		my (@data, $ee) = GetAHolding($pid, $date, $stock);
		if($ee){
			print "Could get holding info: $ee";
		}
		$quantity = $quantity + $data[0];
		$iamt = $iamt + $data[1];
		my $e = UpdateAHolding($pid, $date, $stock, $quantity,$iamt);
	}
	else{
#Make a new entry in the holdings table
		my $error1 = AddToHoldings($pid, $date, $stock,$quantity, $iamt);
#		print "Came to Add To Holding\n";
		if ($error1) { 
			print "Holding transaction not succsessful: $error1";
		}
	}#end else scalar(@data)

	my ($amt, $error2) = AvailableCashInPortfolio($pid);
	if ($error2) { 
		print "Problem Retriving Cash Amount: $error2";
	}


#Update the cash amt in the portfolio
#Update the cash amt in the portfolio
	my $newamt = $amt - $iamt;
	my $error3 = ManageCash($pid, $newamt);
	if ($error3) { 
		print "Portfolio cash not properly debited: $error3";
	}
}
#Begin Joy Code Section#


#
# MANAGE CASH
#
# User can deposit or withdrawl cash from one of their portfolios
#
#

if ($action eq "cashmgmt") {
# 
# Get the portfolios of the user
#
#print "Username is: $user";
	topPanel();
	my (@portfolios, $portfolioerror) = GetPortfolioNames($user);
	if($portfolioerror){
		print "Can't get portfolios: $portfolioerror";
	}

	print start_form(-name=>'Cash Mgmt'),
	      h2('Manage your Portfolio Cash Accounts'),
	      "Portfolio Name:", scrolling_list(-name=>'portfolioname',-values=>[@portfolios],-size=>5),p,
	      "Transaction Type:", radio_group(-name=>'transaction', -values=>['Deposit','Withdraw'], -default=>'Deposit'),p,
	      "Amount: \$", textfield(-name=>'amount'),
	      p,
	      hidden(-name=>'postrun',-default=>['1']),
#		hidden(-name=>'pid',-default=>[GetPid($user,param('portfolioname'))]),
	      hidden(-name=>'act',-default=>['cashmgmt']),
	      submit,
	      end_form;

	if (param('postrun')) {
		my $portfolioname = param('portfolioname');
		my $transactiontype = param('transaction');
		my $amount = param('amount');

		my ($pidno,$error1) = LookUpPortfolio($user,$portfolioname);
		if ($error1) {
			print "Error in looking up pid number";
		}

		my ($availcash,$error2) = AvailableCashInPortfolio($pidno);
		if ($error2) {
			print "Error in getting AvailableCashInPortfolio";
		}
		else {
			print "<h2>Available Cash in Portfolio \"$portfolioname\": \$$availcash</h2>",p;
		}

#		print "Postrun! $portfolioname, $transactiontype, $amount, $pidno, $availcash",p;
		if ($transactiontype eq 'Deposit') {
			$availcash = $availcash + $amount;
			my $error3 = ManageCash($pidno, $availcash);
			if ($error3) { 
				print "Portfolio cash not properly debited: $error3";
			}
			print "<h2>Deposited \$$amount into Portfolio \"$portfolioname\"</h2>";
		}
		elsif ($transactiontype eq 'Withdraw') {
			if ($availcash < $amount) {
				print "Error in performing withdraw: available cash in portfolio insufficient";
			}
			else {
				$availcash = $availcash - $amount;
				my $error3 = ManageCash($pidno, $availcash);
				if ($error3) { 
					print "Portfolio cash not properly debited: $error3";
				}			
				print "<h2>Withdrew \$$amount from Portfolio $portfolioname</h2>";
			}
		}
	}
} #end cashmgmt action


if($action eq "sell"){
#Quantity: XX
#Enter Date Sold:
#Enter Quantity to be sold: 
	topPanel();
	my $pid = param('pid');
	my $stock = param('stock');
	my $bdate = param('bdate');
	my ($m, $d, $y, $sdate, $qsell);
	my (@data, $error1) = GetAHolding($pid, $bdate, $stock);
	if($error1){
		print "Problem getting holding info:$error1";
	}
	my $quant = $data[0];
	my $iinvest = $data[1];
#print "stock:".$stock."bdate: ".$bdate."quant: ".$quant." iinvest:".$iinvest; 
	print start_form(-name=>'Sell'),
	      h2('Sell Stock'),
	      p,
	      "Enter Date Sold:  ", textfield(-name=>'month',-size=>2), "/",textfield(-name=>'day',-size=>2),"/",textfield(-name=>'year',-size=>4),"(mm/dd/yyyy)",
	      p,
	      "Enter Quantity to be Sold: ", textfield(-name=>'qsell',-size=>3),
	      p
		      hidden(-name=>'postrun',-default=>['1']),
	      hidden(-name=>'pid',-default=>[$pid]),
	      hidden(-name=>'bdate',-default=>[$bdate]),
	      hidden(-name=>'stock',-default=>[$stock]),
	      hidden(-name=>'act',-default=>['sell']),
	      p,
	      submit(-name=>'sell'), reset(),
	      end_form;

	if(param('postrun')){
		$qsell = param('qsell');
		$m = param('month');
		$d = param('day');
		$y = param('year');
		$d = $m."/".$d."/".$y." 00:00:00 GMT";
		$sdate =  parsedate($d);
#print $sdate;
		my($exists1, $error2) = StockExistsOnDateM($sdate, $stock);
		my($exists2, $error3) = StockExistsOnDateO($sdate, $stock);
		my ($exactSDate, $ee);
		if($exists1){
			($exactSDate, $ee) = exactDateM($sdate, $stock);
		}
		elsif($exists2){
			($exactSDate, $ee) = exactDateO($sdate, $stock);
		}
		if($ee){
			print "Could not get the exact sell date: $ee";
		}
		if(!$exists1 && !$exists2){
			print h2('This stock does not exist for the date entered. Try Again!!'); 
		}
		elsif($exactSDate < $bdate){
			print h2('Cannot sell on date which is prior to purchase date to the stock. Try Again!');
		}
		elsif($quant - $qsell < 0){
			print h2('Cannot sell more than what you own. Try Again!');
		}
		else{
			my $diff = $quant - $qsell;
			print "You want to sell ".$qsell." shares of ". $stock. " stock on ".gmtime($exactSDate);
			print "<h3><a href=\"portfolio.pl?act=sellConfirm&pid=$pid&stock=$stock&bdate=$bdate&sdate=$exactSDate&qsell=$qsell&diff=$diff\">Confirm</a></h3>";
#Note put a cancel link that goes back to the portfolio.
		}   
	}#end postrun
}#end action sell


if($action eq "sellConfirm"){
	topPanel();
	my $pid = param('pid');
	my $stock = param('stock');
	my $bdate = param('bdate');
	my $sdate = param('sdate');
	my $qsell = param('qsell');
	my $diff = param('diff');
	my ($profitOrLoss, $cashback, $investUpdate);

#########Update portfolio Cash
#get closingPrice on sell date
	my($exists1, $e1) = StockExistsOnDateM($sdate, $stock);
	my($exists2, $e2) = StockExistsOnDateO($sdate, $stock);
	my ($closePriceS, $error1);
	if($exists1){
		($closePriceS, $error1) = GetClosingPriceM($sdate, $stock);
	}
	elsif($exists2){
		($closePriceS, $error1) = GetClosingPriceO($sdate, $stock);
	}
	if($error1){
		print "Problem getting close sell price:$error1";
	} 
	$cashback = $qsell * $closePriceS;
	my ($cash, $error2) = AvailableCashInPortfolio($pid);
	if($error2){
		print "Problem getting current cash of portfolio: $error2";
	}

	$cash += $cashback;
	my($error3) = ManageCash($pid, $cash);
	if($error3){
		print "Problem updating cash in portfolio:$error3";
	}

###calculate profit or loss
	my($exists3, $e3) = StockExistsOnDateM($bdate, $stock);
	my($exists4, $e4) = StockExistsOnDateO($bdate, $stock);
	my ($closePriceB, $error5);
	if($exists3){
		($closePriceB, $error5) = GetClosingPriceM($bdate, $stock);
	}
	elsif($exists4){
		($closePriceB, $error5) = GetClosingPriceO($bdate, $stock);
	}
	if($error5){
		print "Problem getting close buy price:$error5";
	}
	$profitOrLoss = ($closePriceS - $closePriceB)*$qsell;

###Check whether to delete the holding or update the holding
	if($diff == 0){
#Delete holding
		my $error4 = DeleteAHolding($pid,$bdate,$stock);
		if($error4){
			print "Problem deleting a holding:$error4";
		}
	}
	elsif($diff > 0){
#update holding
		$investUpdate = $diff * $closePriceB;
		my ($error6) = UpdateAHolding($pid, $bdate, $stock, $diff, $investUpdate);
		if($error6){
			print "Problem updating a holding:$error6";
		}
	}#end diff > 0

	print start_form(-name=>'Sell Summary'),
	      h2('Sell Summary'),
	      p,
	      "Sold ".$qsell." shares of stock ". $stock. " on ".gmtime($sdate),
	      p,
	      "Cash Received: \$".$cashback,
	      p,
	      "Profit(+)/Loss(-): ".$profitOrLoss,
	      hidden(-name=>'pid',-default=>[$pid]),
	      hidden(-name=>'stock',-default=>[$stock]),
	      hidden(-name=>'bdate',-default=>[$bdate]),
	      hidden(-name=>'sdate',-default=>[$sdate]),
	      hidden(-name=>'qsell',-default=>[$qsell]),
	      hidden(-name=>'diff',-default=>[$diff]),
	      hidden(-name=>'act',-default=>['sellConfirm']),
	      end_form;
}#end sell confirm 

#
# GET HISTORIC INFO
#
# This action displays the historic info of a stock 
#
#

# SEE HISTORICGRAPH.PL

#end Joy Code section#



# USERS
#
# Adding and deleting users is a couple of normal forms
#
#
if ($action eq "users") { 
##
## check to see if user can see this
##
#	if (!UserCan($user,"manage-users")) { 
#		print h2('You do not have the required permissions to manage users.');
#	} else {
##
# Generate the add form.
#
	print start_form(-name=>'AddUser'),
	      h2('Register'),
	      "Enter username: ", textfield(-name=>'name'),
	      p,
	      "Enter password: ", textfield(-name=>'password'), " (Must be 8 characters long)",
	      p,
	      hidden(-name=>'adduserrun',-default=>['1']),
	      hidden(-name=>'act',-default=>['users']),
	      submit(-name=>'Submit'),
	      end_form;

#
# Run the user add
#
	if (param('adduserrun')) { 
		my $name=param('name');
		my $password=param('password');
		my $error;
		$error=UserAdd($name,$password);
		if ($error) { 
			print "<h2>username already exists or password is less than 8 characters</h2>";
		} else {
			print "<h2>$name you have successfully registered!</h2>";
		}
	}

}#end users

#
# Generate debugging output if anything is enabled.
#
#
if ($show_params || $show_cookies || $show_sqlinput || $show_sqloutput) { 
	print hr, p, hr,p, h2('Debugging Output');
	if ($show_params) { 
		print h3('Parameters');
		print "<menu>";
		print map { "<li>$_ => ".param($_)} param();
		print "</menu>";
	}
	if ($show_cookies) { 
		print h3('Cookies');
		print "<menu>";
		print map { "<li>$_ => ".cookie($_)} cookie();
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

print end_html;

#
# The main line is finished at this point. 
# The remainder includes utilty and other functions
#

#############Portfolio functionality##########
#Insert a row in Portfolio table
sub AddPortfolio {
	my ($username,$pname, $cashamt, $strategy)=@_;
#INSERT INTO Portfolio(pid, username, name, cashamt, strategy) VALUES(pid.nextval,'root','myportfolio', 10000.00, 'b');
	eval { ExecSQL($dbuser,$dbpasswd,"insert into Portfolio(pid, username, name, cashamt, strategy) ".
			"select pid.nextval, ?, ?, ?, ? from dual",
			undef, $username, $pname, $cashamt, $strategy); };
	return $@;
}

#get the pid of Portfolio based on username and name
sub LookUpPortfolio{
	my($username, $pname) = @_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select pid from Portfolio where username=? and name =?","COL",$username, $pname);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

# Obtain the portfolio name based on the pid

sub PidToPortfolioName {
	my $pid = @_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select name from Portfolio where pid=?","COL",$pid);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

#get the available cash in Portfolio based on pid
sub AvailableCashInPortfolio{
	my($pid) = @_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select cashamt from Portfolio where pid=?","COL",$pid);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

#testing mysql
sub MysqlTest{
#my($sym) = @_;
	my @col;
	eval {@col=ExecMySQL("select count(*) from symbols","COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

#list of stocks based on search

sub GetStocks{
#my $search = @_;
#$search = "^".$search;
	my @cols;
#eval {@rows=ExecMySQL("select symbol from symbols where symbol regexp ?","ROW", $search);};
	eval {@cols=ExecMySQL("select symbol from symbols","COL");};
	if ($@) {
		return (undef,$@);
	}
	else {
		return (@cols,$@);
	}

}

#begin Joy Code Section#

#
# GetPortfolioNames
#
# Lists the portfolio names owned by the user
#

sub GetPortfolioNames {
#		my $usern = @_;
#		print "Username in GetPortfiolioNames Function: $usern, $user";
	my @cols;
	eval {@cols=ExecSQL($dbuser,$dbpasswd,"select name from Portfolio where username=?","COL",$user);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return (@cols,$@);
	}
}

#end Joy Code Section#

#get closing price of the stock on based on the date from StockDaily
#check if the stock exists in StockDaily
sub StockExistsOnDateM{
	my($date, $sym) = @_;
	my @col;
#select count(*) from StocksDaily where date=1151470800 and symbol='GOOG'; 
	eval {@col=ExecMySQL("select count(*) from StocksDaily where date >=? and date < ? and symbol=?","COL",$date,$date+(24*60*60),$sym);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0]>0,$@);
	}
}

#check if the stock exists in NewStocks
sub StockExistsOnDateO{
	my($date, $sym) = @_;
#print "I am in Stock".$date."\n";
#print "sym: ".$sym."\n";
	my $endDate = $date + (24*60*60);
	my @col;
#select count(*) from OurStocksDaily where date=1151470800 and symbol='GOOG'; 
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select count(*) from NewStocks where datestamp>=? and datestamp<? and symbol=?","COL",$date,$endDate,$sym);};
	if ($@) {
		return (undef,$@);
	}
	else {
#print "c: ".$col[0];
		return ($col[0] > 0,$@);
	}
}

#return the date based on range and symbol
sub exactDateM{
	my($date, $sym) = @_;
	my @col;
#select count(*) from StocksDaily where date=1151470800 and symbol='GOOG'; 
	eval {@col=ExecMySQL("select date from StocksDaily where date >=? and date < ? and symbol=?","COL",$date,$date+(24*60*60),$sym);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

sub exactDateO{
	my($date, $sym) = @_;
#print "date:".$date;
	my @col;
	my $endDate = $date+(24*60*60);
#select count(*) from OurStocksDaily where date=1151470800 and symbol='GOOG'; 
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select DATESTAMP from NewStocks where datestamp>=? and datestamp<? and symbol=?","COL",$date,$endDate,$sym);};
	if ($@) {
		return (undef,$@);
	}
	else {
#       print "c: ".$col[0];
		return ($col[0],$@);
	}
}
#get closing price of the stock on based on the date from StocksDaily
sub GetClosingPriceM{
	my($date, $sym) = @_;
#print " ".$date;
#print "sym: ".$sym;
	my @col;
#select close from StocksDaily where date=1151470800 and symbol='GOOG'; 
	eval {@col=ExecMySQL("select close from StocksDaily where date=? and symbol=?","COL",$date, $sym);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

#get closing price of the stock on based on the date from OurStocksDaily
sub GetClosingPriceO{
	my($date, $sym) = @_;
	my @col;
#select close from NewStocks where date=1151470800 and symbol='GOOG'; 
	eval {@col=ExecSQL($dbuser,$dbpasswd,"select close from NewStocks where datestamp=? and symbol=?","COL",$date,$sym);};
	if ($@) {
		return (undef,$@);
	}
	else {
		return ($col[0],$@);
	}
}

# insert a row into holdings.
sub AddToHoldings{

#insert into Holdings(id, datestamp, symbol, quantity, iinvest) values(2081, 1151470800 , 'GOOG', 10, 500);
	my ($pid,$date, $sym, $quant, $iinvest)=@_;
	eval { ExecSQL($dbuser,$dbpasswd,"insert into Holdings(id, datestamp, symbol, quantity, iinvest) values(?, ?, ?, ?, ?)",undef, $pid, $date, $sym, $quant, $iinvest); };
	return $@;
}

# update the cashamt
sub ManageCash{
	my ($pid, $amt) = @_;
#update Portfolio set cashamt=7000 where pid=1035;
	eval{ExecSQL($dbuser,$dbpasswd,"update Portfolio set cashamt=? where pid=?", undef, $amt, $pid);};
	return @;
}



#get a row in holdings based on pid, stock, and date and return $quantity and $iinvest
sub GetAHolding{

	my ($pid,$date,$sym)=@_;
	my @row;
	eval { @row=ExecSQL($dbuser,$dbpasswd,"select quantity, iinvest from Holdings where id =? and datestamp =? and symbol=?",'ROW', $pid, $date, $sym); };
	if($@){
		return (undef, $@);
	}
	else{
		return (@row, $@);
	}
}

sub HoldingExists{

	my ($pid,$date,$sym)=@_;
	my @col;
	eval { @col=ExecSQL($dbuser,$dbpasswd,"select count(*) from Holdings where id =? and datestamp =? and symbol=?",'COL', $pid, $date, $sym); };
	if($@){
		return (undef, $@);
	}
	else{
		return ($col[0] > 0, $@);
	}
}

#get a row in holdings based on pid, stock, sym with $quantity and $iinvest
sub UpdateAHolding{
	my ($pid,$date,$sym,$quantity,$iinvest)=@_;
	eval{ExecSQL($dbuser,$dbpasswd,"update Holdings set quantity=?, iinvest = ? where id=? and datestamp=? and symbol=?", undef, $quantity, $iinvest, $pid, $date, $sym);};
	return @;
}

#delete a row in holdings based on pid, stock, sym
sub DeleteAHolding{
	my ($pid,$date,$sym)=@_;
	eval{ExecSQL($dbuser,$dbpasswd,"delete from Holdings where id=? and datestamp=? and symbol=?", undef, $pid, $date, $sym);};
	return @;
}

sub WriteStocksToFile{

	my (@stocks, $error2) = GetStocks();
	if($error2){
		print "Can't stocks:$error2";
	}
	open (MYFILE, '>>stocksC.txt');
	foreach my $s (@stocks){
		print MYFILE $s." ";
	}

}

sub topPanel(){
	print "<div class=\"clear_in\"> </div>\n";
	print "<div class=\"sp\">\n";
	print "&nbsp;&nbsp;&nbsp;\n";
	print "<h3><a class=\"menutext\" href=\"portfolio.pl?act=display\">Home</a>";
	print "&nbsp;&nbsp;\n";
	print "<a class=\"menutext\" href=\"portfolio.pl?act=create\">Create Portfolio</a>";
	print "&nbsp;&nbsp;\n";
	print "<a class=\"menutext\" href=\"portfolio.pl?act=cashmgmt\">Cash Management</a></h3>";
	print "&nbsp;&nbsp;\n";
	print "</div>\n";
	print "<div class=\"clear\"> </div>\n";
}
#
# @list=ExecMySQL($querystring, $type, @fill);
#
# Executes a MySQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
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

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
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


#IKH - 
sub PortfoliosTable {
	my @rows;
	my $out = "";
	eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, cashamt, strategy, pid from portfolio where username = '$user'"); };
	if ($@) {
		return (undef,$@);
	} else {
		$out.="<table border><tr><td>NAME</td><td>CASH</td><td>STRATEGY</td><td>VALUE</td></tr>";

		foreach my $row (@rows) {
			my ($name, $cash, $strategy, $pid) = @{$row};
			my ($strategyname, $portfoliosum)=("",$cash);
			my @holdingrows;

			eval { @holdingrows = ExecSQL($dbuser, $dbpasswd, "select datestamp, symbol, iinvest, quantity from holdings where id = '$pid'"); };
			if ($@) {
				return (undef,$@);
			} else {
				foreach my $holdingrow (@holdingrows) {
					my ($date, $symbol, $invest, $quantity) = @{$holdingrow};


					if($strategy eq "a"){
						$strategyname = "buy n hold";
						my ($stocksum,$error) = BuyNHold($symbol,$quantity);
						if ($error) {
							print "Can't display portfolio value  because: $error";
						} else {
							$portfoliosum += $stocksum;
						}
					}

					elsif ($strategy eq "b") {
						$portfoliosum += `./shannon_ratchet.pl '$symbol' $invest 0 '$date'`;
						$strategyname = "shannon ratchet";
					}
				} 
			} 
			$out.="<tr><td><a href = \"portfolio.pl?act=portfoliosummary&pid=$pid&strategy=$strategy&cash=$cash\">$name</a></td><td>$cash</td><td>$strategyname</td><td>$portfoliosum</td></tr>";
		}
		$out.="</table>";
		return $out;
	}

	sub UserTable {
		my @rows;
		eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name from Users order by name"); }; 
		if ($@) { 
			return (undef,$@);
		} else {
			return (MakeTable("2D",
						["Name"],
						@rows),$@);
		}
	}
}
#IKH - 
sub PortfoliosTable {
	my @rows;
	my $out = "";
	eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, cashamt, strategy, pid from portfolio where username = '$user'"); };
	if ($@) {
		return (undef,$@);
	} else {
		$out.="<table border><tr><td>NAME</td><td>CASH</td><td>STRATEGY</td><td>VALUE</td></tr>";

		foreach my $row (@rows) {
			my ($name, $cash, $strategy, $pid) = @{$row};
			my ($strategyname, $portfoliosum)=("",$cash);
			my @holdingrows;

			eval { @holdingrows = ExecSQL($dbuser, $dbpasswd, "select datestamp, symbol, iinvest, quantity from holdings where id = '$pid'"); };
			if ($@) {
				return (undef,$@);
			} else {
				foreach my $holdingrow (@holdingrows) {
					my ($date, $symbol, $invest, $quantity) = @{$holdingrow};


					if($strategy eq "a"){
						$strategyname = "buy n hold";
						my ($stocksum,$error) = BuyNHold($symbol,$quantity);
						if ($error) {
							print "Can't display portfolio value  because: $error";
						} else {
							$portfoliosum += $stocksum;
						}
					}

					elsif ($strategy eq "b") {
						$portfoliosum += `./shannon_ratchet.pl '$symbol' $invest 0 '$date'`;
						$strategyname = "shannon ratchet";
					}
				} 
			} 
			$out.="<tr><td><a href = \"portfolio.pl?act=portfoliosummary&pid=$pid&strategy=$strategy&cash=$cash\">$name</a></td><td>$cash</td><td>$strategyname</td><td>$portfoliosum</td></tr>";
		}
		$out.="</table>";
		return $out;
	}
}


sub StocksTable {
	my($pid, $strategy, $cash) = @_;
	my @rows;
	my $out = "";
	eval { @rows = ExecSQL($dbuser, $dbpasswd, "select datestamp, symbol, iinvest, quantity from holdings where id = '$pid'"); };
	if ($@) {
		return (undef,$@);
	} else {
		$out.="<table border><tr><td>STOCK</td><td>DATE PURCHASED</td><td>INVESTMENT</td><td>QUANTITY</td><td>CURRENT VALUE</td></tr>";
		my $portfoliosum = $cash;
		foreach my $row (@rows) {
			my ($date, $symbol, $invest, $quantity) = @{$row};
			my $stocksum = 0;
			my $error;
			if($strategy eq "a"){
				($stocksum,$error) = BuyNHold($symbol,$quantity);
				if ($error) { 
					print "Can't display portfolio value  because: $error";
				} else {
					$portfoliosum += $stocksum;
				}
			}
			elsif ($strategy eq "b") {
				$stocksum = `./shannon_ratchet.pl '$symbol' $invest 0 '$date'`;
				$portfoliosum += $stocksum;
			}

			my $idate = strftime("%m/%d/%Y", gmtime($date));
			$out.="<tr><td>$symbol</td><td>$idate</td><td>$invest</td><td>$quantity</td><td>$stocksum</td>";
			$out.="<td><a href = \"historicinfo.pl?symbol=$symbol\">Historic Data</a></td>";
			$out.="<td><a href = \"statistics.pl?symbol=$symbol\">Statistical Analysis</a></td>";
			$out.="<td><a href = \"predict_form.pl?symbol=$symbol\">Predict</a></td>";
			$out.="<td><a href = \"portfolio.pl?act=sell&pid=$pid&stock=$symbol&bdate=$date\">Sell</a></td></tr>";
		}

		$out.="<tr><td>CASH</td><td></td><td></td><td></td><td>$cash</td>";
		$out.="<tr><td></td><td></td><td></td><td>TOTAL PORTFOLIO VALUE:</td><td>$portfoliosum</td></table>";
		$out.="<h3><a href=\"portfolio.pl?act=buy&pid=$pid\">Buy Stock</a></h3>";
		$out.="<h3><a href=\"p_statistics.pl?pid=$pid\">Analyze This Portfolio</a></h3>";
		$out.="<h3><a href=\"p_predict.pl?pid=$pid\">Predict This Portfolio</a></h3>";
		$out.="<h3><a href=\"p_historicinfo.pl?pid=$pid\">Past Performance of This Portfolio</a></h3>";
		return $out;
	}
}
#
sub BuyNHold {
	my ($symbol,$quantity)=@_;
	my @stockValue;
	eval { @stockValue = ExecSQL($dbuser, $dbpasswd, "select $quantity*close from NewStocks where symbol = '$symbol' and datestamp = (select max(datestamp) from NewStocks where symbol = '$symbol')", "COL"); };
	if ($@) {
		eval { @stockValue = ExecMySQL("select $quantity*close from StocksDaily where symbol = '$symbol' order by date desc limit 1", "COL"); };
		if ($@) {return (undef,$@); }
		else { return ($stockValue[0],$@) } ;
	} else { return ($stockValue[0],$@) } ;
}



sub UserAdd { 
	eval { ExecSQL($dbuser,$dbpasswd,
			"insert into users (username,password) values (?,?)",undef,@_);};

	return $@;
}

#
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
	my ($user,$password)=@_;
	my @col;
	eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from Users where username=? and password=?","COL",$user,$password);};
	if ($@) { 
		return 0;
	} else {
		return $col[0]>0;
	}
}


#
#
#
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


