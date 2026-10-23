#!/usr/bin/env perl
# Find and rewrite the version values Renovate manages in mise.toml and *.pkl.
#
# Usage:
#   pins.pl mask     <path> <file>
#   pins.pl retarget <path> <file> <source-file>...
#
# <path> is the repo-relative name of <file> and selects the patterns; a file
# kind with no patterns is printed unchanged.
#
#   mask      print <file> with every managed version replaced by @PIN@, so two
#             files that differ only in versions compare equal.
#   retarget  print <file> with every managed version replaced by the one the
#             first <source-file> that has the same key carries; a key none of
#             them has keeps <file>'s own version.
#
# Managed versions (the ones .github/renovate.json bumps):
#   mise.toml  [tools] entries except `lua` (never bumped, a scaffold change is
#              intentional), and `luarocks install --local <pkg> <version>`
#   *.pkl      `package://github.com/<owner>/<repo>/releases/download/v<ver>/<name>@<ver>`

use strict;
use warnings;

sub rewrite {
  my ($path, $text, $fn) = @_;
  my $is_mise = $path =~ m{(?:^|/)mise\.toml$};
  my $is_pkl  = $path =~ m{\.pkl$};
  my $in_tools = 0;
  my $out = '';

  for my $line (split /^/, $text) {
    if ($is_mise) {
      $in_tools = $1 eq 'tools' if $line =~ /^\s*\[([^\]]+)\]/;
      if ($in_tools) {
        $line =~ s{^(\s*(?:"([^"]+)"|([\w.-]+))\s*=\s*")([0-9][^"]*)(")}{
          my $key = $2 // $3;
          $key eq 'lua' ? $& : $1 . $fn->("tool:$key", [$4])->[0] . $5;
        }e;
      }
      $line =~ s{(luarocks install --local (\w+) )([0-9][0-9.]*)}{
        $1 . $fn->("luarocks:$2", [$3])->[0];
      }e;
    }
    if ($is_pkl) {
      $line =~ s{(package://github\.com/([^/]+/[^/]+)/releases/download/v)([^/]+)(/[^@/]+@)([^#"]+)}{
        my $v = $fn->("pkl:$2", [$3, $5]);
        $1 . $v->[0] . $4 . $v->[1];
      }e;
    }
    $out .= $line;
  }
  return $out;
}

sub slurp {
  my ($file) = @_;
  open my $fh, '<', $file or die "pins.pl: cannot read $file: $!\n";
  local $/;
  return <$fh>;
}

my ($mode, $path, $file, @sources) = @ARGV;
die "usage: pins.pl mask <path> <file> | retarget <path> <file> <source-file>...\n"
  unless defined $file && ($mode eq 'mask' || $mode eq 'retarget');

if ($mode eq 'mask') {
  print rewrite($path, slurp($file), sub { [ map { '@PIN@' } @{ $_[1] } ] });
} else {
  my %known;
  for my $src (@sources) {
    rewrite($path, slurp($src), sub { $known{ $_[0] } //= $_[1]; $_[1] });
  }
  print rewrite($path, slurp($file), sub { $known{ $_[0] } // $_[1] });
}
