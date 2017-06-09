use v5.12;
use ZRTeXtor ':all';
use ZRJCode ':all';
use Encode qw(encode decode);
my $prog_name = 'gen-bxunionly';
my $version = '0.2';
my $mod_date = '2017/07/01';
use Data::Dump 'dump';
require "cid2uni.pl";
our (@cid2uni);

my $prefix = "zu-";
my $out_dir = "./out";

my @otf_vfname = qw(
brsgexpXXYY-D
brsgexpXXYYn-D
brsgnmlXXYY-D
brsgnmlXXYYn-D
cidjXY0-D
cidjXY1-D
cidjXY2-D
cidjXY3-D
cidjXY4-D
cidjXY5-D
expXXYY-D
expXXYYn-D
nmlXXYY-D
nmlXXYYn-D
rubyXXYY-D
);

my @otf_shape = map { [ split(m|/|, $_) ] } qw(
min/m/l/l
min/m/r/r
min/m/b/b
goth/g/r/r
goth/g/b/b
goth/g/eb/e
mgoth/mg/r/r
); # XX/X/YY/Y

my @dir = qw( h v );

#@otf_vfname = @otf_vfname[11, 6];
@otf_shape = @otf_shape[1];
@dir = @dir[0];
$prefix = "";

my %toucs;

sub main {
  local ($_);
  if (defined textool_error()) { error(); }
  mkdir($out_dir);
  (-d $out_dir) or error("cannot make", $out_dir);
  jcode_set('none', 'none') or error();
  pl_prefer_hex(1);
  # prepare
  make_toucs();
  # standard
  process_shape_std("jis", "rml", "upjpnrm-h");
  process_shape_std("jis-v", "rmlv", "upjpnrm-v");
  process_shape_std("jisg", "gbm", "upjpngt-h");
  process_shape_std("jisg-v", "gbmv", "upjpngt-v");
  # japanese-otf
  foreach my $vfn0 (@otf_vfname) {
    foreach my $shp (@otf_shape) {
      foreach my $dir ('h', 'v')  {
        process_shape_otf($vfn0, $shp, $dir);
  }}}
}

sub otf_font_name {
  my ($name0, $shape, $dir) = @_;
  local $_ = $name0; my ($xx, $x, $yy, $y) = @$shape;
  s/XX/$xx/; s/X/$x/; s/YY/$yy/; s/Y/$y/; s/D/$dir/;
  return $_;
}

