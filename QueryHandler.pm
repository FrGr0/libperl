#!/usr/bin/perl
###########################
use strict;
use warnings;


package QueryHandler;

sub new { 
    use File::Basename;
    my ( $class, $directory) = @_;

    my %files;
    opendir(DIR, $directory) or die $!;
    while (my $file = readdir(DIR)) {
        my ($f,$dir,$ext) = fileparse($file, qr/\.[^.]*/);
        if ( uc( $ext ) eq ".SQL" ) {
            $files{$f} = $directory."/".$file;
        }
    };
    my $self = bless { 
        dir  => $directory,
        files => \%files,
    }, $class;
    return $self;
}

sub GetQuery {
    my ( $self, $queryName ) = @_;
    my $data;

    if ( exists ${$self->{files}}{$queryName} ){ 
        open( my $handle, "<", ${$self->{files}}{$queryName} );
        $data = do { local $/; <$handle> };
        close( $handle );
    }
    else {
        print "requete inexistante !";
    }
    return $data;
}

sub Count {
    my ( $self ) = @_;
    return keys (%{$self->{files}});
}

1;