#!/usr/bin/perl
#######################
#FG 08/06/2018 

package OptionParser;

use strict;
use warnings;

#initialisation de la classe
sub new {
    my ( $class ) = @_;
    
    # valeurs par défaut
    # -h est une option reservée pour l'aide du programme utilisant la librairie OptionParser.
    
    # tous les hash contiennent l'argument "court" en clé sauf OptOrder 
    # OptOrder contient en clé sa position de déclaration et en valeur l'argument "court".
        
    # hash Options contenant l'argument "long"
    my %Options = ( "-h" => "--help" );
    
    # hash Descrip contenant le descriptif de l'option
    my %Descrip = ( "-h" => "affiche tous les parametres disponibles pour ce programme" );
    
    # hash OptType contenant le type "store" attendu
    # 0 n'attend pas de paramètre supplémentaire ( store true )
    # 1 prends une chaine supplémentaire comme paramètre ( store value )
    my %OptType = ( "-h" => 0 ); 

    # hash contenant les valeures définies (1 ou la chaine en parametres)
    # pas de valeur nécessaire pour -h
    my %OptValu = ();   
    
    # le hash optorder sert à conserver l'ordre de déclaration  
    # des options pour l'appel du programme avec le paramètre -h
    my %OptOrder = ( 0 => "-h" ); 
    
    my $self = bless {
    options => \%Options,
    descrip => \%Descrip,
    opttype => \%OptType,
    optvalu => \%OptValu,
    optorder => \%OptOrder
    }, $class;    
        
    return $self;
}

#permet d'acceder aux valeures stockées dans %OptValu
sub opt {    
    my ( $self, $opt ) = @_;
    my $result = "";
    
    #teste la valeur du hash %OptValu
    if (exists $self->{optvalu}{$opt}) {
        $result = $self->{optvalu}{$opt};
    }
    else {
        # pas de valeur dans le hash %OptValu, verifie que l'argument 
        # est bien déclaré dans le hash %Options
        if (!(exists $self->{options}{$opt})) {
            print "[ERREUR] l'argument $opt n'est pas defini\n";
            exit(0);
        }
    }
    return $result;
}

#trouve la clé depuis une valeur dans un hash
sub find_value {
    my ($self, $key ) = @_;
          
    foreach my $k ( %{$self->{options}} ) {        
        if ($self->{options}{$k}){
            if ($self->{options}{$k} eq $key) {
                return $k;
            }
        }
    }
    return undef;
}

#ajouter une option dans les hash %Options %Descrip et %OptType
sub add {
    my ( $self, $opt, $optlong, $desc, $type ) = @_;
    
    if ($opt eq "-h") {
        die "ERREUR: -h est un argument reserve !\n";
    }
    
    #par défaut, la valeur de %OptType sera store_true
    if(!( $type )){
        $type = 0;
    }
    
    $self->{options}{$opt} = $optlong;
    $self->{descrip}{$opt} = $desc;
    $self->{opttype}{$opt} = $type;
    
    # on récupère la position de l'argument dans le hash %OptOrder
    my $len = keys(%{$self->{options}}) + 1;

    $self->{optorder}{$len} = $opt; 
}

#construit le hash %OptValu depuis les parametres du script
sub parse {
    my ( $self, @tabargs ) = @_;
    my $tablen = @tabargs;
    my $current_arg;
    my $memo_arg="";
    
    for (my $i=0;$i<$tablen;$i++){   
    
        $current_arg = $tabargs[$i];        
                
        if (!(exists $self->{options}{$current_arg})) {
            $memo_arg = $current_arg;
            $current_arg = find_value( $self, $current_arg );            
        }
        if (!($current_arg eq '0')) {
            if (exists $self->{opttype}{$current_arg} and $self->{opttype}{$current_arg} == 1) {
                $i++;
                if ($i>=$tablen) {
                    print "[ERREUR] parametre manquant pour l'argument ".$current_arg."\n";
                    exit(0);
                }
                
                $self->{optvalu}{$current_arg} = $tabargs[$i];
            }            
            else {                
                $self->{optvalu}{$current_arg} = 1;                
            }
        }      
        else {
            print "[ERREUR] l'argument ".$memo_arg." n'est pas defini.\n";
            print "[ERREUR] affichez l'aide du programme avec le parametre -h\n";
            exit(0);
        }
        
        # *** on détecte l'appel de l'argument -h / --help ***
        if ($current_arg eq "-h") {
            
            print "[INFO] Options du programme :\n";
            
            # on s'assure de l'ordre de déclaration des paramètres.
            foreach my $order ( sort {$a<=>$b} keys %{$self->{optorder}} ) {
                
                # la clé de tous les hash correspond à la valeur du hash %OptOrder
                my $cle = $self->{optorder}{$order};           
                    
                # affiche l'aide 
                #         -h    --help    affiche tous les parametres disponibles pour ce programme
                print "  ".$cle."\t".$self->{options}{$cle}."\t".$self->{descrip}{$cle}."\n";                                
            }            
            
            print "[INFO] fin du programme.\n";
            exit(0);
        }
    }
}

1;