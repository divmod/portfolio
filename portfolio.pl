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
# You need to override these for access to your database
#
my $dbuser="ikh831";
my $dbpasswd="o29de7c3f";


#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again.
#
# "MicroblogSession"=>"user/password"
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
if ($action eq "login" || param('loginrun')) { 
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
  } else {
    #
    # Just a login screen request. Still, ignore any cookie that's there.
    #
  }
} else {
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
    print "Login failed.  Try again.<p>"
  } 
  if ($logincomplain or !param('loginrun')) { 
    print start_form(-name=>'Login'),
      h2('Login to Portfolio Manager'),
	"Name:",textfield(-name=>'user'),	p,
	  "Password:",password_field(-name=>'password'),p,
	    hidden(-name=>'act',default=>['login']),
	      hidden(-name=>'loginrun',default=>['1']),
		submit,
		  end_form;
  }
}

if ($action eq "logout") { 
  print "<h2>You have been successfully logged out</h2>";
}

# QUERY
#
# Query is a "normal" form.
#
#
#if ($action eq "query") {
#  #
#  # check to see if user can see this
#  #
#  if (!UserCan($user,"query-messages")) { 
#    print h2('You do not have the required permissions to query messages.');
#  } else {
#    #
#    # Generate the form
#    # This is the part you will be extending
#    #
#    print start_form(-name=>'Query'),
#      h2('Display blog entries'),
#	"From: ", textfield(-name=>'from',-default=>'yesterday'),
#	  "To: ", textfield(-name=>'to',-default=>'now'),
#	    p, "By: ", textfield('by'), p,
#	      hidden(-name=>'queryrun',default=>['1']),
#		hidden(-name=>'act',default=>['query']),
#		  submit,
#		    end_form;
#    #
#    # if we have the hidden parameter queryrun, then we have
#    # been invoked with data
#    #
#    if (param('queryrun')) {
#      my $from=param('from');
#      my $to=param('to');
#      my $by=param('by');
#      #
#      # Run the query (note, you need to write MessageQuery!)
#      # to actually use the parameters.  Right now it just returns all
#      # the messages.
#      #
#      my ($mq,$error) = MessageQuery($from,$to,$by);
#      if ($error) { 
#	print "Can't query messages because: $error";
#      } else {
#	print $mq;
#      }
#    } else {
#      #
#      # If we haven't been invoked with parameters, then just
#      # display a message summary.  You will update this to give
#      # a tree display
#      #
#      my ($ms,$error)=MessageSummary();
#      if ($error) { 
#	print "Can't summarize messages because: $error";
#      } else {
#	print $ms;
#      }
#    }
#  }
#}

##############PORTFOLIO##################################
if ($action eq "display") {
  
    #
    # Generate the form
    # This is the part you will be extending
    #   

    my ($table,$error)=PortfoliosTable();
    if ($error) {
      print "Can't display your portfolios because: $error";
    } else {
      print "<h2>Your Portfolios</h2>$table";
    }
 
    #Query for portfolios and display the info
    #To be done by Irene
   
     
 
    #Also give the option to create a new portfolio
    print h3('<a href="portfolio.pl?act=create" target="output">Create New Portfolio</a>');
    my ($count, $error) = MysqlTest();
    if($error){
	  print "Can't get count: $error";
    }
    else{
	print "count= ".$count;
    }
}

