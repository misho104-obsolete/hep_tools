package SLHA;

use strict;
use integer;

# ================================================================== CONSTRUCTOR
sub _fortranparse{
  my $a = shift;
  $a =~ s/d/e/img if $a =~ /^[\d.+-]+[de][\d+-]+$/i;
  return $a;
}

sub _strip{
  $_[0] =~ s/^\s+//img;
  $_[0] =~ s/\s+$//img;
  $_[0] =~ s/\s+/ /img;
}
sub _block_key{
  my @a = @_;
  _strip($_) foreach @a;
  return (@_ == 0) ? 0 : join(" ", @_);
}
sub _parse_block_line{
  my $line = shift;
  my $decay_flag = shift;  ## within DECAY block
  my $comment = "";
  my @result = undef;
  if($line =~ /^(.*?)\s*(\#.*)$/){
    ($line, $comment) = ($1, $2);
  }
  if($line =~ /^BLOCK\s+(\w+)(\s+.*)?$/i){
    @result = ("BLOCK", $1, $2, $comment);
  }elsif($line =~ /^DECAY\s+([\d+-]+)\s+([\d+-\.de]+)(\s+.*)?$/i){
    @result = ("DECAY", $1, $2, $3, $comment);
  }else{
    _strip($line);
    my @a = split(" ", $line);
    if(!$decay_flag){
      if(@a == 0){
        @result = ();
      }elsif(@a == 1){
        @result = (0, $a[0]);
      }elsif(@a == 2){
        @result = @a;
      }else{
        if($a[1] =~ /^\d+$/){
          @result = ("$a[0] $a[1]", join(" ",@a[2..$#a]));
        }else{
          @result = ($a[0], join(" ",@a[1..$#a]));
        }
      }
    }else{
      @result = @a;
   }
  }
  return @result > 0 ? (@result, $comment) : $comment; # no result => length = 1
}


sub new {
  my $class     = shift;
  my $file_name = shift;
  die "File [$file_name] not found." unless -f $file_name;
  open(my $fh,$file_name);
  my @input = <$fh>;
  close($fh);
  return _construct($class, $file_name, @input);
}

sub new_from_stdin {
  my @input = <STDIN>;
  return _construct($_[0], '<STDIN>', @input);
}

sub new_from_list{
  my $class = shift;
  return _construct($class, '<LIST>', @_);
}

sub _construct {
  my $class     = shift;
  my $file_name = shift;
  my @input     = @_;

  my $data  = {};
     # FOR PARAMETER BLOCKS
     # {data}->{ BLOCK_NAME }->{ q }       = Q
     # {data}->{ BLOCK_NAME }->{ 0 }       = VALUE for no-index block.
     # {data}->{ BLOCK_NAME }->{"$I"}      = VALUE for one-index block.
     # {data}->{ BLOCK_NAME }->{"$I1 $I2"} = VALUE for two-index block.

     # FOR DECAY BLOCKS
     # {data}->{ decay }->{ PDG_ID }->{ rate }  = Decay rate
     # {data}->{ decay }->{ PDG_ID }->{ all }   = LIST [ BR, DAUGHTER1, DAUGHTER2, ... ]
     # {data}->{ decay }->{ PDG_ID }->{ $key }  = VALUE
     #          ($key = "daughter1 daughter2 ... " with ID smaller to larger, 
     #           such as  "5 24" or "-24 -5".)
  my $comment = {};
     # FOR PARAMETER BLOCKS
     # {comment}->{ BLOCK_NAME }->{ head }
     # {comment}->{ BLOCK_NAME }->{ 0 }
     # {comment}->{ BLOCK_NAME }->{"$I"}
     # {comment}->{ BLOCK_NAME }->{"$I1 $I2"}

     # FOR DECAY BLOCKS
     # {comment}->{ decay }->{ PDG_ID }->{ rate }
     # {comment}->{ decay }->{ PDG_ID }->{ $key }
     #          ($key = "daughter1 daughter2 ... " with ID smaller to larger, 
     #           such as  "5 24" or "-24 -5".)

  my $order = [];


  my $block = "";
  my $decay = 0;
  foreach my $line(@input){
    my @parse = _parse_block_line($line, $block eq 'DECAY');
    next if @parse < 2;

    if($parse[0] eq 'BLOCK'){
      my ($x, $args, $com);
      ($x, $block, $args, $com) = @parse;
      $block = uc($block);
      unless($data->{$block}){
        $data   ->{$block} = {};
        $comment->{$block} = { head => $com };
        if($args =~ /^(.*\s)?Q\s*=\s*([\d.+-ed]+)/i){
          $data->{$block}->{q} = _fortranparse($2);
        }
      }
      push(@$order, $block);
      next;
    }
    if($parse[0] eq 'DECAY'){
      my ($x, $id, $rate, $args, $com) = @parse;
      $data   ->{decay} = {} unless $data->{decay};
      $comment->{decay} = {} unless $comment->{decay};

      $data   ->{decay}->{$id} = { rate => $rate, all => [] };
      $comment->{decay}->{$id} = { rate => $com };

      $block = 'DECAY';
      $decay = $id;
      push(@$order, "DECAY $id");
      next;
    }
    next unless $block;

    if($block ne 'DECAY'){
      # PARAM BLOCK VALUE
      my($key, $value, $com) = @parse;
      $value = _fortranparse($value);
      $data   ->{$block}->{$key} = $value;
      $comment->{$block}->{$key} = $com;
    }else{
      # DECAY BLOCK VALUE
      my $com   = pop(@parse);
      my $value = shift(@parse);
      $value = _fortranparse($value);
      my $nda = shift(@parse);
      die if $nda != @parse;
      @parse = sort{$a<=>$b}(@parse);
      my $key = join(" ", @parse);
      $data   ->{decay}->{$decay}->{$key} = $value;
      $comment->{decay}->{$decay}->{$key} = $com;
      push(@{$data->{decay}->{$decay}->{all}}, [$value, @parse]);
    }
  }
  bless {
         file_name => $file_name,
         data      => $data,
         comment   => $comment,
         order     => $order,
        }, $class;
}

sub DESTROY{
    my $self = shift;
    undef $self->{data};
    undef $self->{order};
}

# ==================================================================== ACCESSORS

sub block_list{
  my $self = shift;
  my @a = ();
  foreach(keys %{$self->{data}}){ push(@a, $_) unless $_ eq 'decay'; }
  return @a;
}
sub key_list{
  my $self = shift;
  my $block = shift;
  $block = uc($block);
  my @a = ();
  foreach(keys %{$self->{data}->{$block}}){ push(@a, $_) unless $_ eq 'q'; }
  return @a;
}

sub v{
  my $self = shift;
  my $block = shift;
  $block = uc($block);
  my $key = _block_key(@_);
  return $self->{data}->{$block}->{$key};
}

sub Q{
  my $self = shift;
  my $block = shift;
  $block = uc($block);
  return $self->{data}->{$block}->{q};
}


sub d{
  my $self = shift;
  my $id   = shift;
  return $self->{data}->{decay}->{$id}->{rate};
}
sub dlist{
  my $self = shift;
  my $id   = shift;
  return $self->{data}->{decay}->{$id}->{all};   # returning reference, DANGEROUS!
}
sub br{
  my $self = shift;
  my $id   = shift;
  my @daughters = sort{$a<=>$b}(@_);
  _strip($_) foreach @daughters;
  return $self->{data}->{decay}->{$id}->{join(" ", @daughters)};
}

# ================================================================= MANIPURATORS

sub _define_block{
  my $self = shift;
  my $block = shift;
  $block = uc($block);
  $self->{data}   ->{$block} = {} if !defined $self->{data}   ->{$block};
  $self->{comment}->{$block} = {} if !defined $self->{comment}->{$block};
}

sub _remove_block{
  my $self = shift;
  my $block = shift;
  $block = uc($block);
  undef $self->{data}   ->{$block}   if defined $self->{data}   ->{$block};
  undef $self->{comment}->{$block}   if defined $self->{comment}->{$block};
}

sub _param_key{
  my $self = shift;
  my $block = shift;
  $block = uc($block);
  my @keys = @_;
  if(@keys == 0){
    my $flag = 0;
    if(defined $self->{data}->{$block}){
      foreach(keys %{$self->{data}->{$block}}){
        if($_ != 0){ $flag = 1; last; }
      }
    }
    die "[ERROR] Block [$block] needs a key." if $flag;
    return "0";
  }else{
    _strip($_) foreach @keys;
    return join(" ", @keys);
  }
}

sub set_param_and_comment{
  my $self    = shift;
  my $block   = shift;
  my $comment = pop;
  my $value   = pop;
  $self->set_param($block, @_, $value);
  $self->set_comment($block, @_, $comment);
}

sub set_param{
  my $self  = shift;
  my $block = shift;
  my $value = pop;
  $block = uc($block);
  $self->_define_block($block);
  my $key   = $self->_param_key($block, @_);
  $self->{data}->{$block}->{$key} = $value;
}

sub set_Q{
  my $self  = shift;
  my $block = shift;
  my $value = pop;
  $block = uc($block);
  $self->_define_block($block);
  $self->{data}->{$block}->{q} = $value;
}

sub remove_param{
  my $self  = shift;
  my $block = shift;
  $block = uc($block);

  return unless defined($self->{data}->{$block});
  my $key = $self->_param_key($block, @_);

  delete $self->{data}->{$block}->{$key};
  $self->_remove_block($block) if $self->key_list($block) == 0;
}

sub remove_block{
  my $self  = shift;
  my $block = shift;
  $block = uc($block);
  $self->_remove_block($block);
}

sub set_comment_head{
  my $self = shift;
  my $block = shift;
  my $value = shift || "";
  $block = uc($block);
  _strip($value);
  $value = "# $value" unless $value =~ /^#/;

  $self->_define_block($block);
  $self->{comment}->{$block}->{head} = $value;
}

sub set_comment{
  my $self  = shift;
  my $block = shift;
  my $value = pop || "";
  $block = uc($block);
  _strip($value);
  $value = "# $value" unless $value =~ /^#/;

  $self->_define_block($block);
  my $key   = $self->_param_key($block, @_);
  $self->{comment}->{$block}->{$key} = $value;
}

# ======================================================================= OUTPUT

sub is_number { $_[0] =~ /^[+-]?(\d*\.)\d+([de][+-]?\d+)?$/i; }
sub is_integer{ is_number($_[0]) && $_[0] !~ /[\.de]/i; }
sub is_float  { is_number($_[0]) && $_[0] =~ /[\.de]/i; }

sub numstr{ sprintf(is_float($_[0]) ? "%16.8e" : is_number($_[0]) ? "%9d       " : "%-16s", $_[0]); }
sub e { sprintf("%16.8e", $_[0] || 0); }
sub f { sprintf("  %4d  %s   %s\n",    $_[0]||0,           numstr($_[1]||0), $_[2]||""); }
sub fc{ sprintf("# %4d  %s   %s\n",    $_[0]||0,           numstr($_[1]||0), $_[2]||""); }
sub f2{ sprintf(" %2d %2d  %s   %s\n", $_[0]||0, $_[1]||0, numstr($_[2]||0), $_[3]||""); }
sub f0{ sprintf("        %s   %s\n",                       numstr($_[0]||0), $_[1]||""); }
sub dh{ sprintf("DECAY %9d   %16.8e\n", $_[0] || 0, $_[1] || 0); }
sub dd{ sprintf("    %16.8e   %3d" . ("   %9d" x ($#_-1)) . "   %s\n", $_[0] || 0, ($#_-1) || 0, @_[1..$#_]); }

sub write{
  my $self = shift;
  my %done;

  my $result = [];

  # PARAM BLOCK FIRST.
  foreach(@{$self->{order}}){
    next if /^DECAY ([\d+-]+)$/;
    $done{$_} = 1;
    _write_block($result, $self, $_);
  }
  foreach(keys %{$self->{data}}){
    next if $_ eq 'decay' or $done{$_};
    _write_block($result, $self, $_);
  }

  # THEN DECAY BLOCK.
  foreach(@{$self->{order}}){
    next unless /^DECAY ([\d+-]+)$/;
    $done{"DECAY $1"} = 1;
    _write_decay($result, $self, $1);
  }
  foreach(keys %{$self->{data}->{decay}}){
    next if $done{"DECAY $_"};
    _write_decay($result, $self, $_);
  }
  foreach(@$result){ s/\s+$//img; $_ .= "\n"; }
  return @$result;
}

sub _write_block{
  my $result = shift;
  my $self   = shift;
  my $block  = shift;

  $block = uc($block);

  return unless $self->key_list($block);

  my $data = $self->{data}->{$block};
  my $com  = $self->{comment}->{$block};

  my $q  = defined($data->{q})   ? " Q = " . e($data->{q}) : "";
  my $hc = defined($com->{head}) ? "    " . $com->{head} : "";

  push(@$result, "BLOCK $block$q$hc\n");
  foreach my $k(sort { my ($c, $d) = ($a, $b);
                       $c =~ s/(\d+) (\d+)/$1*10000+$2/e;
                       $d =~ s/(\d+) (\d+)/$1*10000+$2/e; $c <=> $d
                } keys(%$data)){
    next if $k eq 'q';
    my $c = $com->{$k} || "";

    if($k =~ /^(\d+) (\d+)$/){
      push(@$result, f2($1, $2, $data->{$k}, $c));
    }elsif($k == 0){
      push(@$result, f0($data->{$k}, $c));
    }else{
      push(@$result, f($k, $data->{$k}, $c));
    }
  }
  push(@$result, "#\n");
}

sub _write_decay{
  my $result = shift;
  my $self = shift;
  my $block = shift;

  $block = uc($block);
  my $data = $self->{data}->{decay}->{$block};
  my $com  = $self->{comment}->{decay}->{$block};

  my $hc = $com->{rate} || "";
  push(@$result, dh($block, $data->{rate}, $hc));
  foreach(sort {$b->[0] <=> $a->[0]} @{$data->{all}}){
    my $key = join(" ", sort {$a<=>$b} @{$_}[1..$#{$_}]);
    my $c = $com->{$key} || "";
    push(@$result, dd(@{$_}, $c));
  }
  push(@$result, "#\n");
}

sub write_block{
  my $self = shift;
  my $block = shift;
  my @result = ();
  _write_block(\@result, $self, $block);
  return @result;
}

sub write_decay{
  my $self = shift;
  my $block = shift;
  my @result = ();
  _write_decay(\@result, $self, $block);
  return @result;
}

1;
