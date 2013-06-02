use strict;
use warnings;
use Test::Simple;
use slha;

sub dcmp{
  my ($a, $b) = @_;
  return ($a*$b == 0) ? ($a + $b == 0) : (abs($a-$b) < 0.00000001 * (abs($a)+abs($b)));
}

my @list = <DATA>;
my $slha = new_from_list SLHA @list;

print "---------------------------------------- ONE ARGUMENT BLOCK\n";
ok($slha->v('oneargblock', 1) ==  10);
ok($slha->v('OneArgBlock', 2) == -20);
ok($slha->v('ONEARGBLOCK', 3) ==   0);

ok(!defined($slha->v('OneArGBLOCK', 10)));

ok(dcmp($slha->v('ONEARGBLOCK', 11),  -1522.2 ));
ok(dcmp($slha->v('ONEARGBLOCK', 12),    250 ));
ok(dcmp($slha->v('ONEARGBLOCK', 13),  0.02  ));
ok(dcmp($slha->v('ONEARGBLOCK', 14), -0.003 ));

print "---------------------------------------- ZERO ARGUMENT BLOCK\n";

ok(dcmp($slha->v('NOARGBLOCKA'), 3.1415926535));
ok($slha->v('NOARGBLOCKB') == 0);

print "---------------------------------------- TWO ARGUMENT BLOCK\n";

foreach my $i(1..2){
  foreach my $j(1..2){
    ok($slha->v('doubleargblock', $i, $j) == $i*$j);
  }
}

print "---------------------------------------- UNUSUAL BLOCK\n";
ok($slha->v('unusualcase', 1) eq 'some calculator returns');
ok($slha->v('unusualcase', 2) eq 'these kind of error messages');
ok($slha->v('unusualcase', 3) eq 'which of course is not expected in slha format.');


print "---------------------------------------- BLOCK Q\n";
ok(dcmp($slha->Q('NOARGBLOCKA'), 123456.789));
ok(dcmp($slha->Q('NOARGBLOCKB'), 123456.789));

print "---------------------------------------- Decay Rates\n";
ok(dcmp($slha->d(      6),  1.45899677));
ok(dcmp($slha->d(1000021), 13.4988503 ));
ok(dcmp($slha->d(1000005), 10.7363639 ));

print "---------------------------------------- Branching Ratio (1)\n";
ok(dcmp($slha->br(6,5,24), 1.000000000 ));
ok(dcmp($slha->br(6,24,5), 1.000000000 ));

print "---------------------------------------- Branching Ratio (2)\n";
ok(dcmp($slha->br(1000021,  1000001, -1), 0.0217368689));
ok(dcmp($slha->br(1000021, -1000001,  1), 0.0217368689));

print "---------------------------------------- Branching Ratio (3)\n";
ok(dcmp($slha->br(1000005,  1000022,  5), 0.0259311849));
ok(dcmp($slha->br(1000005,  1000023,  5), 0.216401445));
ok(dcmp($slha->br(1000005,  1000025,  5), 0.0159051554));
ok(dcmp($slha->br(1000005,  1000035,  5), 0.0127036617));

print "---------------------------------------- Branching Ratio (4)\n";
ok(dcmp($slha->br(1000005,  1, -2, -3),          0.378818883));
ok(dcmp($slha->br(1000005,  1, -2, -3, 4),       0.378818883));
ok(dcmp($slha->br(1000005,  1, -2, -3, 4, 5),    0.378818883));
ok(dcmp($slha->br(1000005,  1, -2, -3, 4, 5, 6), 0.378818883));

print "---------------------------------------- Decay List\n";
ok(@{$slha->dlist(      6)} == 1);
ok(@{$slha->dlist(1000021)} == 2);
ok(@{$slha->dlist(1000005)} == 8);

print "---------------------------------------- Manipulate (1)\n";
$slha->set_param('ONEARGBLOCK', 8, 300);
$slha->set_param('ONEARGBLOCK', 1, -4.01031);
ok($slha->v('ONEARGBlock', 8) == 300);
ok(dcmp($slha->v('ONEARGBlock', 1), -4.01031));

$slha->set_param('DoubleARGBLOCK', 2, 1, 4);
$slha->set_param('DoubleARGBLOCK', 2, 2, 9);
$slha->set_param('DoubleARGBLOCK', 2, 3, 16);
ok($slha->v('doubleARGBlock', 2, 1) == 4);
ok($slha->v('doubleARGBlock', 2, 2) == 9);
ok($slha->v('doubleARGBlock', 2, 3) == 16);

$slha->set_param('Noargblocka', -100);
ok(dcmp($slha->v('NOARGBlockA'), -100));

$slha->set_param('NewBlock', 6, 7, 10);
ok($slha->v('newblock', 6, 7) == 10);

print "---------------------------------------- Manipulate (2)\n";

$slha->set_Q('NoArgBlockA', 20);
$slha->set_Q('oneArgBlock', 22);
ok($slha->Q('NoArgBlockA') == 20);
ok($slha->Q('oneargBlock') == 22);


print "---------------------------------------- Manipulate (3)\n";
$slha->remove_param('oneargblock', 1);
ok(!defined($slha->v('OneaRGBLOCK', 1)));
ok(!defined($slha->{data}->{ONEARGBLOCK}->{1}));