if($action eq "portfoliosummary") {
  my $pid = param('pid');
  my $strategy = param('strategy');
  my ($table,$error) = StocksTable($pid,$strategy);
  if ($error) {
     print "Can't display your stocks because: $error";
  } else {
    print "<h2>Your Stocks for Portfolio $pid</h2>$table";
  }
}
# CREATE
# Allows a user to create a new portfolio
if($action eq "create"){
  print start_form(-name=>'Create'),
	h2('Add Portfolio'),
	"Portfolio Name:  ", textfield(-name=>'pname'),
	p,
	"Cash Amt:  ", textfield(-name=>'cashamt'),
	p,
	popup_menu(-name=>'strategy', -values=>['a', 'b', 'c'], -labels=>{'a' => 'buy n hold', 'b' => 'shannon rachet', 'c'=>'markov model'}, -default=>'a'), 
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
      elsif($strategy eq "c"){
	$s = "markov model";
      }
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
	    p
	    "Enter Date Purchased:  ", textfield(-name=>'month',-size=>2), "/",textfield(-name=>'day',-size=>2),"/",textfield(-name=>'year',-size=>4),"(mm/dd/yyyy)",
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
	$pdate = $m."/".$d."/".$y." 05:00:00 GMT";
	$date =  parsedate($pdate);
	my($exists, $error3) = StockExistsOnDate($date, $stock);
	if(!$exists){
	    print h2('This stock does not exist for the date entered. Try Again.');
	    #print "<h3><a href=\"portfolio.pl?act=buy&pid=$pid\">Try Again</a></h3>";
	}
	else{
	   my $deduct = $cashamt - $iamt;
	   if($deduct < 0){
	      $iamt = $cashamt;
	   }
	  my ($closePrice, $error4) = GetClosingPrice($date, $stock);
	  if($error4){
	    print "Problem getting close price:$error4";
	  }
	  if($closePrice > $iamt){
	    print "<h4>You have insufficient funds to buy stock $stock as the close strike price for one unit on".localtime($date)." is \$$closePrice</h4>";
	    print "<h3><a href=\"portfolio.pl?act=cashManagement&pid=$pid\">Add Cash to Portfolio</a></h3>";
	  }
	  else{
	    my $quantity = floor($iamt/$closePrice);
	    #print "<h4>Quantity:".$quantity."</h4>";
	    print "<h4>Stock Chosen:".$stock."</h4>";
	    print "<h4>Close price on ".localtime($date)." is "."\$".$closePrice."</h4>";
	    $iamt = $quantity * $closePrice;
	    print "<h4>Investment Amount to be Deducted for ". $quantity." units : "."\$".$iamt."</h4>";
	    print "<h3><a href=\"portfolio.pl?act=confirmBuy&pid=$pid&stock=$stock&date=$date&iamt=$iamt&quant=$quantity\">Confirm</a></h3>";
	  }#end closePrice<= $iamt
	}#end stock exists for date
	
      }#end postrun
}#end action buy

if($action eq "confirmBuy"){

    my($iamt, $stock, $pid,$date, $quantity);
    $iamt = param('iamt');
    $stock = param('stock');
    $date = param('date');
    $pid = param('pid');
    $quantity = param('quant');
    print start_form(-name=>'ConfirmBuy'),
      h2('Successful Purchase Summary'),
      "Date of Purchase: ".localtime($date),
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

     #Make a new entry in the holdings table
     my $error1 = AddToHoldings($pid, $date, $stock,$quantity, $iamt);
     if ($error1) { 
      print "Holding transaction not succsessful: $error1";
    }
    
    my ($amt, $error2) = AvailableCashInPortfolio($pid);
    if ($error2) { 
      print "Problem Retriving Cash Amount: $error2";
    }
   
    #Update the cash amt in the portfolio
    my $newamt = $amt - $iamt;
    my $error3 = ManageCash($pid, $newamt);
     if ($error3) { 
      print "Portfolio cash not properly debited: $error3";
    }
}
###################################################################

