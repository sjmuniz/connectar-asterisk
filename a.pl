#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use POSIX qw(strftime);
use DBI;
use DBD::mysql;


sub dnis_iplan {
  my ($modalidad, $indicativo, $bloque, $tel) = @_;

  return "666803#54$indicativo".($modalidad eq 'CPP' ? '15' : '')."$bloque$tel";
}

sub dnis_anton {
  my ($modalidad, $indicativo, $bloque, $tel) = @_;

  return "226654".($modalidad eq 'CPP' ? '9' : '')."$indicativo$bloque$tel";
}

sub dnis_berazategui {
  my ($modalidad, $indicativo, $bloque, $tel) = @_;

  return "0054$indicativo".($modalidad eq 'CPP' ? '15' : '')."$bloque$tel";
}


my $dbh = DBI->connect('DBI:mysql:multifon', 'multifon', 'soruco');

my $dnis = "386815452950";

        my @q = ();
        foreach my $l (2..7) {
          push @q, "(len=$l and pref='".substr($dnis, 0, length($dnis)-$l)."')";
        }

        my $q_ = join(" or ", @q);
        my $q_2 = $q_;
        $q_2 =~ s/pref/pref2/g;

        my ($modalidad, $indicativo, $bloque, $len, $localidad) = $dbh->selectrow_array("select modalidad, indicativo, bloque, len, localidad from prefijos where $q_ or $q_2");

        my $ruta = $dbh->selectcol_arrayref("select ruta from rutas where localidad=".$dbh->quote($localidad)." and modalidad=".$dbh->quote($modalidad)." order by rand()");

	print Dumper($ruta);

	my @rutas = map { {ruta => $_, localidad => $localidad, modalidad => $modalidad, out_dnis => 
         $_ eq "iplan" ? dnis_iplan($modalidad, $indicativo, $bloque, substr($dnis, length($dnis)-$len)) :
         $_ eq "anton" ? dnis_anton($modalidad, $indicativo, $bloque, substr($dnis, length($dnis)-$len)) :
         $_ eq "berazategui" ? dnis_berazategui($modalidad, $indicativo, $bloque, substr($dnis, length($dnis)-$len)) :
          "" } } @$ruta;

	print Dumper( \@rutas )