$slha->remove_param('doubleargblock', 2,1);
ok(!defined($slha->v('DOUBLEARGBLOCK', 2, 1)));
ok(!defined($slha->{data}->{DOUBLEARGBLOCK}->{"2 1"}));

$slha->remove_param('NoArgBlockA');
ok(!defined($slha->{data}->{NOARGBLOCKA}));


print "---------------------------------------- Modify Decay block (1)\n";
$slha->set_decay_rate(6, 1.2345);
ok(dcmp($slha->d(      6),  1.2345));
ok(dcmp($slha->d(1000005), 10.7363639 ));     # unchanged

ok(dcmp($slha->br(6,5,24), 1.000000000 ));    # unchanged
ok(dcmp($slha->br(6,24,5), 1.000000000 ));    # unchanged

ok(dcmp($slha->br(1000021,  1000001, -1), 0.0217368689)); # unchanged
ok(dcmp($slha->br(1000021, -1000001,  1), 0.0217368689)); # unchanged

print "---------------------------------------- Modify Decay block (2)\n";
$slha->clear_decay_channels(6);
ok(dcmp($slha->d(      6),  1.2345));
ok(dcmp($slha->br(6,5,24), 0));
ok(@{$slha->dlist(      6)} == 0);

ok(@{$slha->dlist(1000021)} == 2); #unchanged

$slha->add_decay_channel(6, 1, 3, 24); # 100% to 3 and 24
ok(@{$slha->dlist(      6)} == 1);
ok(dcmp($slha->br(6,24,3), 1));
ok(dcmp($slha->br(6,24,5), 0));
ok(dcmp($slha->br(6,3,24), 1));
ok(dcmp($slha->br(6,5,24), 0));

print "---------------------------------------- Modify Decay block (3)\n";
$slha->clear_decay_channels(6);
$slha->add_decay_channel(6, 0.99, 5, 24); # 99% to 5 and 24
$slha->add_decay_channel(6, 0.01, 1, 24); #  1% to 1 and 24
ok(@{$slha->dlist(      6)} == 2);
ok(dcmp($slha->br(6,24,1), 0.01));
ok(dcmp($slha->br(6,5,24), 0.99));

ok(dcmp($slha->br(1000021,  1000001, -1), 0.0217368689)); # unchanged
ok(dcmp($slha->br(1000021, -1000001,  1), 0.0217368689)); # unchanged

print "---------------------------------------- Modify Decay block (4)\n";
$slha->set_decay_rate(123, 2.4);
$slha->add_decay_channel(123, 0.5, -1, -2, -3, -4, -5);
$slha->add_decay_channel(123, 0.5, 1, 2, 3, 4, 5, 6, 7);
ok(@{$slha->dlist(123)} == 2);
ok(dcmp($slha->br(123,2,4,6,1,3,5,7), 0.5));

print "---------------------------------------- Copy\n";
my $copy = $slha->copy();
$copy->remove_block('doubleargblock');
ok(defined($slha->{data}->{DOUBLEARGBLOCK}));
ok(!defined($copy->{data}->{DOUBLEARGBLOCK}));

$copy->set_param('NewBlock', 6, 7, 2000);
ok($slha->v('newblock', 6, 7) == 10);
ok($copy->v('newblock', 6, 7) == 2000);

print "---------------------------------------- Write\n";
foreach($slha->write([qw/NewBlock NotExistingBlock/])){print;}

__END__

# TEST TARGET SLHA
#

BLOCK     ONEARGBLOCK    # COMMENT
     1     10    # one
     2    -20    # two
     3      0    # three

#   10     20    # comment

    11   -1.5222e+3 ###      
    12   +2.5E+2
    13   +2.0d-2 #### FORTRAN DOUBLE   
    14   -3.0D-3            

BLOCK     NOARGBLOCKA  Q = 123456.789
    3.1415926535

BLOCK     NOARGBLOCKB  Q = 123456.789
    0

BLOCK   doubleArgBlock
   1  1      1
   1  2      2
   2  1      2
   2  2      4

BLOCK unusualcase
   1    some calculator returns # hogehoge
   2    these kind of error messages # hogehoge
   3    which of course is not expected in slha format.

#
#         PDG            Width
DECAY         6     1.45899677E+00   # top decays
#          BR         NDA      ID1       ID2
     1.00000000E+00    2           5        24   # BR(t ->  b    W+)
#
#         PDG            Width
DECAY   1000021     1.34988503E+01   # gluino decays
#          BR         NDA      ID1       ID2
     2.17368689E-02    2     1000001        -1   # BR(~g -> ~d_L  db)
     2.17368689E-02    2    -1000001         1   # BR(~g -> ~d_L* d )
#
DECAY   1000005     1.07363639E+01   # sbottom1 decays
#          BR         NDA      ID1       ID2
     2.59311849E-02    2     1000022         5   # BR(~b_1 -> ~chi_10 b )
     2.16401445E-01    2     1000023         5   # BR(~b_1 -> ~chi_20 b )
     1.59051554E-02    2     1000025         5   # BR(~b_1 -> ~chi_30 b )
     1.27036617E-02    2     1000035         5   # BR(~b_1 -> ~chi_40 b )

     3.78818883E-01    3     1 -2 -3         # artifitial multibody
     3.78818883E-01    4     1 -2 -3 4       # artifitial multibody
     3.78818883E-01    5     1 -2 -3 4 5     # artifitial multibody
     3.78818883E-01    6     1 -2 -3 4 5 6   # artifitial multibody
#
