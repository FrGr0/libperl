#!/usr/bin/perl
###########################
use strict;
use warnings;
use diagnostics;
use POSIX qw(strftime); 


package CLogs;

sub new { 
    my ( $class, $nom_fichier, $printtime, $printout )  = @_;                 
    
    if(!($printtime)) {
        $printtime=0;
    }
    
    if(!($printout)) {
        $printout=0;
    }
       
    open( my $handle, '>:encoding( UTF-8 )', $nom_fichier );
    
    my $self = bless { 
                   hfw  => $handle,
                   file => $nom_fichier, 
                   tsp  => $printtime,
                   std  => $printout, 
                    }, $class;
            
    return $self;
}

sub write {    
    my ( $self, $line, $die ) = @_;
    
    my $timestamp = "";    
    
    if ( $self->{tsp} ) {
        $timestamp = "[".&POSIX::strftime( "%d/%m/%Y %H:%M:%S", localtime() )."] ";     
    }
    
    if ( $self->{std} ){
        print $timestamp.$line."\n";   
    } 
    
    print {$self->{hfw}} $timestamp.$line."\n";   
    
    
    #affiche la sortie standard
    #print $timestamp.$line."\n";   
    
    if ($die) {
        print "[ERREUR] ".$line."\n";
        print {$self->{hfw}} "[ERREUR] ".$line."\n";
        close( $self->{hfw} );
        exit(0);
    }
}

sub close {
    my ( $self ) = @_;
    close( $self->{hfw} );
}

1;