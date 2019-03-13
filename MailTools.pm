#!/usr/bin/perl
#####################################################################
#### envoi de mail utilisant uniquement les modules core de perl ####
#### FGros 06112018                                              ####
#####################################################################

use strict;
use warnings;
use File::Basename; #module core
use Net::SMTP;      #module core
use MIME::Base64;   #module core

package MailTools;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(SendMail AuthMail);

my %h_MailAuth;

sub GetMIMEType {
    my ($file)=@_;
    my ($ext) = $file =~ /\.([^.]+)$/;
    my ( $fh, $ret );
    open( $fh, "<", "./lib/MIMETypes.dat" );
    while ( <$fh> ) {
        chomp;
        my ( $k, $v ) = split( /;/, $_ );
        if (uc($k) eq uc($ext)) {
            $ret = $v;
            last;
        }
    }
    close( $fh );
    return $ret;
}

sub AuthMail {
    my ( $host, $user, $pwd ) = @_;
    $h_MailAuth{ "host" } = $host;
    $h_MailAuth{ "user" } = $user;
    $h_MailAuth{ "pwd"  } = $pwd;
}

sub SendMail {
    my ( 
        $from,          #emetteur
        $to,            #destinataire(s) séparateur ;
        $cc,            #carbon copy, séparateur ;
        $cci,           #carbon copy invisible, séparateur ;
        $objet,         #objet du mail
        $HTMLbody,      #corps du msg en html
        @piecesJointes  #liste de chemins complets vers les pièces jointes
    ) = @_;
    my %attachContent;
    my @textFile;

    #transforme la liste des pièces jointes en hashtable : 
    #clé : le nom du fichier (basename)
    #valeur : le contenu du fichier (texte brut pour CSV/TXT ou données binaires)
    if ( @piecesJointes ) {
        foreach my $pj_item ( @piecesJointes ) {
            open( DAT, "$pj_item" ) or die( "impossible d'ouvrir la PJ" );
            if ( $pj_item =~ /[\.txt|\.csv]$/i ) {
                $attachContent{ File::Basename::basename( $pj_item ) } = do { local $/; <DAT> };
            }
            else {
                binmode(DAT);
                my ( $bytesread, $buffer, $total, $data );
                while (($bytesread = sysread(DAT, $buffer, 1024)) == 1024) {
                    $total += $bytesread;
                    $data .= $buffer;
                }
                if ($bytesread) {
                    $data .= $buffer;
                    $total += $bytesread;
                }
                $attachContent{ File::Basename::basename( $pj_item ) } = $data;
            }
            close( DAT );
        }
    }
    
    #séparateur de sections.
    my $separateur = '_f_r_o_n_t_i_e_r_';
    
    #création du mail
    my $host = "SMTP";
    $host = $h_MailAuth{ "host" } if ( exists $h_MailAuth{ "host" } );

    my $smtp = Net::SMTP->new($host);

    $smtp->auth( $h_MailAuth{ "user" }, $h_MailAuth{"pwd"} ) if ( exists $h_MailAuth{ "user" } && exists $h_MailAuth{"pwd"} );

    $smtp->mail( $from );

    #ajout des destinataires
    if ( index( $to, ";" ) ) {
        foreach my $partto ( split( /;/, $to ) ) {
            if ( $partto ) {
                $smtp->to($partto);
            }
        }
    }
    else { $smtp->to($to); }
    $smtp->data();

    # header du mail.
    $smtp->datasend("Subject: $objet\n");
    $smtp->datasend("To: $to\n");
    if ( $cc ) {
        if ( index( $cc, ";" ) ) {
            foreach my $partcc ( split( /;/, $cc ) ) {
                if ( $partcc ) {
                    $smtp->datasend("CC: $partcc\n");
                }
            }
        }
        else { $smtp->datasend("CC: $cc\n"); }
    }
    if ( $cci ) {
        if ( index( $cci, ";" ) ) {
            foreach my $partcci ( split( /;/, $cci ) ) {
                if ( $partcci ) {
                    $smtp->datasend("BCC: $partcci\n");
                }
            }
        }
        else { $smtp->datasend("BCC: $cci\n"); }
    }

    #en cas d'envoi de pièces jointes
    if ( @piecesJointes ) {
        $smtp->datasend("MIME-Version: 1.0\n");
        $smtp->datasend("Content-Type: multipart/mixed;\n\tboundary=\"$separateur\"\n");
        $smtp->datasend("\n");
        $smtp->datasend("--$separateur\n");;
    }

    #début d'écriture du corps du mail
    $smtp->datasend("Content-Type: text/html\n");
    $smtp->datasend("\n");
    
    # corps du mail.
    $smtp->datasend( "$HTMLbody\n" );
    
    #pièce jointe (texte/csv/binaire)
    foreach my $keypj (keys %attachContent) {
        $smtp->datasend("--$separateur\n");

        if ( $keypj =~ /[\.txt|\.csv]$/i ) {
            $smtp->datasend("Content-Type: application/text; name=\"$keypj\"\n");
            $smtp->datasend("Content-Disposition: attachment; filename=\"$keypj\"\n");
            $smtp->datasend("\n");
            $smtp->datasend( $attachContent{$keypj}."\n" );
        }
        else {
            $smtp->datasend("Content-Type: ".GetMIMEType($keypj)."; name=\"$keypj\"\n");
            $smtp->datasend("Content-Transfer-Encoding: base64\n");
            $smtp->datasend("Content-Disposition: attachment; filename=\"$keypj\"\n");
            my $pjdata = $attachContent{$keypj};
            $smtp->datasend("\n");
            $smtp->datasend( MIME::Base64::encode_base64( $pjdata ));
        }
    }
    $smtp->datasend("\n");
    
    #fin du mail
    $smtp->dataend;

    #fermeture SMTP
    $smtp->quit;
}
1;