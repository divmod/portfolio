#!/usr/bin/perl -w

use CGI qw(:standard);
use Time::ParseDate;
use Time::CTime;
use Getopt::Long;

my $cgi = new CGI();

print "Cache-Control: no-cache\n";
print "Expires: Thu, 13 Mar 2003 07:12:13 GMT\n";  # ie, a long time ago
print "Content-Type: text/html\n\n";

$ENV{ORACLE_HOME}="/opt/oracle/product/11.2.0/db_1";
$ENV{ORACLE_BASE}="/opt/oracle/product/11.2.0";
$ENV{ORACLE_SID}="CS339";


my $symbol = param('symbol');
$model = "AR";
#$#ARGV>=2 or die "usage: time_series_symbol_project.pl symbol date steps-ahead model \n";
print start_form(-name=>'StockPredict'),
      h2('Get Prediction Data for Stock ', $symbol),
      "To Date (mm/dd/yyyy): ", textfield(-name=>'todate',default=>'06/30/2006'),p,
	"Time Interval Ago: ",
	radio_group(-name=>'period', -values=>['Day','Week','Month','Quarter'], -default=>'Day'),
	p,
	"Choose order of polynomial for AR prediction",
	p,
	popup_menu(-name=>'polynomial', -values=>['1', '2', '3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20']),
	p,
	hidden(-name=>'postrun',-default=>['1']),
	hidden(-name=>'symbol',-default=>['$symbol']),
	submit,
	end_form;

if (param('postrun')) {
	my $symbol = param('symbol');
	my $period = param('period');
	my $polynomial = param('polynomial');
	my $enddate = param('todate')." 00:00:00 GMT";

	if ($period eq 'Day') {
		$steps = 1;
	}
	elsif ($period eq 'Week') {
		$steps = 7;
	}
	elsif ($period eq 'Quarter') {
		$steps = 90;
	}
	elsif ($period eq 'Month') {
		$steps = 30;
	}


	my $to = parsedate($enddate);

	system "./predict.pl $symbol $to $steps $model $polynomial"; 

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

