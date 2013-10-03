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

    # 
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
    open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
    #open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
    open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";    
    defined(my $pid = fork)   or die "Can't fork: $!";
    exit if $pid;
    setsid                    or die "Can't start a new session: $!";    
}
####

sub debugsay {
    print shift."\n" if ($debug);
}

sub dir2arr {
    my $dir = shift;
    our @arr;
    opendir (my $dh, $dir) or return undef;
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
        } else {
            sleep 1;
        }
    }
    (sub {})->() while ($PAUSED);
}

sub single {
    my $image;
    $image = $config->{walls}[$config->{select}]->{file} if ($config->{select} > -1);
    $image = $config->{walls}[(floor(rand(scalar @{$config->{walls}})))] if ($config->{select} == -1);

    $image = ( defined($config->{dir}) ? $config->{dir} : $ENV{HOME} ) . "/$image" if ($image =~ /^[^~\/]/);
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
            $image = ( defined($config->{dir}) ? $config->{dir} : $ENV{HOME} ) . "/$image" if ($image =~ /^[^~\/]/);
            my $style = defined($_->{style}) ?
                $_->{style} 
                : defined($config->{style}) ? 
                    $config->{style} 
                    : "centered";

            system "$bgcommand ".$formats{$style}." $image";
            mysleep($config->{sleep});
        }
    })->() while (1 and !$RELOADCONF) ;
}

sub seqdir {
    my @images = dir2arr($config->{dir});
    (sub {
        foreach(@images) {
            my $image = $config->{dir} . "/$_";
            my $style = defined($config->{style}) ? 
                $config->{style} 
                : "centered";

            system "$bgcommand ".$formats{$style}." $image";
            mysleep($config->{sleep});
        }
    })->() while (1 and !$RELOADCONF) ;

}
sub random {
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


daemonise() if ($config->{background} eq 1);



# our pidfile
open my $fh, ">", $ENV{HOME}."/.walls.pid";
print $fh $$;
close $fh;

while ( 1 ) {
    $config = YAML::LoadFile($ENV{HOME}."/.walls.conf");
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
# vim: set ts=4 sw=4 tw=0 et :
