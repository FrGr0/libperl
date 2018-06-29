#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use DBI;
use DBD::Oracle;

package DBTools;
##################################
=pod *** exemple de requêtes/fonctions oracle ***

$dbh->DBQuery( "select ".$dbschema.".SELECT_NEXT_SEQUENCE from dual" );
foreach $RowList ( $dbh->DBFetchAll ) {
    foreach $row ( @{$RowList} ) {
        foreach $field ( %{$row} ) {
            if ($$row{$field}) {
                print $field." --> ".$$row{$field}."\n";
            }
        }
    }
}


* pour écrire directement les résultats dans un fichier >>

$dbh->DBQuery( "select * from machin" );
$compteur = $dbh->DBFetchAll( $Fichier, $Separateur (optionnel) );

=cut
=pod *** exemple d'appel de procédure oracle ***
my $FetchAll = $dbh->DBQProcFetchAll( $dbschema.".dbi_test_fg.SP_GET_CODE_INT_VTE_GOLD( '799004' , '0', :ret )" );
foreach $row ( @{$FetchAll} ) {
    foreach $field (%{$row}) {
        if ($$row{$field}) {
            print $field." --> ".$$row{$field}."\n";
        }
    }
}

* pour écrire directement dans un fichier >>

$compteur = $dbh->DBQProcFetchAll( $dbschema.".dbi_test_fg.SP_GET_CODE_INT_VTE_GOLD( '799004' , '0', :ret )", $Fichier, $Separateur(optionnel) );

=cut 


#création d'une instance de la classe DBTools
sub new {
    my ( $class, $hfw_log ) = @_;
    my ($dbh, $sth);
    
    my $self = bless {
        dbh => $dbh,        
        sth => $sth,        
        hlg => $hfw_log,
    }, $class;
    
    return $self;
}

#creation de la connexion à la BDD
sub DBConnect {
    my ( $self, $host, $name, $user, $pass, $port ) = @_;    
    my $connexionstr = sprintf( "dbi:Oracle:host=%s;port=%s;sid=%s" , $host, $port, $name );
    my %dbattr = (
                PrintError => 0,
                RaiseError => 1,
                AutoCommit => 0,
            );
             
    $self->{dbh} = DBI->connect( $connexionstr, $user, $pass, \%dbattr ) or RaiseError(DBI->errstr);
    return $self;
}

#execute une requête sql... utiliser DBFetchAll pour retourner les résultats d'un select
#rien a faire pour insert/update/create... a part commit si autocommit est désactivé
sub DBQuery {
    my ($self, $query ) = @_;  
    
    $self->{sth} = $self->{dbh}->prepare( $query )|| die $self->{dbh}->errstr;
    $self->{sth}->execute || die $self->{dbh}->errstr;    
    if ($query=~ m/^SELECT/i) {            
    }    
    else {
        $self->{sth}->finish;    
    }
}

#retourne un array de hash, ou le nombre de lignes si écriture directe dans un fichier (en fonction du 1er paramètre)
#$hdb->Query( "select * from toto" );
#$num_rows = $hdb->FetchAll( 'toto.txt' ); --> écriture du résultat dans toto.txt, retour du nombre de lignes
#$FetchAll = $hdb->FetchAll; --> retourne l'array de hash
sub DBFetchAll {
    my ( $self, $filename, $separator ) = @_;
    my @rowtab = ();
    my $row;    
    
    #pour écriture du fichier si précisé
    my $hfw;
    
    if ($filename) {
        
        if (!( $separator )) {
            $separator = ";";
        }        
        
        open( $hfw, ">:encoding( UTF-8 )", $filename );
    }
    
    my $rownum = 0;
    my %roworder = ();
    
    while( $row = $self->{sth}->fetchrow_hashref() ) {
        
        #foreach $field ( %{$row} )
        
        if ($hfw){
            $rownum = DBWriteRowToFile( $self, $row, $rownum, $hfw, $separator );
        }
        
        else {
            push @rowtab, $row;
        }
        
    }
    $self->{sth}->finish;        
        
    if ($filename) {
        close( $hfw );
        return $rownum;
    }
    
    return \@rowtab;
}

sub DBFunc {
    my ( $self, $query ) = @_;
    my $fullquery = "begin\n   :VRETURN := ".$query.";\nEND;";
    $self->{sth} = $self->{dbh}->prepare( $fullquery )|| die $self->{dbh}->errstr;    
    my $retcode;
    $self->{sth}->bind_param_inout(":VRETURN", \$retcode, 2048000);
    $self->{sth}->execute || die  $self->{dbh}->errstr;    
    $self->{sth}->finish;
    return $retcode;
}


sub WRITE_LOG {
    my ( $self, $prog, $idmsg, $nivmsg, $msg, $pkg ) = @_;    

=pod    
    my  $query = "begin\n   :VRETURN := GBAOWN1.PKG_GBA_UTILS.FC_WRITE_LOG( '".$0."', '".$idmsg."', '".$nivmsg."', '".$msg."', '".$pkg."', 'BATCH_GBA' );\nEND;";
    $self->{sth} = $self->{dbh}->prepare( $query )|| die $self->{dbh}->errstr;    
    my $retcode;
    $self->{sth}->bind_param_inout(":VRETURN", \$retcode, 2048000);
    $self->{sth}->execute || die  $self->{dbh}->errstr;    
    $self->{sth}->finish;
=cut 

    my $retcode;
    DBFunc( $self, "GBAOWN1.PKG_GBA_UTILS.FC_WRITE_LOG( '".$0."', ".$idmsg.", '".$nivmsg."', '".$msg."', '".$pkg."', 'BATCHGBA' )" );
    return $retcode;
}



