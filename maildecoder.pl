#!/usr/bin/perl
#
# maildecoder.pl - Yet another maildecoder based on MIME for MHonArc as an alternative to nkf -
#
# Copyright (C) 2012 "AYANOKOUZI, Ryuunosuke" <i38w7i3@yahoo.co.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Usage:
#     $ cat /path/to/maildir/hoge.eml | perl maildecoder.pl | mhonarc
#
# Reference:
#     [1] http://lists.debian.or.jp/debian-www/201202/msg00075.html
#     [2] http://lists.debian.or.jp/debian-www/201202/msg00082.html
#
use strict;
use warnings;
use Encode;
use Encode::Guess qw/shift-jis euc-jp 7bit-jis/;
use MIME::Parser;

{

    package MIME::Head;
    no warnings 'redefine';
    *decode2 = sub {
        my $self = shift;
        my $force = shift || 0;
        unless ( ( $force eq "I_NEED_TO_FIX_THIS" )
            || ( $force eq "I_KNOW_WHAT_I_AM_DOING" ) )
        {
            usage "decode is deprecated for safety";
        }
        my $wd = supported MIME::WordDecoder 'UTF-8';
        my ( $tag, $i, @decoded );
        foreach $tag ( $self->tags ) {
            @decoded = ();
            foreach ( $self->get_all($tag) ) {
                my $decoded_str = '';
                foreach ( decode_mimewords($_) ) {
                    my $str = $_->[0];
                    my $enc = defined $_->[1] ? $_->[1] : '';
                    $decoded_str .= main::decode_str( $str, $enc );
                }
                push @decoded, $decoded_str;
            }
            for ( $i = 0 ; $i < @decoded ; $i++ ) {
                $self->replace( $tag, $decoded[$i], $i );
            }
        }
        $self->{MH_Decoded} = 1;
        $self;
    };
    *MIME::Head::decode2 = \&decode2;
}

{

    package MIME::Body;
    no warnings 'redefine';
    *decode2 = sub {
        my $self    = shift;
        my $charset = shift;
        if ( defined $charset ) {
            my $decoded_str = main::decode_str( $self->as_string, $charset );
            $self->init($decoded_str);
            $self->is_encoded(1);
        }
    };
    *MIME::Body::decode2 = \&decode2;
}

{

    package MIME::Entity;
    no warnings 'redefine';
    *decode2 = sub {
        my $self = shift;
        $self->head->decode2;
        if ( $self->is_multipart ) {
            my $count = $self->parts;
            for ( my $i = 0 ; $i < $count ; $i++ ) {
                $self->parts($i)->decode2;
            }
        }
        else {
            my $charset = $self->head->mime_attr('content-type.charset');
            $self->bodyhandle->decode2($charset);
        }
    };
    *MIME::Entity::decode2 = \&decode2;
}

#{
#    package Mail::Header;
#    no warnings 'redefine';
#    *_tag_case2 = sub {
#        my $tag = shift;
#        $tag =~ s/\:$//;
#        join '-', map {
#        #    /^[b-df-hj-np-tv-z]+$|^(?:MIME|SWE|SOAP|LDAP|ID)$/i
#        #      ? uc($_)
#        #      : ucfirst( lc($_) )
#        $_} split m/\-/, $tag, -1;
#    };
#    *Mail::Header::_tag_case = \&_tag_case2
#}

sub decode_str {
    my $str         = shift;
    my $charset     = shift;
    my $output      = $main::output;
    my $decoded_str = '';
    my $decoder     = Encode::find_encoding($charset);
    if ( ref($decoder) ) {
        $decoded_str .= $output->encode( $decoder->decode($str) );
    }
    else {
        $decoder = Encode::Guess->guess($str);
        if ( ref($decoder) ) {
            $decoded_str .= $output->encode( $decoder->decode($str) );
        }
        else {
            $decoded_str .= '';    #$str;
        }
    }
    return $decoded_str;

    #return ($decoder, $decoded_str);
}

our $output = find_encoding('utf8');

my $parser = MIME::Parser->new;
$parser->output_to_core(1);

#$parser->decode_headers(0);
#$parser->decode_bodies(0);
my $entity = $parser->parse(*STDIN);

$entity->decode2;
print $entity->as_string;

exit;

__END__