# WRITE
#
# Write is a "normal" form.
#
#
if ($action eq "write") { 
  #
  # check to see if user can see this
  #
  if (!UserCan($user,"write-messages")) { 
    print h2('You do not have the required permissions to write messages.');
  } else {
    #
    # Generate the form.
    # Your reply functionality will be similar to this
    #
    print start_form(-name=>'Write'),
      h2('Make blog entry'),
	"Subject:", textfield(-name=>'subject'),
	  p,
	  textarea(-name=>'post', 
		   -default=>'Write your post here.',
		   -rows=>16,
		   -columns=>80),
          hidden(-name=>'postrun',-default=>['1']),
	  hidden(-name=>'act',-default=>['write']), 
	  submit,
	  end_form,
	  hr;

    #
    # If we're being invoked with parameters, then
    # do the actual posting. 
    #
    if (param('postrun')){ 
      my $by=$user;
      my $text=param('post');
      my $subject=param('subject');
      my $error=Post(0,$by,$subject,$text);
      if ($error) { 
	print "Can't post message because: $error";
      } else {
	print "Posted the following on $subject from $by:<p>$text";
      }
    }
  }
}


# USERS
#
# Adding and deleting users is a couple of normal forms
#
#
if ($action eq "users") { 
  #
  # check to see if user can see this
  #
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage users.');
  } else {
    #
    # Generate the add form.
    #
    print start_form(-name=>'AddUser'),
      h2('Add User'),
    "Name: ", textfield(-name=>'name'),
      p,
    "Email: ", textfield(-name=>'email'),
      p,
    "Password: ", textfield(-name=>'password'),
      p,
	hidden(-name=>'adduserrun',-default=>['1']),
          hidden(-name=>'act',-default=>['users']),
	  submit,
	       end_form,
		 hr;
    #
    # Generate the givepermform.
    #
    print start_form(-name=>'GivePermission'),
      h2('Give Permission'),
      "Name: ", textfield(-name=>'name'),
	p,
      "Action: ", textfield(-name=>'perm'),
	  hidden(-name=>'givepermrun',-default=>['1']),
          hidden(-name=>'act',-default=>['users']),p,
	  submit,
	       end_form,
	    hr;

    #
    # Generate the revokepermform.
    #
    print start_form(-name=>'RevokePermission'),
      h2('Revoke Permission'),
      "Name: ", textfield(-name=>'name'),
	p,
      "Action: ", textfield(-name=>'perm'),
	  hidden(-name=>'revokepermrun',-default=>['1']),
          hidden(-name=>'act',-default=>['users']),p,
	  submit,
	       end_form,
	    hr;

    #
    # Generate the deleteform.
    # Your delete message functionality may be similar to this
    #
    print start_form(-name=>'DeleteUser'),
      h2('Delete User'),
      "Name: ", textfield(-name=>'name'),
	p,
	  hidden(-name=>'deluserrun',-default=>['1']),
          hidden(-name=>'act',-default=>['users']),
	  submit,
	       end_form,
	    hr;

    #
    # Run the user add
    #
    if (param('adduserrun')) { 
      my $name=param('name');
      my $email=param('email');
      my $password=param('password');
      my $error;
      $error=UserAdd($name,$password,$email);
      if ($error) { 
	print "Can't add user because: $error";
      } else {
	print "Added user $name $email\n";
      }
    }
    #
    # Run the user delete
    #
    if (param('deluserrun')) { 
      my $name=param('name');
      my $error=UserDel($name);
      if ($error) { 
	print "Can't delete user because: $error";
      } else { 
	print "User $name deleted.";
      }
    }
    #
    # Run givepermission
    #
    if (param('givepermrun')) { 
      my $name=param('name');
      my $perm=param('perm');
      my $error=GiveUserPerm($name,$perm);
      if ($error) { 
	print "Can't give $name permission $perm because: $error";
      } else { 
	print "User $name given permission $perm.";
      }
    }
    #
    # Run givepermission
    #
    if (param('revokepermrun')) { 
      my $name=param('name');
      my $perm=param('perm');
      my $error=RevokeUserPerm($name,$perm);
      if ($error) { 
	print "Can't revoke $name permission $perm because: $error";
      } else { 
	print "User $name has had permission $perm revoked.";
      }
    }
    #
    # Print tables users Permissions
    #
    my ($table,$error);
    ($table,$error)=PermTable();
    if ($error) { 
      print "Can't display permissions table because: $error";
    } else {
      print "<h2>Available Permissions</h2>$table";
    }
    ($table,$error)=UserTable();
    if ($error) { 
      print "Can't display user table because: $error";
    } else {
      print "<h2>Registered Users</h2>$table";
    }
    ($table,$error)=UserPermTable();
    if ($error) { 
      print "Can't display user permission table because: $error";
    } else {
      print "<h2>Users and their permissions</h2>$table";
    }
  }
}

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
#get closing price of the stock on based on the date
sub StockExistsOnDate{
   my($date, $sym) = @_;
   my @col;
  #select count(*) from StocksDaily where date=1151470800 and symbol='GOOG'; 
  eval {@col=ExecMySQL("select count(*) from StocksDaily where date=? and symbol=?","COL",$date,$sym);};
  if ($@) {
      return (undef,$@);
  }
  else {
    return ($col[0]>0,$@);
  }
}

