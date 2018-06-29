#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use POSIX; 

package GenTools;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(F_Timestamp Line2Hash StrTrim IsEmptyFile F_ConvMonth FindLastFile Diff);


sub F_ConvMonth {
    my ( $str_in, $rep, $tdelta ) = @_;  
        
    my %monthconv = ( "01" => "JAN", "02" => "FEB", "03" => "MAR", "04" => "APR", 
                      "05" => "MAY", "06" => "JUN", "07" => "JUL", "08" => "AUG", 
                      "09" => "SEP", "10" => "OCT", "11" => "NOV", "12" => "DEC" );
    
    if (!($tdelta)) {
        $tdelta = 0;
    }   
    
    my $month = POSIX::strftime( "%m", localtime( $tdelta ) );
    my $strmonth; 
    
    if (!($rep)) {
        $rep = "%m";
        $strmonth = $monthconv{$month};
    }       
    else {
        $strmonth = $monthconv{$rep};
    }    
    
    if ( $strmonth ) {
        $str_in=~ s/$rep/$strmonth/;      
    }
    return $str_in;
}


################################################################
# subroutine F_TimeStamp permettant un delta (en secondes) #####
# l'objet tdelta doit correspondre au format : #################
#           time()[-|+](nbsecondes); ###########################

sub F_Timestamp {
    my ( $tformat, $tdelta, $convert_month ) = @_;
    if (!($tformat)) {
        $tformat = "%d/%m/%Y %H:%M:%S"; #par defaut
    }        
    if (!($tdelta)) {
        $tdelta = time();
    }
        
    if ($convert_month) {
        $tformat = F_ConvMonth( $tformat )
    }
    my $timestamp = POSIX::strftime( $tformat, localtime( $tdelta ) );
    
    return $timestamp;
}


################################################################
# subroutine Line2Hash convertissant une ligne d'un fichier ####
# en hash. utilise la ligne d'en tête du fichier pour les clés #

sub Line2Hash {
    my ($line, $headerline, $separator) = @_;
    my %ResultSet = ();
    my $i = 0;
    
    if (!($separator)){
        $separator=';';
    }
    
    foreach my $field (split( /$separator/, $headerline )) {    
        my @splittedline = split( /$separator/, $line );
        if( $field ){ 
            $ResultSet{$field} = $splittedline[$i]; 
            $i+=1;
        }
        undef @splittedline;
    }    
    return %ResultSet;
}


#################################################################
# subroutine IsEmptyFile verifiant le contenu d'un fichier   ####

sub IsEmptyFile {
    my ( $file ) = @_;
    my $l="";
    
    open( my $testhandle, "<:encoding( UTF-8 )", $file );
    while (<$testhandle>) {
        $l=$_;
        if( $l ) {
            last;
        }
    }
    close( $testhandle );

    if ( $l ) {
        #contenu trouvé dans le fichier
        return 0;
    }
    
    #fichier vide
    return 1;
}

#################################################################
# trim ##########################################################

sub StrTrim { 
    my $s = shift; 
    $s =~ s/^\s+|\s+$//g; 
    return $s;
}


#################################################################
# find last file ################################################

sub FindLastFile { 
    my ( $section, $path_fichier, $timedelta ) = @_;
    my $nom_fichier_precedent;
    
    if( !($timedelta) ) {
        $timedelta = time();
    }
    
    #recupere le dernier fichier produit sans tenir compte de la date. 
    #
    my $search_fichier_precedent = sprintf( qw{ %s/\d{14}_%s.CSV }, $path_fichier, $section );    
    
    # on recherche le fichier précédent dans le répertoire (ignore minutes/secondes)
    my @csv_files = glob( $path_fichier."/*_".$section.".CSV" );
    my @sorted_csv_files = sort { -M $b <=> -M $a } @csv_files;
    
    foreach my $csvf (@sorted_csv_files){
        #print "CSV: ".$csvf."\n";
        
        if ( $csvf=~m/$search_fichier_precedent/ ) {
            
            if ( -e $csvf ) {
                $nom_fichier_precedent=$csvf;
                #print "TROUVE : ". $nom_fichier_precedent."\n";
                #last <- non, on laisse la boucle continuer jusqu'au dernier fichier            
            }
        }
    }
    return $nom_fichier_precedent;
}

#####################################################################
# Diff entre 2 fichiers ( fichier_ancien, fichier_récent, nouveaufichier(optionnel) )
# ressort les lignes du fichier récent absentes du fichier ancien.
#charge un tableau contenant chaque ligne du fichier
sub Diff {
    my ( $fichier_ancien, $fichier_recent, $fichier_sortie ) = @_;
       
    my @contfile1 = Load( $fichier_ancien );
    my @contfile2 = Load( $fichier_recent );
    my $hfw;
    
    open( $hfw, ">:encoding( UTF-8 )", $fichier_sortie );
    
    my $count=0;
    foreach my $line ( @contfile2 ) {     
        
        if ( $count>2 ) {
            if ( $line ) {
                #if ( grep {$_ eq $line} @contfile1 ) {                                
                print $hfw $line."\n" if (!( grep( /^(?:RE:\s*|FW:\s*)*\Q$line\E$/, @contfile1 )));                
            }
        }
        
        elsif ($count==1)  {
            if ( $line ) {
                #reporte l'en tête du fichier
                print $hfw $line."\n";
            }
        }        
        $count++;
    }    
    close( $hfw );    
}

#charge les lignes d'un fichier dans un tableau pour comparaison
sub Load {
    my ( $fichier ) = @_;
        
    if ((!($fichier)) or (!(-e $fichier))) {
        return {};
    }    
        
    open( my $hfr, '<:encoding( UTF-8 )', $fichier );
    my @return = {};
    while (<$hfr>) {
        chomp;
        push @return, $_;
    }
    close( $hfr );
    return @return;
}





1;