#!/usr/bin/perl

use strict;
use warnings;
use hep_tools::slha::slha;

# ------ TINY TOOLS ------------------------------------------------------------
our $EPSILON = 0.0001;
sub equ { $_[0]&&$_[1] ? abs($_[0] - $_[1]) <= $EPSILON * ($_[0]||$_[1]) : $_[0]||$_[1] == 0; };
sub eq0 { $_[0]==0; }

sub has_block {
  my ($slha, $block) = @_;
  foreach($slha->block_list()){
    return 1 if uc($block) eq $_;
  }
  return 0;
}
sub has_key {
  my ($slha, $block, @key) = @_;
  return defined($slha->v($block, @key));
}

# ------ MAIN ------------------------------------------------------------------
our (@error, @warn, @info);

my $slha = new_from_stdin SLHA;


# SURVEY
assert_sfermion_mixing($slha, 'stopmix', 'usqmix');
assert_sfermion_mixing($slha, 'sbotmix', 'dsqmix');
assert_sfermion_mixing($slha, 'staumix', 'selmix');

assert_aterm($slha, 'au', 'tu');
assert_aterm($slha, 'ad', 'td');
assert_aterm($slha, 'ae', 'te');

assert_diagonal_block($slha, 'vckm');
assert_diagonal_block($slha, 'snumix');
assert_diagonal_block($slha, 'upmns');

assert_alpha_block($slha);

if(@error > 0){
  print STDERR "\n";
  foreach(@error) { print STDERR "[ERROR] $_\n"; }
  exit 1;
}

foreach($slha->write()){ print; }

if(@warn > 0){
  print STDERR "\n";
  foreach(@warn) { print STDERR "[WARNING] $_\n"; }
}else{
  print STDERR "\nConsistent param card.";
}
exit 0;


sub assert_sfermion_mixing{
  my($slha, $pythia, $ufo) = @_;
  $pythia = uc($pythia);
  $ufo    = uc($ufo);

  # Input SLHA must
  #     - have STOPMIX/SBOTMIX/STAUMIX.
  #     - not have USQMIX/DSQMIX/SELMIX.

  my @third_ufo = ();
  my @third_pythia = ();

  if(has_block($slha, $ufo)){
    for my $i(1..6){
      for my $j(1..6){
        if($i%3 != 0 or $j%3 != 0){
          my $value = $slha->v($ufo, $i, $j);
          next unless defined($value);
          my $shouldbe = $i==$j ? 1 : 0;
          if(!equ($shouldbe, $value)){
            push @error, "Block [$ufo] has invalid component ($i,$j) which should be $shouldbe.";
          }
        }else{ # 3rd gen.
          if(defined($slha->v($ufo, $i, $j))){
            push(@third_ufo, $slha->v($ufo, $i, $j));
          }
        }
      }
    }
  }
  if(has_block($slha, $pythia)){
    for my $i(1..2){
      for my $j(1..2){
        if(defined($slha->v($pythia, $i, $j))){
          push(@third_pythia, $slha->v($pythia, $i, $j));
        }
      }
    }
  }

  if(@third_pythia == 0 && @third_ufo == 0){
    push @error, "Block [$pythia] is not specified.";
  }elsif(@third_pythia == 4 && @third_ufo == 0){
    # ideal case.
  }elsif(@third_pythia == 4 && @third_ufo == 4){
    foreach(0..3){
      if(!equ($third_pythia[$_], $third_ufo[$_])){
        push @error, "Block [$pythia] is inconsistent with Block [$ufo].";
        last;
      }
    }
    push @warn, "Block [$ufo] is consistent with Block [$pythia], and thus removed.";
    $slha->remove_block($ufo);
  }else{
    push @warn, "Block [$ufo] 3-gen. components to be converted to [$pythia] block.";
    for my $i(1..2){
      for my $j(1..2){
        $slha->set_param($pythia, $i, $j, $slha->v($ufo, $i*3, $j*3));
        $slha->set_comment($pythia, $i, $j, "CONVERTED FROM $ufo BLOCK");
      }
    }
    $slha->remove_block($ufo);
  }
}

