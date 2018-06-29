#!/usr/bin/perl
#######################

package ConfigParser;

use strict;
use warnings;
use Text::ParseWords;


#crée une instance de la classe à partir du fichier ini
#param : FichierIni
#si le fichier n'existe pas, un fichier vide sera créé.
sub new {
    my ( $class, $ConfFile ) = @_; 
    my %config = ();    
    
    my $self = bless {
        file => $ConfFile,        
        cfg => \%config }, $class;    
    
    my $Section = ""; #section vide par défaut
    my %KeyVal = ();

    if (!(-e $self->{file})){
        print "[ERREUR] le fichier de configuration n'existe pas !\n";
        print "[INFO] création du fichier de configuration vide !\n";
        open( my $conf_hfw, ">:encoding( UTF-8 )", $self->{file});
        close($conf_hfw);
        undef $conf_hfw;
    }

    open( my $conf_hfr, "<:encoding( UTF-8 )", $self->{file} );
    while ( <$conf_hfr> ){
        chomp;
        if ( $_=~m/\[(.*)\]/ ) {
            $Section= $1;
            %KeyVal = (); #nouvelle section, on vide KeyVal
            %{$self->{cfg}{$Section}}=();
        }
        else {
            #on ne split que sur la 1ere occurence du caractère "="
            #les autres occurences doivent être lues et renvoyées par $this->read( x, x )
            
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



#réécrit l'ensemble du dictionnaire %config dans le fichier en apportant les modifications demandées.
#params : section (existante ou nouvelle)
#         clé (existante ou nouvelle)
#         valeur (nouvelle)
sub write{
    my ( $self, $section, $key, $value ) = @_;
        
    if ( exists $self->{cfg}{$section}) {
        
        #print "la section $section existe !\n";
        my %KeyVal = %{$self->{cfg}{$section}};
        my $found = 0;
        foreach my $k (keys %KeyVal) {
            if ( $k eq $key ) {
                $KeyVal{$key} = $value; #mise a jour de la valeur de la clé existante
                $found = 1;
            }
        }
        if ($found == 0) {
            $KeyVal{$key} = $value; #création de la nouvelle clé
        }
        
        %{$self->{cfg}{$section}} = (%KeyVal);
        undef %KeyVal;
    }
    
    else {
        %{$self->{cfg}{$section}} = ();
        my %KeyVal = ( $key => $value ); #creation de la nouvelle section
        %{$self->{cfg}{$section}} = ( %KeyVal );
        undef %KeyVal;
    }
    
    #réécriture du fichier
    open( my $hfw_conf, ">", $self->{file} );
    
    foreach my $SaveSection ( sort keys %{$self->{cfg}} ) {
        my %KeyVal = %{$self->{cfg}{$SaveSection}};
        foreach my $SaveKey ( sort keys %KeyVal ) {
            print $hfw_conf $SaveKey."=".$KeyVal{$SaveKey}."\n";
        }
        undef %KeyVal;        
    }
    close($hfw_conf);
}

#affiche le contenu du dictionnaire %config (debug)
sub display{
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

#permet d'accéder à la valeur d'une clé pour une section donnée
#params : section existante
#         clé existante
#         valeur par défaut (optionnelle)
sub read{ 
    my $value;
    my ($self, $section, $key, $defaut ) = @_;

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

1;