#get closing price of the stock on based on the date
sub GetClosingPrice{
   my($date, $sym) = @_;
   my @col;
  #select close from StocksDaily where date=1151470800 and symbol='GOOG'; 
  eval {@col=ExecMySQL("select close from StocksDaily where date=? and symbol=?","COL",$date,$sym);};
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
##############################################
#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from blog_actions"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("2D",
		     ["Perm"],
		     @rows),$@);
  }
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, email from blog_users order by name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("2D",
		     ["Name", "Email"],
		     @rows),$@);
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
       my ($strategyname, $portfoliosum)=("",0);
       my @holdingrows;

       eval { @holdingrows = ExecSQL($dbuser, $dbpasswd, "select datestamp, symbol, iinvest, quantity from holdings where id = '$pid'"); };
       if ($@) {
          return (undef,$@);
       } else {
         foreach my $holdingrow (@holdingrows) {
           my ($date, $symbol, $invest, $quantity) = @{$holdingrow};


           if($strategy eq "a"){
             $strategyname = "buy n hold";
             $portfoliosum += './shannon_ratchet.pl $symbol $invest 0 $date';
           }

           elsif ($strategy eq "b") {
	     $portfoliosum += './shannon_ratchet.pl $symbol $invest 0 $date';
             $strategyname = "shannon ratchet";
           }
           elsif($strategy eq "c"){
             $strategyname = "markov model";
           }
         } 
       } 
       $out.="<tr><td><a href = \"portfolio.pl?act=portfoliosummary&pid=$pid&strategy=$strategy\">$name</a></td><td>$cash</td><td>$strategyname</td><td>$portfoliosum</td></tr>";
    }
    $out.="</table>";
    return $out;
  }
}


sub StocksTable {
  my($pid, $strategy) = @_;
  my @rows;
  my $out = "";
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select datestamp, symbol, iinvest, quantity from holdings where id = '$pid'"); };
  if ($@) {
    return (undef,$@);
  } else {
    $out.="<table border><tr><td>STOCK</td><td>DATE PURCHASED</td><td>INITIAL INVESTMENT</td><td>INITIAL QUANTITY</td><td>CURRENT VALUE</td></tr>";

    foreach my $row (@rows) {
       my ($date, $symbol, $invest, $quantity) = @{$row};
       my $stocksum = 0;
           if($strategy eq "a"){
             $stocksum = './shannon_ratchet.pl $symbol $invest 0 $date';
           }

           elsif ($strategy eq "b") {
	     $stocksum = './shannon_ratchet.pl $symbol $invest 0 $date';
           }
           elsif($strategy eq "c"){
           }
       $out.="<tr><td><a href = \"uploadandplot.pl?symbol=$symbol&pid=$pid\">$symbol</a></td><td>$date</td><td>$invest</td><td>$quantity</td><td>$stocksum</td></tr>";
    }
    $out.="</table>";
    $out.="<h3><a href=\"portfolio.pl?act=buy&pid=$pid\">Buy Stock</a></h3>";
    return $out;
  }
}
#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select blog_users.name, blog_permissions.action from blog_users, blog_permissions where blog_users.name=blog_permissions.name order by blog_users.name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("2D",
		     ["Name", "Permission"],
		     @rows),$@);
  }
}

