use v5.12;
use ZRTeXtor ':all';
use ZRJCode ':all';
use ZRWidthCid;
use Encode qw(encode decode);
my $prog_name = 'generate';
my $version = '0.5-pre';
my $mod_date = '2019/02/17';
use Data::Dumper;
$Data::Dumper::Indent = 1;
require "cid2uni.pl";
our (@cid2uni);

# the prefix to be attached to new VFs
my $prefix = "zu-";
# output directories
my $tfm_dir = "../tfm";
my $vf_dir = "../vf";

# list of non-Unicode japanese-otf VF name-formats
my @otf_vfname = qw(
brsgnmlXXYY-D
brsgnmlXXYYn-D
cidjXY0-D
cidjXY1-D
cidjXY2-D
cidjXY3-D
cidjXY4-D
cidjXY5-D
nmlXXYY-D
nmlXXYYn-D
rubyXXYY-D
);
# list of Unicode japanese-otf VF info
# entry: [<vf_nformat>, <main_raw_tfm_nformat>]
my @otfu_vfname = (
[qw( upbrsgnmlXXYY-D uphXXYY-D )],
[qw( upbrsgnmlXXYYn-D uphXXYYn-D )],
[qw( upnmlXXYY-D uphXXYY-D )],
[qw( upnmlXXYYn-D uphXXYYn-D )],
[qw( uprubyXXYY-D uphXXYY-D )],
);

sub ruby_alternate_font {
  local ($_) = @_;
  return (s/ruby/nml/) ? $_ : undef;
}
#
#my @omitted = qw(
#brsgexpXXYY-D
#brsgexpXXYYn-D
#expXXYY-D
#expXXYYn-D
#rubyXXYY-D
#);

# list of shape entries
# entry: [<XX>, <X>, <YY>, <Y>]
my @otf_shape = map { [ split(m|/|, $_) ] } qw(
min/m/l/l
min/m/r/r
min/m/b/b
goth/g/r/r
goth/g/b/b
goth/g/eb/e
mgoth/mg/r/r
); # XX/X/YY/Y
#$#otf_shape=0;

# direction symbols
my @dir = qw( h v );

sub main {
  local ($_);
  if (defined textool_error()) { error(); }
  mkdir($vf_dir); (-d $vf_dir) or error("cannot make", $vf_dir);
  mkdir($tfm_dir); (-d $tfm_dir) or error("cannot make", $tfm_dir);
  jcode_set('none', 'none') or error();
  pl_prefer_hex(1);
  # prepare
  make_toucs();
  # standard
  process_shape_std("jis", "rml", "uprml-h", "uprml-hq");
  process_shape_std("jis-v", "rmlv", "uprml-v", "uprml-v");
  process_shape_std("jisg", "gbm", "upgbm-h", "upgbm-hq");
  process_shape_std("jisg-v", "gbmv", "upgbm-v", "upgbm-v");
  process_shape_std("min10", "rml", "uprml-h", "uprml-hq");
  process_shape_std("tmin10", "rmlv", "uprml-v", "uprml-v");
  process_shape_std("goth10", "gbm", "upgbm-h", "upgbm-hq");
  process_shape_std("tgoth10", "gbmv", "upgbm-v", "upgbm-v");
  # japanese-otf
  foreach my $vfn0 (@otf_vfname) {
    foreach my $shp (@otf_shape) {
      foreach my $dir ('h', 'v')  {
        process_shape_otf($vfn0, $shp, $dir);
  }}}
  foreach my $e (@otfu_vfname) {
    my ($vfn0, $up) = @$e;
    foreach my $shp (@otf_shape) {
      foreach my $dir ('h', 'v')  {
        process_shape_otf($vfn0, $shp, $dir, $up);
  }}}
  foreach my $shp (@otf_shape) {
    foreach my $dir ('h', 'v')  {
      process_extra_raw_tfm($shp, $dir);
  }}
}

## otf_font_name(<nformat>, <shape_entry>, <dir_sym>)
# The actual font name.
sub otf_font_name {
  my ($name0, $shape, $dir) = @_;
  local $_ = $name0; my ($xx, $x, $yy, $y) = @$shape;
  s/XX/$xx/; s/X/$x/; s/YY/$yy/; s/Y/$y/; s/D/$dir/;
  return $_;
}

# code conversion map
# <in_code> -> [<unicode>, <glyph_var>, <ruby_switch>]
# glyph_var: 0=90JIS, 1=2004JIS, 2=quote
# ruby_switch: 0=normal, 1=ruby
my (%toucs);

