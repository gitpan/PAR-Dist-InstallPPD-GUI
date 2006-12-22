package PAR::Dist::InstallPPD::GUI::Installed;
use strict;
use warnings;

use ExtUtils::Installed;
use Tk::HList;
our $VERSION = '0.04';


sub _init_installed_tab {
    my $self = shift;
    my $fr = $self->{tabs}{installed}->Frame()->pack(qw/-side top -fill both -expand 1/);

    $self->{installed} = {};


    $fr->Label(-text => 'Installed modules:')->pack(qw/-side top -fill x -pady 3/);

    my $modules = $self->{installed}{modules} = $fr->Scrolled(
        'HList', qw/-scrollbars osoe/,
        qw/-columns 2 -header 1 -height 9 -background white/,
        '-browsecmd' => [$self, '_display_installed_files']
    )->pack(qw/-side top -fill both -expand 1 -padx 4/);
    $modules->header('create', 0, -text => 'Module');
    $modules->header('create', 1, -text => 'Version');

    $fr->Label(-text => 'Files of selected module:')->pack(qw/-side top -fill x -pady 3/);

    my $files = $self->{installed}{files} = $fr->Scrolled(
        'HList', qw/-scrollbars osoe/,
        qw/-columns 1 -header 1 -height 8 -background white/,
    )->pack(qw/-side top -fill both -expand 1 -padx 4/);
    $files->header('create', 0, -text => 'Path');

}

sub _raise_installed {
    my $self = shift;
    $self->_status('Searching for installed modules...');
    my $inst = $self->{installed}{extutils_installed} = ExtUtils::Installed->new();
    $self->_status('Populating list of installed modules...');

    my $hlist = $self->{installed}{modules};
    $hlist->delete('all');
    $self->{installed}{files}->delete('all');
    $self->{installed}{current_module} = undef;

    my $i = 0;
    foreach my $module (
        map {$_->[1]}
        sort {$a->[0] cmp $b->[0]}
        map {[uc($_), $_]}
        $inst->modules())
    {
        next if $module =~ /^Perl/;
        my $version = $inst->version($module) || '?';
        $hlist->add($i);
        $hlist->itemCreate($i, 0, -text => $module);
        $hlist->itemCreate($i, 1, -text => $version);
        $self->{mw}->update();
        $i++;
    }
    $self->_status('');

}

sub _display_installed_files {
    my $self = shift;

    my $modules = $self->{installed}{modules};
    my $files   = $self->{installed}{files};
    my @list = $modules->info('selection');
    my $mod_no = shift @list;

    my $modulename = $modules->itemCget($mod_no, 0, '-text');

    my $current_module = $self->{installed}{current_module};
    return if defined $current_module and $current_module eq $modulename;

    $self->_status('Populating files list');
    my $instl = $self->{installed}{extutils_installed}
                || ExtUtils::Installed->new();
    my @files = $instl->files($modulename);

    $files->delete('all');
    my $i = 0;
    foreach my $file (
        map {$_->[1]}
        sort {$a->[0] cmp $b->[0]}
        map {[uc($_), $_]}
        @files)
    {
        $files->add($i);
        $files->itemCreate($i, 0, -text => $file);
        $i++;
    }

    $self->{installed}{current_module} = $modulename;
    $self->_status('');
}


1;

__END__

=head1 NAME

PAR::Dist::InstallPPD::GUI::Installed - Implements the Installed tab

=head1 SYNOPSIS

  use PAR::Dist::InstallPPD::GUI;
  my $gui = PAR::Dist::InstallPPD::GUI->new();
  $gui->run();

=head1 DESCRIPTION

This module is B<for internal use only>.

=head1 SEE ALSO

L<PAR::Dist::InstallPPD::GUI>

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