#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
# 
# UserAdd($name,$password,$email)
#
sub UserAdd { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into blog_users (name,password,email) values (?,?,?)",undef,@_);};
  
  return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
# 
sub UserDel { 
  eval {ExecSQL($dbuser,$dbpasswd,"delete from blog_users where name=?", undef, @_);};
  return $@;
}


#
# Give a user a permission
#
# returns false on success, error string on failure.
# 
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into blog_permissions (name,action) values (?,?)",undef,@_);};
  return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
# 
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "delete from blog_permissions where name=? and action=?",undef,@_);};
  return $@;
}

#
#
# Check to see if user and password combination exist
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
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
  my ($user,$action)=@_;
  my @col;
  eval {@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from blog_permissions where name=? and action=?","COL",$user,$action);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}




#
# Post a message
#
# returns false if success, error string if failed.
#
# Post($respid, $author, $subject, $text);
#
# $respid => "response id", the id of the message to which you are responding.
#            zero if you are not responding to a message
# $author, $subject, $text => self-explanatory
#
sub Post { 
  my ($respid,$author, $subject, $text) = @_;

#
# this idiom, eval and then $@, is an exception handling trick in perl
# even if ExecSQL dies, the eval will succeed.  At the end of the 
# eval, $@ will either be false or will contain the string with which
# die was called.
#
  eval { ExecSQL($dbuser,$dbpasswd,"insert into blog_messages (id,respid,author,subject,time,text) ".
		 "select blog_message_id.nextval, ?, ?, ?, ?, ? from dual",
		undef, $respid, $author, $subject, time(), $text); };
  return $@ ;
}


#
# Generate a summary of messages (a table of all messages in the system)
# You will extend this to support showing a tree of messages and also
# within other constraints
#
# ($table,$error) = MessageSummary();
#
sub MessageSummary {
  my @rows;
  eval { @rows = ExecSQL($dbuser,$dbpasswd,
                         "select author,subject,time from blog_messages where id<>0 order by time");};
  if ($@) { 
    return (undef,$@);
  } else {
    # Convert time values to pretty printed version
    foreach my $r (@rows) {
      $r->[2]=localtime($r->[2]);
    }
    return (MakeTable("2D", ["Author","Subject","Time"],@rows),$@);
  }
}

#
# Generate a list of messages that match the criteria 
# Currently, this is ignores the criteria and shows all messages
# You will fix this.
#
# ($html,$error) = MessageQuery($from,$to,$by)
#
sub MessageQuery {
  my ($from, $to, $by) = @_;
  
  my $timefrom=parsedate($from);
  my $timeto=parsedate($to);

  my @msgs;
  eval {@msgs=ExecSQL($dbuser,$dbpasswd,"select id, respid, author, subject, time, text from blog_messages where id<>0 order by time");};
  if ($@) { 
    return (undef,$@);
  } else {
    my $msg;
    my $out="";
    $out.="<h3>Messages from $timefrom to $timeto by '$by'<h3>";
    if ($msg<0) { 
      $out.="There are no messages";
    }
    foreach $msg (@msgs) { 
      my ($id, $respid, $author, $subject, $time, $text) = @{$msg};
      $out.="<table border><tr><td><b>id:</b></td><td>$id</td><td><b>respid:</b></td><td>$respid</td><td><b>Time:</b></td><td>".localtime($time)."</td></tr>";
      $out.="<tr><td><b>author:</b></td><td colspan=5>$author</td></tr>";
      $out.="<tr><td><b>subject:</b></td><td colspan=5>$subject</td></tr>";
      $out.="<tr><td colspan=6>$text</td></tr>";
      $out.="</table>";
    }
    return ($out,$@);
  }
}

#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($type, $headerlistref,@list);
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


