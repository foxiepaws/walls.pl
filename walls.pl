#!/usr/bin/env perl

# walls.pl
# Allie Theze
#
# This script is a simple wallpaper switcher, designed for use with 
# tiling window managers like dwm. It was written in 2013 and really
# needs some work done to it, keep your eyes out for updates as I
# slowly rewrite it!


use strict;
use warnings;
use YAML;
use feature "switch";
use 5.18.0;
no warnings "experimental";
use POSIX;
use Carp;
use Data::Dumper;
## example config ########
#mode: single
#select: 0
#walls:
#    - file: ~/tweed.png
#      style: tiled
#
## vim: syntax=yaml
##########################


our $config = YAML::LoadFile($ENV{HOME}."/.walls.conf");

our %formats = (
    tiled    => "--no-fehbg --bg-tile",
    centered => "--no-fehbg --bg-center",
    scaled   => "--no-fehbg --bg-scale",
    filled   => "--no-fehbg --bg-fill",
);

our $bgcommand = "feh";
our $debug = 0;
our $RELOADCONF = 0;
our $PAUSED = 0; 
our $NEXT = 0;
$SIG{HUP} = (sub { debugsay("reloading config"); $RELOADCONF = 1 });
$SIG{TERM} = (sub { debugsay("quitting!"); unlink $ENV{HOME}."/.walls.pid"; exit 0; });
$SIG{USR1} = (sub { if (!$PAUSED) { debugsay( "pausing!"); $PAUSED = 1 } else { debugsay( "unpausing!");$PAUSED = 0 } });
$SIG{USR2} = (sub { debugsay("trying to skip to next image!");$NEXT = 1 });

## modified from Daemonise.pm by Andy Dixon, <ajdixon@cpan.org>
sub daemonise {

    my $fho = 0;
    open my $fh, '<', $ENV{HOME} . "/.walls.pid" and $fho = 1;
    if (defined($fho)) {
        my $opid = readline $fh;
        close $fh; 
        debugsay("pid found: $opid");
        if (-d "/proc/$opid/") {
            `kill $opid`;
        }
    }

    chdir '/'                 or die "Can't chdir to /: $!";
    umask 0;
    open STDIN, '<', '/dev/null'   or die "Can't read /dev/null: $!";
    #open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
    open STDERR, '>', '/dev/null' or die "Can't write to /dev/null: $!";
    defined(my $pid = fork)   or die "Can't fork: $!";
    exit if $pid;
    setsid                    or die "Can't start a new session: $!";
}
####

sub debugsay {
    print shift."\n" if ($debug);
}

sub fix_path {
    my $odir = shift;
    if ($odir =~ /^~\//) {
        $odir =~ s/^~/$ENV{HOME}/;
        return $odir;
    } elsif ($odir =~ /^~(?<user>\w)\//) {
        ...;
    } else {
        return $odir;
    }
}

sub dir2arr {
    my $dir = shift;
    $dir = fix_path $dir;
    our @arr;
    opendir (my $dh, $dir) or return;
    @arr = grep { /\.(jpe?g|png|gif)/ } readdir $dh;
    close $dh;
    return @arr;
}

sub mysleep {
    my $time = shift;
    # handle pausing
    for (my $i = 0; $i < $time; $i++) {
        if ($NEXT == 1) {
            $NEXT = 0;
            return;
        } elsif ($RELOADCONF) {
            # return as immediately as we can. 
            return;
        } else {
            sleep 1;
        }
    }
    sleep 1 while ($PAUSED);
}

sub single {
    my ($image, $style);
    for ($config->{select}) {
        do {
            # select a specific image from the list of walls based on
            # the toplevel config var "select". (0 indexed)
            my @walls = @{$config->{walls}};
            $image = $walls[$_];
        } when $_ > -1;
        default {
            # randomly select an image from the list of walls.
            my @walls = @{$config->{walls}};
            $image = $walls[rand @walls];
        }
    }
    # get which style we are going to use.
    if (defined($image->{style})) {
        $style = $image->{style};
    } elsif (defined($config->{style})) {
        $style = $config->{style};
    } else {
        $style = "centered";
    }
    # fix the path using the above fix path implementation, and
    # display the image if it exists, or warn the user otherwise.
    for (fix_path $image->{file}) {
        system "${bgcommand} ${formats{$style}} ${_}" when -f;
        default {
            carp "file doesn't actually exist";
        }
    }
}

