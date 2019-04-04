#!/usr/bin/perl
#_*_ coding: iso-8859-15 _*_

use strict;
use warnings;
use DBI;
use DBD::Oracle;
use POSIX;

package fwk;

our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw(Timestamp Line2Hash StrTrim);
our %EXPORT_TAGS = ( ALL => [ @EXPORT_OK, @EXPORT ] );

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
sub Log {
    my ($class, $log) = @_;

    $log = "logs/".$0.".".Timestamp("%d%m%Y_%H%M%S").".log" if (!$log);

    my $self = bless {
        log => $log,
    }, $class;

    open( my $hdl, '>', $self->{log} );
    print $hdl "[".Timestamp()."] *** initialisation du log $0 ***\n";
    close($hdl);
    return $self;
}

sub LogWrite {
    my ($self, $l) = @_;
    open( my $hdl, '>>', $self->{log} );
    print $hdl "[".Timestamp()."] $l\n";
    close($hdl);
}

sub LogClose {
    my ($self) = @_;
    open( my $hdl, '>>', $self->{log} );
    print $hdl "[".Timestamp()."] *** fermeture du log $0 ***\n";
    close($hdl);
}

#creation d'une instance de gestion de config (type INI)
sub ConfigParser {
    my ($class, $cfg) = @_;
    use Text::ParseWords;

    my %config;
    $cfg = "conf/$0.cfg" if (!$cfg);

    my $self = bless {
        file => $cfg,
        conf => \%config
    }, $class;

    my $Section = ""; #section vide par défaut
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

sub ConfigRead {
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


sub ConfigWrite {
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

sub ConfigDisplay {
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

#gestionnaire de parametres lignes de commande
sub OptionParser {
    my ( $class ) = @_;
    my %Options = ( "-h" => "--help" );
    my %Descrip = ( "-h" => "affiche tous les parametres disponibles pour ce programme" );
    my %OptType = ( "-h" => 0 );
    my %OptValu = ();
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

sub OptionAdd {
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

sub OptionParse {
    my ( $self, @tabargs ) = @_;
    @tabargs = @ARGV if (! @tabargs);
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

sub OptionFindValue {
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

sub OptionGet {
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

#lecture-ecriture de fichier syntaxe python
#r = read, a = append, w = write, [raw]b = binary
sub FOpen {
    my ( $class, $file, $mode, $encoding ) = @_;
    my ($handle, $perlmode);

    #par defaut, mode lecture
    $perlmode = "<";
    $perlmode = ">" if ($mode eq "w" || $mode eq "wb");
    $perlmode = ">>" if ($mode eq "a" || $mode eq "ab");
    $perlmode = "<" if ($mode eq "r" || $mode eq "rb");

    $encoding = ":encoding( $encoding )" if ($encoding);

    open( $handle, "$perlmode$encoding", $file);

    my $self = bless {
        file => $file,
        phdl => $handle,
        codi => $encoding,
        mode => $mode,
    }, $class;

    return $self;
}

sub FHandle {
    my ( $self ) = @_;
    return $self->{phdl};
}

sub FWrite {
    my ($self, $line) = @_;
    print $self->{phdl} $line;
}

sub FClose {
    my ( $self ) = @_;
    close( $self->{phdl} );
}

################################################
#horodatage
sub Timestamp {
    my ($format) = @_;
    $format = "%d/%m/%Y %H:%M:%S" if (!$format);
    return &POSIX::strftime( $format, localtime() )
}

################################################
# conversion l'une ligne de fichier CSV en hashtable
sub CSVLine2Hash {
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

################################################
#trim espaces
sub StrTrim {
    my $s = shift;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

1;
