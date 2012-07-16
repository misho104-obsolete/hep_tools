#!/usr/bin/perl

use strict;
use warnings;
use slha;

my $slha = new_from_stdin SLHA;
foreach ('AU', 'AD', 'AE'){
  $slha->remove_param($_, 1, 1);
  $slha->remove_param($_, 2, 2);
}
foreach($slha->write()){ print; }
exit 0;
