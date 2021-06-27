#!/usr/bin/perl -w

use strict;
use Asterisk::AGI;
use Data::Dumper;
use POSIX qw(strftime);
use DBI;
use DBD::mysql;


my $dbh = DBI->connect('DBI:mysql:multifon', 'multifon', 'soruco');

my $AGI = new Asterisk::AGI;
my %input = $AGI->ReadParse();

open (LOG, '>>', '/tmp/astgk.txt');
select((select(LOG), $| = 1)[0]);
*STDERR = *LOG;

my $srcep = $AGI->get_full_variable('${CHANNEL(peername)}');
my $in_id = $input{uniqueid};
my $in_ani = $input{callerid};
my $in_dnis = $input{extension};

discar($in_dnis);

sub debug {
  print LOG "$in_id ",strftime("%Y%m%d%H%M%S", localtime())," ",@_,"\n";
}

sub dnis_iplan {
  my ($modalidad, $indicativo, $bloque, $tel) = @_;
  
  return "666803#54$indicativo".($modalidad eq 'CPP' ? '15' : '')."$bloque$tel";
}

sub dnis_anton {
  my ($modalidad, $indicativo, $bloque, $tel) = @_;

  return "226654".($modalidad eq 'CPP' ? '9' : '')."$indicativo$bloque$tel";
}

sub discar {
	my $dnis = shift;

        if ($dnis =~ /^549?(15)?(........)$/) {
          $dnis = "11$2";
        } elsif ($dnis =~ /^(00)?549?(.*)$/) {
          $dnis = $2;
        } elsif ($dnis =~ /^00/) {
          return "INVALIDO (LDI)";
        } elsif ($dnis =~ /^0(.*)/) {
          $dnis = $1;
        } elsif ($dnis =~ /^54(..........)$/) {
          $dnis = $1;
        } elsif ($dnis =~ /15/ && $dnis =~ /^54(............)$/) {
          $dnis = $1;
        } elsif ($dnis =~ /^........$/ || $dnis =~ /^15........$/) {
          $dnis = "11$dnis";
        }

        my @q = ();
        foreach my $l (2..7) {
          push @q, "(len=$l and pref='".substr($dnis, 0, length($dnis)-$l)."')";
        }

	my $q_ = join(" or ", @q);
	my $q_2 = $q_;
	$q_2 =~ s/pref/pref2/g;

	my ($modalidad, $indicativo, $bloque, $len, $localidad) = $dbh->selectrow_array("select modalidad, indicativo, bloque, len, localidad from prefijos where $q_ or $q_2");

        unless ($modalidad) {
        	debug( "Llamada <$in_id> de <$in_ani> a <$in_dnis>: INVALIDO" );
		$AGI->exec('Hangup', 1);
		return;
        }

	my ($ruta) = $dbh->selectrow_array("select ruta from rutas where localidad=".$dbh->quote($localidad)." and modalidad=".$dbh->quote($modalidad)." order by rand() limit 1");

	my $out_dnis =
	 $ruta eq "iplan" ? dnis_iplan($modalidad, $indicativo, $bloque, substr($dnis, length($dnis)-$len)) :
	 $ruta eq "anton" ? dnis_anton($modalidad, $indicativo, $bloque, substr($dnis, length($dnis)-$len)) :
	  "";

        debug( "Llamada <$in_id> de <$in_ani> a <$in_dnis> (<$localidad: $modalidad>) -> $ruta <$out_dnis>");

	if ($out_dnis) {
        	$AGI->exec('Dial', "SIP/$out_dnis\@$ruta");
		debug( "Fin llamada <$in_id>" );
	} else {
		$AGI->exec('Hangup', 1);
	}
}