sub assert_aterm{
  my($slha, $pythia, $ufo) = @_;

  # Input SLHA must
  #     - have AU/AD/AE(3,3)
  #     - not have other AU/AD/AE nor TU/TD/TE.

  $pythia = uc($pythia);
  $ufo    = uc($ufo);

  die if $pythia !~ /^A([UDE])$/;
  my $label = $1;
  die if $ufo !~ /^T$label$/;

  my ($org_a33, $converted_a33);
  my $yukawa = 0;

  if(has_block($slha, $ufo)){
    for(my $i=1; $i<4; $i++){
      for(my $j=1; $j<4; $j++){
        my $value = $slha->v($ufo, $i, $j); # might be undef.
        next unless defined($value);
        if($i == 3 and $j == 3){
          $yukawa = $slha->v("Y$label", 3, 3);
          if(defined($yukawa) and $yukawa > 0){
            push @warn, "Block [$ufo] (3,3) components are converted to [$pythia] with Yukawa $yukawa.";
            $converted_a33 = $value / $yukawa;
          }else{
            push @error, "Block [$ufo] (3,3) exists but Block [Y$label] (3,3) is invalid.";
          }
        }else{
          if(!eq0($value)){
            push @error, "Block [$ufo] is invalid; all but (3,3) must be zero.";
            ($i, $j) = (3,2); # go to (3,3).
          }
        }
      }
    }
    $slha->remove_block($ufo);
  }

  if(has_block($slha, $pythia)){
    my $flag = 0;
    for (my $i = 1; $i <= 3; $i++){
      for (my $j = 1; $j <= 3; $j++){
        my $value = $slha->v($pythia, $i, $j); # might be undef.
        next unless defined($value);
        if($i == 3 and $j == 3){
          $org_a33 = $value;
        }
        else{
          if(!eq0($value)){
            push @error, "Block [$pythia] is invalid; all but (3,3) must be zero.";
            ($i, $j) = (3,2); # go to (3,3).
          }else{
            $slha->remove_param($pythia, $i, $j);
            $flag = 1;
          }
        }
      }
    }
    if($flag){
      push @warn, "Block [$pythia] 1,2-gen components, which are zero, are removed.";
    }
  }
  if(defined($org_a33) and defined($converted_a33)){
    if(equ($org_a33, $converted_a33)){
      # consistent; block are already removed. nothing to do.
    }else{
      push @error, "Block [$pythia] is inconsistent with Block [$ufo].";
    }
  }elsif(defined($converted_a33)){
    $slha->set_param($pythia, 3, 3, $converted_a33);
    $slha->set_comment($pythia, 3, 3, "CONVERTED FROM $ufo BLOCK with Yukawa $yukawa");
  }elsif(!defined($org_a33)){
    push @error, "Block [$pythia] (3,3) component is not found.";
  }
}

sub assert_diagonal_block{
  my ($slha, $block) = @_;
  my $flag = 0;
  if(has_block($slha, $block)){
    for my $i(1..3){
      for my $j(1..3){
        my $value = $slha->v($block, $i, $j); # might be undef.
        next unless defined($value);
        if(equ($value, $i==$j ? 1 : 0)){
          $flag = 1;
        }else{
          push @error, "Block [$block] is invalid; all but (3,3) must be zero.";
        }
      }
    }
  }
  if($flag == 1){
    push @warn, "Block [$block], which is diagonal, is removed.";
    $slha->remove_block($block);
  }
}

sub assert_alpha_block{
  my ($slha) = @_;
  my ($ufo, $pythia) = ('FRALPHA', 'ALPHA');

  my $fr    = has_block($slha, $ufo) ? $slha->v($ufo, 1) : undef;
  my $alpha = $slha->v($pythia);

  if(defined($fr)){
    if(defined($alpha)){
      unless(equ($fr, $alpha)){
        push @error, "Block [$ufo] is inconsistent with Block [$pythia].";
      }
    }else{
      push @warn, "Block [$ufo] is converted to [$pythia].";
      $slha->set_param($pythia, $fr);
      $slha->set_comment($pythia, "CONVERTED FROM Block $ufo");
    }
    push @warn, "Block [$ufo] is removed.";
    $slha->remove_block($ufo);
  }else{
    if(defined($alpha)){
      # ideal case.
    }else{
      push @error, "Block [$pythia] is not found.";
    }
  }
}

__END__
DECAY  6  1.56194983e+00  # WT
DECAY  11  0.00000000e+00  # We
DECAY  12  0.00000000e+00  # Wve
DECAY  13  1.10000000e+00  # Wmu
DECAY  14  0.00000000e+00  # Wvmu
DECAY  15  1.10000000e+00  # Wtau
DECAY  16  0.00000000e+00  # Wvt
DECAY  23  2.41143316e+00  # WZ
DECAY  24  2.00282196e+00  # WW
DECAY  25  1.98610799e-03  # Wh0
DECAY  35  5.74801389e-01  # WH0
DECAY  36  6.32178488e-01  # WA0
DECAY  37  5.46962813e-01  # WH
DECAY  1000001  5.31278772e+00  # Wdsq1
DECAY  1000002  5.47719539e+00  # Wusq1
DECAY  1000003  5.31278772e+00  # Wdsq2
DECAY  1000004  5.47719539e+00  # Wusq2
DECAY  1000005  3.73627601e+00  # Wdsq3
DECAY  1000006  2.02159578e+00  # Wusq3
DECAY  1000011  2.13682161e-01  # Wsl1
DECAY  1000012  1.49881634e-01  # Wsn1
DECAY  1000013  2.13682161e-01  # Wsl2
DECAY  1000014  1.49881634e-01  # Wsn2
DECAY  1000015  1.48327268e-01  # Wsl3
DECAY  1000016  1.47518977e-01  # Wsn3
DECAY  1000021  5.50675438e+00  # Wglu
DECAY  1000022  1.10000000e+00  # Wneu1
DECAY  1000023  2.07770048e-02  # Wneu2
DECAY  1000024  1.70414503e-02  # Wch1
DECAY  1000025  1.91598495e+00  # Wneu3
DECAY  1000035  2.58585079e+00  # Wneu4
DECAY  1000037  2.48689510e+00  # Wch2
DECAY  2000001  2.85812308e-01  # Wdsq4
DECAY  2000002  1.15297292e+00  # Wusq4
DECAY  2000003  2.85812308e-01  # Wdsq5
DECAY  2000004  1.15297292e+00  # Wusq5
DECAY  2000005  8.01566294e-01  # Wdsq6
DECAY  2000006  7.37313275e+00  # Wusq6
DECAY  2000011  2.16121626e-01  # Wsl4
DECAY  2000013  2.16121626e-01  # Wsl5
DECAY  2000015  2.69906096e-01  # Wsl6
