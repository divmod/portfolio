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

#print "<head><title>Upload File and Plot</title></head>";

#my $file = $cgi->param("uploadedfile");
#my $file = "plot.dat";
my $pid = param('pid');
my $fromdate = param('fromdate');
my $symbol = param('symbol');

print start_form(-name=>'StockHistory'),
			h2('Get Historical Data for Stock ', $symbol),
#	"To Date (mm/dd/yyyy): ", textfield(-name=>'mm',-size=>'2',-default=>'06'),"/",
#	textfield(-name=>'dd',-size=>'2',-default=>'30'),"/",textfield(-name=>'yyyy',-size=>'4',-default=>'2006'),p,

			"To Date (mm/dd/yyyy): ", textfield(-name=>'todate',default=>'06/30/2006'),p,

			"Time Interval Ago: ", 
			radio_group(-name=>'period', -values=>['Day','Week','Month','Quarter','Year', '5 Years'], -default=>'Day'),
			p,
			hidden(-name=>'postrun',-default=>['1']),
			hidden(-name=>'symbol',-default=>['$symbol']),
			submit,
			end_form;

if (param('postrun')) {
	my $symbol = param('symbol');
	my $period = param('period');
	my $enddate = param('todate').' 05:00:00 GMT';
	my $fromdate;
	my $todate = parsedate($enddate);

	if ($period eq 'Day') {
		$fromdate = parsedate($enddate) - (24 * 60 * 60);
	}
	elsif ($period eq 'Week') {
		$fromdate = parsedate($enddate) - (7 * 24 * 60 * 60);
	}
	elsif ($period eq 'Quarter') {
		$fromdate = parsedate($enddate) - (90 * 24 * 60 * 60);
	}
	elsif ($period eq 'Month') {
		$fromdate = parsedate($enddate) - (30 * 24 * 60 * 60);
	}
	elsif ($period eq 'Year') {
		$fromdate = parsedate($enddate) - (365 * 24 * 60 * 60);
	}
	elsif ($period eq '5 Years') {
		$fromdate = parsedate($enddate) - (5 * 365 * 24 * 60 * 60) + 1;
	}

	my @results =	`./get_data.pl --from='$fromdate' --to='$todate' --close --plot $symbol`;

	print @results;

#	`./get_data.pl --close $symbol --plot`;
#	system("/usr/bin/perl 'get_data.pl --close $symbol --plot'");
#	system './get_data.pl --close $symbol --plot';
#	open(my $STOCK, "./get_data.pl --close $symbol --plot |");

	GraphAndPrint('_plot.in');

	print $cgi->end_html();

	exit;

}

sub GraphAndPrint
{
	my ($name) = @_;
	my ($graphfile)="$name.png";

	print "<b>Graph</b><p><img src =\"" . GnuPlot($name,$graphfile) ."\"><p>\n";

	print "<b>Data</b><p><pre>";
	print "Unix Time\tPrice Per Unit\n";
	open (FILE,$name);
	while (<FILE>) { 
		print $_;
	}
	close(FILE);
	print "</pre>";
}


sub GnuPlot
{

	my ($datafile, $outputfile)=@_;

	open(GNUPLOT,"|gnuplot");
	print GNUPLOT "set terminal png\n";
	print GNUPLOT "set output \"$outputfile\"\n";
	print GNUPLOT "set xdata time\n";
	print GNUPLOT "set timefmt \"%s\"\n";
	print GNUPLOT "set format x \"%m/%d/%y\"\n";
	print GNUPLOT "set xlabel 'Date'\n";
	print GNUPLOT "set ylabel 'Price Per Unit'\n";
	print GNUPLOT "plot \"$datafile\" using 1:2 with linespoints\n";
	close(GNUPLOT);
	return $outputfile;
}