sub make_toucs {
  info("make_toucs");
  my %jismap = map {
    in_jis($_) => [ in_ucs($_, EJV_UPTEX), 0 ]
  } grep { defined_jis($_) } (0 .. MAX_INTCODE);
  my %cidmap = map {
    my $r = $cid2uni[$_];
    $_ => (ref $r) ? [@$r] : [ $r, 1 ]
  } (0 .. $#cid2uni);
  delete $cidmap{0};
  %toucs = ( jis => \%jismap, cid => \%cidmap );
}

sub process_shape_std {
  my ($vfn, $jtfm, $utfm) = @_; local ($_);
  info("process", $vfn);
  $_ = read_whole_file(kpse("$vfn.vf"), 1) or error();
  $_ = convert_vf($_, [$jtfm], [], [$utfm, $utfm]);
  write_whole_file("$out_dir/$prefix$vfn.vf", $_, 1) or error();
}

sub process_shape_otf {
  my ($vfn0, $shp, $dir) = @_; local ($_);
  my $vfn = otf_font_name($vfn0, $shp, $dir);
  info("process", $vfn);
  $_ = read_whole_file(kpse("$vfn.vf"), 1) or error();
  $_ = convert_vf($_,
    [ map { otf_font_name($_, $shp, $dir) } ("hXXYY-D", "hXXYYn-D") ],
    [ map { otf_font_name($_, $shp, $dir) } ("otf-cjXY-D") ],
    [ map { otf_font_name($_, $shp, $dir) } ("otf-ujXY-D", "otf-ujXYn-D") ]);
  write_whole_file("$out_dir/$prefix$vfn.vf", $_, 1) or error();
}

sub convert_vf {
  my ($vf, $jisraw, $cidraw, $uniraw) = @_;
  local $_ = vf_parse($vf) or error();
  my (@map) = grep { $_->[0] eq 'MAPFONT' } (@$_);
  my (@char) = grep { $_->[0] eq 'CHARACTER' } (@$_);
  my (@other) = grep { $_->[0] ne 'MAPFONT' && $_->[0] ne 'CHARACTER'} (@$_);
  my %mftyp = ((map { $_ => 'jis' } (@$jisraw)), (map { $_ => 'cid' } (@$cidraw)));
  # MAPFONT
  my $zmfid = 0; my ($omfid, %mfadj, @zmap);
  foreach (@map) {
    ($_->[3][0] eq 'FONTNAME') or die;
    my ($mfid, $nam) = (pl_value($_, 1), $_->[3][1]);
    (defined $omfid) or $omfid = $mfid;
    if (exists $mftyp{$nam}) {
      my (@z, @i);
      foreach my $ur (@$uniraw) {
        my $z = pl_clone($_); pl_set_value($z, 1, $zmfid);
        $z->[3][1] = $ur;
        push(@z, $z); push(@i, $zmfid); $zmfid += 1;
      }
      push(@zmap, @z); $mfadj{$mfid} = [$mftyp{$nam}, @i];
    } else {
      my $z = pl_clone($_); pl_set_value($z, 1, $zmfid);
      $_->[3][1] = $prefix . $nam;
      $mfadj{$mfid} = $zmfid; $zmfid += 1;
      push(@zmap, $z);
    }
  }
  (defined $omfid) or error("no MAPFONT");
  info("MAPFONT count", scalar(@map) . " -> " . scalar(@zmap));
  # CHARACTER
  my @zchar;
  L1:foreach (@char) {
    my $z = pl_clone($_);
    ($z->[4][0] eq 'MAP') or die;
    my (@zmc); my ($fid, $zfid) = ($omfid, 0);
    foreach (@{$z->[4]}) {
      if (ref $_ && $_->[0] eq 'SELECTFONT') {
        $fid = pl_value($_, 1);
      } elsif (ref $_ && $_->[0] eq 'SETCHAR') {
        my $cc = pl_value($_, 1); my $nzfid = $mfadj{$fid};
        #info("from", $fid, $cc);
        if (ref $nzfid) {
          my ($typ, @nzf) = @$nzfid;
          my $r = $toucs{$typ}{$cc} or next L1;
          ($cc, $r) = @$r; $nzfid = $nzf[$r];
        }
        #info("to", $nzfid, $cc);
        if ($zfid != $nzfid) {
          $zfid = $nzfid;
          my $r = pl_cook_list(['SELECTFONT', 'D', 0]);
          pl_set_value($r, 1, $zfid); push(@zmc, $r);
        }
        my $r = pl_cook_list(['SETCHAR', 'H', 0]);
        pl_set_value($r, 1, $cc); push(@zmc, $r);
      } else { push(@zmc, $_); }
    }
    $z->[4] = \@zmc; push(@zchar, $z);
  }
  info("CHARACTER count", scalar(@char) . " -> " . scalar(@zchar));
  #
  my $zvf = [ @other, @zmap, @zchar ];
  return vf_form($zvf);
}

=nop

sub main_vf2zvp0 {
  my ($t);
  read_option();
  $t = read_whole_file(kpse($infile), 1) or error();
  $t = vf_parse($t) or error();
  $t = pl_form($t) or error();
  write_whole_file($outfile, $t) or error();
}

sub main_zvp02vf {
  my ($t);
  read_option();
  $t = read_whole_file(kpse($infile)) or error();
  $t = pl_parse($t) or error();
  $t = vf_form($t) or error();
  write_whole_file($outfile, $t, 1) or error();
}

sub main_zvp2vf {
  my ($t, $u);
  read_option();
  if ($sw_uptool) { jfm_use_uptex_tool(1); }
  $t = read_whole_file(kpse($infile)) or error();
  $t = pl_parse($t) or error();
  ($t, $u) = vf_form_ex($t) or error();
  write_whole_file($outfile, $t, 1) or error();
  write_whole_file($out2file, $u, 1) or error();
}

=cut

sub info {
  print STDERR (join(": ", $prog_name, @_), "\n");
}
sub alert {
  info("warning", @_);
}
sub error {
  info((@_) ? (@_) : textool_error());
  exit(-1);
}

main();
# EOF
