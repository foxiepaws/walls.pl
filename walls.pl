#!/usr/bin/env perl

# 
#
#
#
#

use YAML;
use feature "switch";
use POSIX;
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


our %formats = (
    tiled    => "--no-fehbg --bg-tile",
    centered => "--no-fehbg --bg-center",
    scaled   => "--no-fehbg --bg-scale",
    filled   => "--no-fehbg --bg-fill",
);

our $bgcommand = "feh";
our $RELOADCONF = 0;
$SIG{HUP} = (sub { $RELOADCONF = 1 });



## from Daemonise.pm by Andy Dixon, <ajdixon@cpan.org>
sub daemonise {
    chdir '/'                 or die "Can't chdir to /: $!";
    umask 0;
    open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
    #open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
    open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";    
    defined(my $pid = fork)   or die "Can't fork: $!";
    exit if $pid;
    setsid                    or die "Can't start a new session: $!";    
}
####


sub single {
    my $image = $config->{walls}[$config->{select}]->{file};
    my $style = defined($config->{walls}[$config->{select}]->{style}) ?
        $config->{walls}[$config->{select}]->{style} 
        : defined($config->{style}) ? 
            $config->{style} 
            : "centered";

    system "$bgcommand ".$formats{$style}." $image"
}

sub seq {
   # run sequentually though the walls array.
    (sub {
        foreach(@{$config->{walls}}) {
            my $image = $_->{file};
            my $style = defined($_->{style}) ?
                $_->{style} 
                : defined($config->{style}) ? 
                    $config->{style} 
                    : "centered";

            system "$bgcommand ".$formats{$style}." $image";
            sleep($config->{sleep});
        }
    })->() while (1 and !$RELOADCONF) ;
}
sub seqdir {
    die "not yet implemented";
}
sub random {
    my $walls = $config->{walls};
    while ( 1 and !$RELOADCONF ) {
        my $select = floor(rand(scalar @{$walls}));
        my $image = $config->{walls}[$select]->{file};
        my $style = defined($config->{walls}[$select]->{style}) ?
            $config->{walls}[$select]->{style} 
            : defined($config->{style}) ? 
                $config->{style} 
                : "centered";
        system "$bgcommand ".$formats{$style}." $image";
        sleep($config->{sleep});
    }
}
sub randir {
    die "not yet implemented";
}


daemonise();
# our pidfile
open my $fh, ">", $ENV{HOME}."/.walls.pid";
print $fh $$;
close $fh;

while ( 1 ) {
    our $config = YAML::LoadFile($ENV{HOME}."/.walls.conf");
    $RELOADCONF = 0;
    given ($config->{mode}) {
        single() when "single";
        seq() when "seq";
        seqdir() when "seqdir";
        random() when "rand";
        randir() when "randdir"
    }
    # prevent feh from being called every 30 seconds if on single.
    (sub {})->() while(!$RELOADCONF);
}


1;
