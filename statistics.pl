#!/usr/bin/perl -w

use strict;
use CGI qw(:standard);
use URI::Escape;
use Time::ParseDate;
use Time::CTime;

my $cgi = new CGI();

print "Cache-Control: no-cache\n";
print "Expires: Thu, 13 Mar 2003 07:12:13 GMT\n";  # ie, a long time ago
print "Content-Type: text/html\n\n";


print "<head><title>Show Statistical Analysis of Symbol</title></head>";

#my $file = $cgi->param("uploadedfile");
#my $file = "plot.dat";
#my $pid = param('pid');
#my $fromdate = param('fromdate');
my $symbol = param('symbol');

my $stat_type = param('stat_type');
print start_form(-name=>'selectstat'),
			h2('Statistical Analysis of Stock ', $symbol),
			"Select Statistic Type: ",
			radio_group(-name=>'stat_type',-values=>['Standard Deviation/Coefficient of Variation','Beta'],
					-default=>'Standard Deviation/Coefficient of Variation'),
			hidden(-name=>'symbol',-default=>['$symbol']),
			submit('typebutton','Change'),
			end_form;

if ($stat_type eq 'Beta') {

	print start_form(-name=>'analysis'),
				"From Date (mm/dd/yyyy): ", textfield(-name=>'fromdate',default=>'09/07/1984'),p,
				"To Date (mm/dd/yyyy): ", textfield(-name=>'todate',default=>'06/30/2006'),p,
				p,
				hidden(-name=>'postrun',-default=>['1']),
				hidden(-name=>'symbol',-default=>['$symbol']),
				hidden(-name=>'stat_type',-default=>['$stat_type']),
				submit('betasubmit','Submit'),
				end_form;
}
else {
	print start_form(-name=>'analysis'),
#			h2('Statistical Analysis of Stock ', $symbol),
				"From Date (mm/dd/yyyy): ", textfield(-name=>'fromdate',default=>'09/07/1984'),p,
				"To Date (mm/dd/yyyy): ", textfield(-name=>'todate',default=>'06/30/2006'),p,
				"Field Type: ", popup_menu(-name=>'field',-values=>['open','high','low','close']),p,
				p,
				hidden(-name=>'postrun',-default=>['1']),
				hidden(-name=>'symbol',-default=>['$symbol']),
				hidden(-name=>'stat_type',-default=>['$stat_type']),
				submit('submitbutton','Submit'),
				end_form;
}

if (param('postrun')) {
	my $symbol = param('symbol');
	my $period = param('period');
	my $enddate = param('todate').' 05:00:00 GMT';
	my $startdate = param('fromdate').' 05:00:00 GMT';
	my $field = param('field');
	my $stat_type = param('stat_type');

	my $i;


	if ($stat_type eq 'Beta') {
		my @beta = `./get_beta.pl --from='$startdate' --to='$enddate' $symbol`;
		print "<pre>";
		print @beta;
		print "</pre>";
	}
	else {
		my @results =	`./get_info.pl --from='$startdate' --to='$enddate' --field=$field --plot $symbol`;

		print "<pre>";
#	print @results,p;
		for ($i = 0; $i < 2; $i++) {
			print "$results[$i]";
		}
		print "</pre>";
	}
	print $cgi->end_html();

	exit;

}

