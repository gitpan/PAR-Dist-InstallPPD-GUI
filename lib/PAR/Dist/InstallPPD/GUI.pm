package PAR::Dist::InstallPPD::GUI;
use strict;
use warnings;

our $VERSION = '0.02';

use File::Spec;
use Config::IniFiles;
use Tk;
use Tk::NoteBook;
use Tk::ROText;
use IPC::Run ();

use File::UserConfig ();
use PAR::Dist::FromPPD ();

sub new {
	my $proto = shift;
	my $class = ref($proto)||$proto;

	my $cfgdir = File::UserConfig->new(
		dist     => 'PAR-Dist-InstallPPD-GUI',
		module   => 'PAR::Dist::InstallPPD::GUI',
		dirname  => '.PAR-Dist-InstallPPD-GUI',
#		sharedir => 'PARInstallPPDGUI',
	)->configdir();
    my $cfgfile = File::Spec->catfile($cfgdir, 'config.ini');
    chmod(oct('644'), $cfgfile);

    if (not -f $cfgfile) {
        require File::Path;
        File::Path::mkpath($cfgdir);
        open my $fh, '>', $cfgfile
          or die "Could not open configuration file: $!";
        print $fh <DATA>;
        close $fh;
    }
	tie my %cfg => 'Config::IniFiles', -file => $cfgfile;

	my $self = bless {
		urientry => undef,
		ppduri => $cfg{main}{ppduri},
		verbose => $cfg{main}{verbose},
		shouldwrap => $cfg{main}{shouldwrap},
		parinstallppd => $cfg{main}{parinstallppd},
		saregex => $cfg{main}{saregex},
		spregex => $cfg{main}{spregex},
		resulttext => '',
	} => $class;
	$self->{cfg} = \%cfg;
	
	my $mw = MainWindow->new();
	$mw->geometry( "800x600" );
	eval { # eval, in case fonts already exist
		$mw->fontCreate(qw/C_normal  -family courier   -size 10/);
		$mw->fontCreate(qw/C_bold    -family courier   -size 10 -weight bold/);
	};
	my $nb = $mw->NoteBook()->pack( -fill=>'both', -expand=>1 );

	my @tabs;
	push @tabs, $nb->add( "welcome",  -label => "Welcome" );
	push @tabs, $nb->add( "install",  -label => "Install" );
	push @tabs, $nb->add( "config", -label => "Configuration" );

	$tabs[0]->Label( -text=>"Welcome to PAR-Install-PPD-GUI!" )->pack( );

	$self->{tabs} = \@tabs;
	$self->_init_install_tab();
	$self->_init_config_tab();

	return $self;
}	

sub _init_install_tab {
	my $self = shift;
	my $tabs = $self->{tabs};
	my $fr = $tabs->[1]->Frame()->pack(qw/-side top -fill both/);

	my $urifr = $fr->Frame()->pack(qw/-side top -fill x/);
	$urifr->Label(qw/-text/, "PPD URI: ")->pack(qw/-side left -ipady 10/);
	$self->{urientry} = $urifr->Entry(
		qw/-width 70 -textvariable/, \$self->{ppduri}
	)->pack(qw/-side left -ipadx 10/);

    # view button
	$urifr->Button(
		qw/-text View -command/, [$self, '_view_ppd'],
	)->pack(qw/-side left -padx 5/);

    # install button
	$urifr->Button(
		qw/-text Install -command/, [$self, '_start_installation'],
	)->pack(qw/-side left -padx 5/);

	my $resultfr = $fr->Frame()->pack(qw/-side top -fill both/);

	my $tframe = $resultfr->Frame()->pack(qw/-side top -fill x/);
	$tframe->Label(qw/-text/, "Results:")->pack(qw/-side left/);
	$tframe->Checkbutton(
		qw/-text/, "Wrap Lines",
		qw/-variable/, \$self->{shouldwrap},
		qw/-command/, [$self, '_wrap_toggle'],
	)->pack(qw/-side left -padx 3/);
	$tframe->Checkbutton(
		qw/-text/, "Verbose Output",
		qw/-variable/, \$self->{verbose},
	)->pack(qw/-side left -padx 3/);

	$self->{resulttext} = $resultfr->Scrolled(
		qw/ROText -scrollbars osoe -background white/
	)->pack(qw/-side top -fill both -padx 5/);
	$self->{resulttext}->tag(qw/configure output -foreground black -font C_normal/);
	$self->{resulttext}->tag(qw/configure error -foreground red -font C_bold/);

    $self->_wrap_toggle();
}

sub _init_config_tab {
	my $self = shift;
	my $tabs = $self->{tabs};
	my $fr = $tabs->[2]->Frame()->pack(qw/-side top -fill both/);

	$self->_make_entry($fr, '"parinstallppd" command:', $self->{parinstallppd});
	$self->_make_entry($fr, '--selectarch Regular Expression (leave blank for default):', $self->{saregex});
	$self->_make_entry($fr, '--selectperl Regular Expression (leave blank for default):', $self->{spregex});

}