#execute une procedure stockée retournant un résultat, le paramètre de retour est détecté par une regex
#retourne un array de hash, ou le nombre de lignes si écriture directe dans un fichier (en fonction du 2em paramètre)
#possibilité d'indiquer un séparateur précis (3em paramètre optionnel, ";" par défaut)
#$num_rows = $hdb->DBQProcFetchAll( "GBAOWN1.DBI_TEST_FG.MA_PROCEDURE( :ret )", "toto.txt" ); --> écriture du résultat dans toto.txt, retour du nombre de lignes
#$FetchAll = $hdb->DBQProcFetchAll( "GBAOWN1.DBI_TEST_FG.MA_PROCEDURE( :ret )" ); --> retourne l'array de hash
sub DBQProcFetchAll { 
    use DBD::Oracle qw(:ora_types);
    use GenTools qw(StrTrim);
    
    no strict;
    
    my ($self, $funct, $filename, $separator ) = @_;    
      
    
    #pour écriture du fichier si précisé
    my $hfw;
        
    if ($filename) {
    
        if (!( $separator )) {
            $separator = ";";
        }        
        
        open( $hfw, ">:encoding( UTF-8 )", $filename );
    }
    
    #détection du paramètre de retour pour la procédure.
    my $ret_param = ":ret"; #par défaut
    if ( $funct=~ m/(\:.*)\)/ ) {
        $ret_param = &StrTrim($1);
    }
        
    my $functfull = "BEGIN\n    ".$funct.";\nEND;";      
    my $rc; 
    
    $self->{sth} = $self->{dbh}->prepare( $functfull )  || die $self->{dbh}->errstr ;    
    $self->{sth}->bind_param_inout($ret_param, \$rc, 0, { ora_type => ORA_RSET } ) || die $self->{dbh}->errstr;
    $self->{sth}->execute || die  $self->{dbh}->errstr;
    
    my $row;    
    my @rowtab = (); 
    my $rownum = 0;
    while( $row = $rc->fetchrow_hashref() ) {
        
        if ($hfw) {
            $rownum = DBWriteRowToFile( $self, $row, $rownum, $hfw, $separator  );
        }
        else {
            push @rowtab, $row;      
        }
    }      
    $self->{sth}->finish;    
    
    if ($filename) {
        close( $hfw );
        return $rownum;
    }
    
    return \@rowtab;
}


#execute une fonction oracle retournant un cur, le paramètre de retour est détecté par une regex
#retourne un array de hash, ou le nombre de lignes si écriture directe dans un fichier (en fonction du 2em paramètre)
#possibilité d'indiquer un séparateur précis (3em paramètre optionnel, ";" par défaut)
#$num_rows = $hdb->DBQProcFetchAll( "GBAOWN1.DBI_TEST_FG.MA_PROCEDURE( :ret )", "toto.txt" ); --> écriture du résultat dans toto.txt, retour du nombre de lignes
#$FetchAll = $hdb->DBQProcFetchAll( "GBAOWN1.DBI_TEST_FG.MA_PROCEDURE( :ret )" ); --> retourne l'array de hash
sub DBFuncFetchAll { 
    use DBD::Oracle qw(:ora_types);
    use GenTools qw(StrTrim);
    
    no strict;
    
    my ($self, $funct, $filename, $separator ) = @_;    
      
    
    #pour écriture du fichier si précisé
    my $hfw;
        
    if ($filename) {
    
        if (!( $separator )) {
            $separator = ";";
        }        
        
        open( $hfw, ">:encoding( UTF-8 )", $filename );
    }
    
    #détection du paramètre de retour pour la procédure.
    my $ret_param = ":ret"; #par défaut
    if ( $funct=~ m/(\:.*)\s?\:\=.*/ ) {
        $ret_param = &StrTrim($1);
    }
        
    my $functfull = "BEGIN\n    ".$ret_param." := ".$funct.";\nEND;";      
    my $rc; 
    
    $self->{sth} = $self->{dbh}->prepare( $functfull )  || die $self->{dbh}->errstr ;    
    $self->{sth}->bind_param_inout($ret_param, \$rc, 0, { ora_type => ORA_RSET } ) || die $self->{dbh}->errstr;
    $self->{sth}->execute || die  $self->{dbh}->errstr;
    
    my $row;    
    my @rowtab = (); 
    my $rownum = 0;
    while( $row = $rc->fetchrow_hashref() ) {
        
        if ($hfw) {
            $rownum = DBWriteRowToFile( $self, $row, $rownum, $hfw, $separator  );
        }
        else {
            push @rowtab, $row;      
        }
    }      
    $self->{sth}->finish;    
    
    if ($filename) {
        close( $hfw );
        return $rownum;
    }
    
    return \@rowtab;
}











#ecriture dans les fichiers depuis l'appel DBQProcFetchAll et DBFetchAll
sub DBWriteRowToFile {
    my ( $self, $row, $rownum, $filehandle, $separator ) = @_;
    no strict;
    
    my $line = "";    
    my $header = "";
    my $fieldval;
    
    foreach my $key ( sort keys %{$row} )
    {
        $fieldval = "";
        if (exists $$row{$key} and $$row{$key}){
            $fieldval = $$row{$key};
        }        
                
        if (!($rownum)){ 
            $header.=$key.$separator;
        }
        
        $line.=$fieldval.$separator;
    }
    if (!($rownum)){ 
        print $filehandle $header."\n";
    }
    print $filehandle $line."\n";
    $rownum+=1;
    
    return $rownum;
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

1;