sub seq {
    # collect walls from config file into @walls now to prevent constant redefining
    my @walls = @{$config->{walls}};
    # loop until reload conf is set
    while (!$RELOADCONF) {
        foreach my $image (@walls) {
            my $style;
            if (defined($image->{style})) {
                $style = $image->{style};
            } elsif (defined($config->{style})) {
                $style = $config->{style};
            } else {
                $style = "centered";
            }
            # figure out if we need to prepend all files
            my $path;
            for ($image->{file}) {
                do {
                    # image isn't an absolute path nor does it point to
                    # at the home directory, and config has a dir setting
                    $path = fix_path $config->{dir} . "/" . $_;
                } when /^[^~\/]/ and defined($config->{dir});
                default {
                    $path = fix_path $_;
                }
            }
            # actually try to display the image
            for ($path) {
                system "${bgcommand} ${formats{$style}} ${_}" when -f;
                default {
                    carp "file doesn't actually exist";
                }
            }
            # call special sleep algorithm to handle config reloading, skipping, and pausing.
            mysleep($config->{sleep});
            # break out if we need to reload
            last if $RELOADCONF;
        }
    }
}

sub seqdir {
    my @images = dir2arr($config->{dir});
    my $style;
    if (defined($config->{style})) {
        $style = $config->{style};
    } else {
        $style = "centered";
    }
    while (!$RELOADCONF) {
        foreach my $image (@images) {
            
            
            my $path;
            for ($image) {
                do {
                    # image isn't an absolute path nor does it point to
                    # at the home directory, and config has a dir setting
                    $path = fix_path $config->{dir} . "/" . $_;
                } when /^[^~\/]/ and defined($config->{dir});
                default {
                    $path = fix_path $_;
                }
            }
            # actually try to display the image
            for ($path) {
                system "${bgcommand} ${formats{$style}} ${_}" when -f;
                default {
                    carp "file doesn't actually exist";
                }
            }
            mysleep($config->{sleep});
            last if $RELOADCONF;
        }
    }
}

#sub seqdir {
#    # FIXME: once again, what was i thinking
#    my @images = dir2arr($config->{dir});
#    (sub {
#        foreach(@images) {
#            my $image = $config->{dir} . "/$_";
#            my $style = defined($config->{style}) ? 
#                $config->{style} 
#                : "centered";
#            debugsay("$bgcommand ".$formats{$style}." $image");
#            system "$bgcommand ".$formats{$style}." $image";
#            mysleep($config->{sleep});
#        }
#    })->() while (1 and !$RELOADCONF) ;
#
#}
sub random {
    # FIXME: This is /so bad/ probably the worst perl I've ever written.
    my $walls = $config->{walls};
    while ( 1 and !$RELOADCONF ) {
        my $select = floor(rand(scalar @{$walls}));
        my $image = $config->{walls}[$select]->{file};
        $image = ( defined($config->{dir}) ? $config->{dir} : $ENV{HOME} ) . "/$image" if ($image =~ /^[^~\/]/);
        my $style = defined($config->{walls}[$select]->{style}) ?
            $config->{walls}[$select]->{style} 
            : defined($config->{style}) ? 
                $config->{style} 
                : "centered";
        system "$bgcommand ".$formats{$style}." $image";
        mysleep($config->{sleep});
    }
}

sub randir {
    # FIXME: Also really bad
    my @images = dir2arr($config->{dir});
    while ( 1 and !$RELOADCONF ) {
        my $select = floor(rand(scalar @images));
        my $image = $config->{dir} . "/". $images[$select];
        my $style = defined($config->{style}) ? 
            $config->{style} 
            : "centered";

        system "$bgcommand ".$formats{$style}." $image";
        mysleep($config->{sleep});
    }
}


daemonise() if (defined $config->{background} && $config->{background} eq 1);
# our pidfile
open my $fh, ">", $ENV{HOME}."/.walls.pid";
print $fh $$;
close $fh;
while ( 1 ) {
    $config = YAML::LoadFile($ENV{HOME}."/.walls.conf");
    $RELOADCONF = 0;
    my $mode = $config->{mode};
    for ($mode) {
        single() when /^single$/;
        seq() when /^seq$/;
        seqdir() when /^seqdir$/;
        random() when /^rand$/;
        randir() when /^randdir$/;
    }
    # prevent feh from being called every 30 seconds if on single.
    sleep .5 while(!$RELOADCONF);
}
# vim: set ts=4 sw=4 tw=0 et :