sub _make_entry {
	my $self = shift;
	my $frame = shift;
	my $label = shift;
	my $ref = shift;
	my $width = shift||80;

	my $fr = $frame->Frame()->pack(qw/-side top -fill x -pady 3/);
	$fr->Label(qw/-text/, $label.' ')->pack(qw/-side left/);
	return $fr->Entry(-width => $width, -textvariable => $ref)->pack(qw/-side left -fill x/);
}

sub run {
	MainLoop;
}

sub _view_ppd {
    my $self = shift;
    my $ppduri = $self->{ppduri};

    my $ppd;
    eval {
        $ppd = PAR::Dist::FromPPD::get_ppd_content($ppduri);
    };

    $self->_reset_resulttext();
    if ($@) {
        $self->_warn_resulttext("Error: $@");
    }
    elsif (not defined $ppd) {
        $self->_warn_resulttext("Error: Could not get PPD");
    }
    else {
        $self->_print_resulttext($ppd);
    }
}

sub _reset_resulttext {
    my $self = shift;
    $self->{resulttext}->Contents('');
	$self->{resulttext}->insert('0.0', '');
}

sub _print_resulttext {
    my $self = shift;
    my $text = shift;
    $self->{resulttext}->insert('insert', $text, 'output');
}

sub _warn_resulttext {
    my $self = shift;
    my $text = shift;
    $self->{resulttext}->insert('insert', $text, 'error');
}

sub _start_installation {
	my $self = shift;
	my $uri = $self->{ppduri};
	my @call = ($self->{parinstallppd}, '--uri', $self->{ppduri});
	push @call, '--verbose' if $self->{verbose};

	if (defined $self->{saregex} and $self->{saregex} =~ /\S/) {
		push @call, '--selectarch', $self->{saregex};
	}
	if (defined $self->{spregex} and $self->{spregex} =~ /\S/) {
		push @call, '--selectperl', $self->{spregex};
	}

	$self->_reset_resulttext();
	my $update_out = sub{
        $self->_print_resulttext(join "", @_);
	};
	my $update_err = sub{
        $self->_warn_resulttext(join "", @_);
	};
	IPC::Run::run(\@call, \undef, $update_out, $update_err);
}

sub _wrap_on {
	my $self = shift;
	$self->{resulttext}->configure(
		qw/-wrap word/
	);
}

sub _wrap_off {
	my $self = shift;
	$self->{resulttext}->configure(
		qw/-wrap none/
	);
}

sub _wrap_toggle {
	my $self = shift;
	if ($self->{shouldwrap}) { $self->_wrap_on()  }
	else                      { $self->_wrap_off() }
}


sub _save_config {
	my $self = shift;
	my $cfg = $self->{cfg};
	$cfg->{main}{verbose} = $self->{verbose} || 0;
	$cfg->{main}{ppduri} = $self->{ppduri} || 'http://';
	$cfg->{main}{shouldwrap} = $self->{shouldwrap} || 0;
	$cfg->{main}{parinstallppd} = $self->{parinstallppd} || 'parinstallppd';
	$cfg->{main}{spregex} = $self->{spregex} || '';
	$cfg->{main}{saregex} = $self->{saregex} || '';
	tied(%$cfg)->RewriteConfig();
}

sub DESTROY {
	my $self = shift;
	$self->_save_config();
}

1;

=head1 NAME

PAR::Dist::InstallPPD::GUI - GUI frontend for PAR::Dist::InstallPPD

=head1 SYNOPSIS

  use PAR::Dist::InstallPPD::GUI;
  my $gui = PAR::Dist::InstallPPD::GUI->new();
  $gui->run();

=head1 DESCRIPTION

This module implements a Tk GUI front-end to the L<PAR::Dist::InstallPPD>
module's C<parinstallppd> command. You will generally want to use the
C<parinstallppdgui> command instead of using this module.

The interface to C<parinstallppd> isn't done in code via an API.
Instead C<parinstallppdgui> uses L<IPC::Run> to run C<parinstallppd>.

=head1 SEE ALSO

L<PAR::Dist::InstallPPD>, L<IPC::Run>, L<File::UserConfig>, L<Tk>

PAR has a mailing list, <par@perl.org>, that you can write to; send an empty mail to <par-subscribe@perl.org> to join the list and participate in the discussion.

Please send bug reports to <bug-par-dist-installppd-gui@rt.cpan.org>.

The official PAR website may be of help, too: http://par.perl.org

For details on the I<Perl Package Manager>, please refer to ActiveState's
website at L<http://activestate.com>.

=head1 AUTHOR

Steffen Mueller, E<lt>smueller at cpan dot orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.6 or,
at your option, any later version of Perl 5 you may have available.

=cut

__DATA__
# default config
[main]
parinstallppd=parinstallppd
ppduri=http://
verbose=0
shouldwrap=0
saregex=
spregex=

