#!/usr/bin/perl
#_*_ coding: iso-8859-15 _*_

use strict;
use warnings;
use DBI;
use DBD::Oracle;
use POSIX;

package fwk;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(DBConnect DBQuery Prepare_Binding Execute_Procedure DBFieldOrder Timestamp);


# OUTILS DB ORACLE #####################################
#connexion a la BDD
sub DBConnect {
    my ( $class, $sid, $user, $pass ) = @_;    

    my $self = bless {
        dbh => undef,        
        sth => undef,        
        
    }, $class;

    my $connexionstr = sprintf( "dbi:Oracle:%s", $sid );
    my %dbattr = (
                PrintError => 0,
                RaiseError => 1,
                AutoCommit => 0,
            );
             
    $self->{dbh} = DBI->connect( $connexionstr, $user, $pass, \%dbattr ) or RaiseError(DBI->errstr);
    return $self;
}

#parcours de la reference de hash ligne par ligne
sub DBFetchAll {
    my ( $self ) = @_;
    return $self->{sth}->fetchrow_hashref;
}

#permet de recuperer la liste des champs dans l'ordre 
#de la requete
sub DBFieldOrder {
    my ($self) = @_;
    return @{$self->{sth}->{NAME}};
}

#execution d'une requete (preparée ou non)
sub DBQuery {
    my ($self, $query, @params) = @_;  
    
    $self->{sth} = $self->{dbh}->prepare_cached($query)|| die $self->{dbh}->errstr;
    $self->{sth}->execute(@params) || die $self->{dbh}->errstr;    
    $query=~s/\s+//g;
    if (uc $query=~ m/^SELECT/i) {            
    }    
    else {
        $self->{sth}->finish;    
        return 1;
    }
    return 0;
}

sub DBCommit {
    my ( $self ) = @_;
    $self->{dbh}->commit;
}

sub DBRollback {
    my ( $self ) = @_;
    $self->{dbh}->rollback;
}

sub DBClose {
    my ( $self ) = @_;
    $self->{dbh}->disconnect;
}


# OUTILS GENERAUX ############################
#creation d'une instance de log
sub LogNew {
    my ($class, $log) = @_;
    use File::Basename;

    $log = "logs/".basename($log) if ($log);
    $log = "logs/$0.log" if (!$log);

    my $self = bless {
        log => $log,        
    }, $class;

    open( my $hdl, '>', $self->{log} );
    print $hdl "[".Timestamp()."] *** initialisation du log $0 ***\n";
    close($hdl);
    return $self;
}

sub WriteLog {
    my ($self, $l) = @_;    
    open( my $hdl, '>>', $self->{log} );
    print $hdl "[".Timestamp()."] $l\n";
    close($hdl);
}

sub CloseLog {
    my ($self) = @_;    
    open( my $hdl, '>>', $self->{log} );
    print $hdl "[".Timestamp()."] *** fermeture du log $0 ***\n";
    close($hdl);   
}

#creation d'une instance de gestion de config (type INI)
sub NewConfParser {
    my ($class, $cfg) = @_;
    use File::Basename;
    use Text::ParseWords;

    my %config;

    $cfg = "conf/".basename($cfg) if ($cfg);
    $cfg = "conf/$0.cfg" if (!$cfg);

    my $self = bless {
        file => $cfg,    
        conf => \%config
    }, $class;

    my $Section = ""; #section vide par d?faut
    my %KeyVal;

    open( my $conf_hfr, '<', $self->{file} );
    while ( <$conf_hfr> ){
        chomp;
        if ( $_=~m/\[(.*)\]/ ) {
            $Section= $1;
            %KeyVal=();
            %{$self->{cfg}{$Section}}=();
        }
        else {
            #on ne split que sur la 1ere occurence du caract?re "="
            #les autres occurences doivent ?tre lues et renvoy?es par $this->read( x, x )
            
            my @linetab = &parse_line( "=", 1, $_ );
            if ( @linetab ){
                my $newline = "";
                my $i=0;
                foreach my $occur ( @linetab ) {
                    if ($i and $occur) {
                        $newline.=$occur.'=';
                    }
                    $i+=1;
                }                          
                $newline = substr( $newline, 0, length( $newline )-1 );
                $KeyVal{$linetab[0]} = $newline;
            }
        }
        %{$self->{cfg}{$Section}} = ( %KeyVal );
    }
    undef %KeyVal;
    close($conf_hfr);
 
    return $self; 
}

sub ConfRead {     
    my ($self, $section, $key, $defaut ) = @_;
    my $value;

    if (exists $self->{cfg}{$section}) {
        #print "$section OK\n";
        my %KeyVal = %{$self->{cfg}{$section}};
        
        if (exists $KeyVal{$key}) {
            $value = $KeyVal{$key};
        }
        else {
            print "contenu de la section $section inconnu\n";
        }
        undef %KeyVal;
    } 
    else {
        die "section inconnue : ".$section."\n";
    }
    
    if ((!($value)) and ($defaut)) {
        $value = $defaut;
    }
    return $value;
}

sub ConfDisplay {
    my ( $self ) = @_;
    foreach my $section (keys %{$self->{cfg}}){
        print "SECTION: ".$section."\n";
        my %KeyVal = %{$self->{cfg}{$section}};
        foreach my $key (keys %KeyVal){
            print $key." => ". $KeyVal{$key}."\n";
        }
        print "-------------------------\n\n";
    }
}


#horodatage
sub Timestamp {
    my ($format) = @_;
    $format = "%d/%m/%Y %H:%M:%S" if (!$format);
    return &POSIX::strftime( $format, localtime() )
}


1;