## make_toucs()
# Prepares %toucs.
sub make_toucs {
  info("make_toucs");
  my %cidmap = map {
    my $r = $cid2uni[$_];
    $_ => (ref $r) ? [@$r] : [ $r, 0 ]
  } (0 .. $#cid2uni);
  delete $cidmap{0};
  my %upmap = map { $_ => [ $_, 0, 1 ] } (0 .. 0x2FFFF);
  foreach (0x2018, 0x2019, 0x201C, 0x201D) {
    $upmap{$_}[1] = 2; $upmap{$_}[2] = 0;
  }
  # Ruby fonts are tricky in that they abuse raw TFMs for CID.
  # ruby_swictch is turned off for each character such that:
  # - the character is a kanji;
  # - code value is out of CID range, i.e. over 23057 (=0x5A11);
  #   (that makes the switch-off range of >= 0x4E00)
  # - the CID glyph for that value has a fixed-width other than fullwidth.
  foreach (0x3200 .. 0x4DBF) { $upmap{$_}[2] = 0; }
  foreach (0x4E00 .. 0x2FFFF) { $upmap{$_}[2] = 0; }
  foreach (0 .. 0x4DFF) {
    if (width_aj1($_) >= 2) { $upmap{$_}[2] = 0; }
  }
  my %jismap = map {
    my $uc = in_ucs($_, EJV_UPTEX);
    in_jis($_) => $upmap{$uc}
  } grep { defined_jis($_) } (0 .. MAX_INTCODE);
  %toucs = ( jis => \%jismap, cid => \%cidmap, up => \%upmap );
}

## process_shape_std(<vf_name>, <jis_tfm_name>, <uni_tfm_name>,
#    <quote_tfm_name>)
sub process_shape_std {
  my ($vfn, $jtfm, $utfm, $utfmq) = @_; local ($_);
  info("process", $vfn);
  $_ = read_whole_file(kpse("$vfn.vf"), 1) or error();
  $_ = convert_vf($_, $utfm ne $utfmq, 0,
      [$jtfm], [], [], [$utfm, $utfm, $utfmq]);
  finish($vfn, $_);
}

## process_shape_otf(<vf_nformat>, <shape_entry>, <dir_sym>
#    [, <main_raw_tfm_nformat>])
sub process_shape_otf {
  my ($vfn0, $shp, $dir, $up) = @_; local ($_);
  my $vfn = otf_font_name($vfn0, $shp, $dir);
  $_ = ruby_alternate_font($vfn0);
  my $avfn = (defined $_) ? otf_font_name($_, $shp, $dir) : undef;
  info("process", $vfn, $avfn);
  $_ = (defined $avfn) ? $avfn : $vfn;
  $_ = read_whole_file(kpse("$_.vf"), 1) or error();
  my @x = (defined $up) ? ([$up], [$up, $up, "otf-ujXY-D"]) :
    ([], ["otf-ujXY-D", "otf-ujXYn-D", "otf-ujXY-D"]);
  (defined $avfn) and push(@{$x[1]}, "zur-rjXY-D");
  $_ = convert_vf($_, $dir eq 'h', defined $avfn,
      map { [ map { otf_font_name($_, $shp, $dir) } (@$_) ] } (
        ["hXXYY-D", "hXXYYn-D"], ["otf-cjXY-D"], @x));
  finish($vfn, $_);
  (defined $avfn) and finish_ruby($shp, $dir);
}

## convert_vf(<vf_name>, <is_horiz>, <is_ruby>, <jis_tfm_name_list>,
#    <cid_tfm_name_list>, <main_tfm_name_list>, <uni_tfm_name_lsit>)
sub convert_vf {
  my ($vf, $horz, $ruby, $jisraw, $cidraw, $upraw, $uniraw) = @_;
  local $_ = vf_parse($vf) or error();
  my (@map) = grep { $_->[0] eq 'MAPFONT' } (@$_);
  my (@char) = grep { $_->[0] eq 'CHARACTER' } (@$_);
  my (@other) = grep { $_->[0] ne 'MAPFONT' && $_->[0] ne 'CHARACTER'} (@$_);
  my %mftyp = ((map { $_ => 'jis' } (@$jisraw)), (map { $_ => 'cid' } (@$cidraw)),
      (map { $_ => 'up' } (@$upraw)));
  # MAPFONT
  my ($omfid, $mfadj, $zmap) = convert_mapfont(\@map, \%mftyp, $uniraw);
  (defined $omfid) or error("no MAPFONT");
  info("MAPFONT count", scalar(@map) . " -> " . scalar(@$zmap));
  # CHARACTER
  my ($zchar) = convert_character(\@char, $omfid, $mfadj, $horz, $ruby);
  info("CHARACTER count", scalar(@char) . " -> " . scalar(@$zchar));
  #
  my $zvf = [ @other, @$zmap, @$zchar ];
  return vf_form($zvf);
}

## convert_mapfont(<map_data>, <mapfont_type_map>, <uni_tfm_name_list>)
# mapfont_type_map: <tfm_name> -> <mapfont_type>
# mapfont_type: either of 'jis', 'cid', 'up'
# Returns (<init_mapfont_id>, <mapfont_adjust_map>, <out_map_data>).
# mapfont_adjust_map: <in_mapfont_id> ->
#    either of <out_mapfont_id> or <out_mapfont_id_list>
# out_mapfont_id_list: out-mapfont-id for each of <uni_tfm_name_list>
sub convert_mapfont {
  my ($map, $mftyp, $uniraw) = @_; local ($_);
  my ($omfid, %mfadj, @zmap, %zuni);
  foreach (@$map) {
    ($_->[3][0] eq 'FONTNAME') or die;
    my ($mfid, $nam) = (pl_value($_, 1), $_->[3][1]);
    (defined $omfid) or $omfid = $mfid;
    if (exists $mftyp->{$nam}) {
      my @adj = ($mftyp->{$nam}); $mfadj{$mfid} = \@adj;
      foreach my $ur (@$uniraw) {
        my $z = pl_clone($_); $z->[3][1] = $ur;
        my $signa = pl_form([@{$z}[3..$#$z]]); my $i = $zuni{$signa};
        if (!defined $i) {
          push(@zmap, $z); pl_set_value($z, 1, $#zmap);
          $i = $zuni{$signa} = $#zmap;
        }
        push(@adj, $i);
      }
    } else {
      my $z = pl_clone($_); $z->[3][1] = $prefix . $nam;
      push(@zmap, $z); pl_set_value($z, 1, $#zmap);
      $mfadj{$mfid} = $#zmap;
    }
  }
  return ($omfid, \%mfadj, \@zmap);
}

## convert_character(<in_char_data>, <init_mapfont_id>,
#   <mapfont_adjust_map>, <is_horiz>, <is_ruby>)
sub convert_character {
  my ($char, $omfid, $mfadj, $horz, $ruby) = @_; local ($_);
  my @zchar;
  L1:foreach (@$char) {
    my $z = pl_clone($_);
    ($z->[4][0] eq 'MAP') or die;
    my (@zmc); my ($fid, $zfid) = ($omfid, 0);
    foreach (@{$z->[4]}) {
      if (ref $_ && $_->[0] eq 'SELECTFONT') {
        $fid = pl_value($_, 1);
      } elsif (ref $_ && $_->[0] eq 'SETCHAR') {
        my $cc = pl_value($_, 1); my $nzfid = $mfadj->{$fid};
        #info("from", $fid, $cc);
        if (ref $nzfid) {
          my ($typ, @nzf) = @$nzfid;
          my $r = $toucs{$typ}{$cc} or next L1; my $ru;
          ($cc, $r, $ru) = @$r; ($r == 2 && !$horz) and $r = 0;
          ($ruby && $ru) and $r = -1;
          $nzfid = $nzf[$r];
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
  return (\@zchar);
}

## process_extra_raw_tfm(<shape_entry>, <dir_sym>)
sub process_extra_raw_tfm {
  my ($shp, $dir) = @_;
  foreach my $otfmn0 ("zur-gjXY-D") {
    my $tfmn = otf_font_name("hXXYY-D", $shp, $dir);
    my $otfmn = otf_font_name($otfmn0, $shp, $dir);
    my $tfm = read_whole_file(kpse("$tfmn.tfm"), 1) or error();
    write_whole_file("$tfm_dir/$otfmn.tfm", $tfm, 1) or error();
  }
}

sub finish {
  my ($vfn, $vf) = @_;
  my $ovfn = $prefix . $vfn;
  my $tfm = read_whole_file(kpse("$vfn.tfm"), 1) or error();
  write_whole_file("$tfm_dir/$ovfn.tfm", $tfm, 1) or error();
  write_whole_file("$vf_dir/$ovfn.vf", $vf, 1) or error();
}

sub finish_ruby {
  my ($shp, $dir) = @_;
  my $tfmn = otf_font_name("hXXYY-D", $shp, $dir);
  my $otfmn = otf_font_name("zur-rjXY-D", $shp, $dir);
  my $tfm = read_whole_file(kpse("$tfmn.tfm"), 1) or error();
  write_whole_file("$tfm_dir/$otfmn.tfm", $tfm, 1) or error();
}

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
