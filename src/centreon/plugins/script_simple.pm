#
# Copyright 2023 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package centreon::plugins::script_simple;

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;
    $self->{options} = $options{options};
    $self->{output} = $options{output};
    
    $self->{options}->add_options(
        arguments => {
            'mode:s'            => { name => 'mode_name' },
            'dyn-mode:s'        => { name => 'dynmode_name' },
            'list-mode'         => { name => 'list_mode' },
            'mode-version:s'    => { name => 'mode_version' },
            'no-sanity-options' => { name => 'no_sanity_options' },
            'pass-manager:s'    => { name => 'pass_manager' },
        }
    );
    $self->{version} = '1.0';
    %{$self->{modes}} = ();
    $self->{default} = undef;
    
    $self->{options}->parse_options();
    $self->{option_results} = $self->{options}->get_options();
    foreach (keys %{$self->{option_results}}) {
        $self->{$_} = $self->{option_results}->{$_};
    }
    $self->{options}->clean();

    $self->{options}->add_help(package => $options{package}, sections => 'PLUGIN DESCRIPTION');
    $self->{options}->add_help(package => __PACKAGE__, sections => 'GLOBAL OPTIONS');
    $self->{output}->mode(name => $self->{mode_name});

    return $self;
}

sub init {
    my ($self, %options) = @_;

    # add meta mode
    $self->{modes}->{multi} = 'centreon::plugins::multi';
    if (defined($options{help}) && !defined($self->{mode_name}) && !defined($self->{dynmode_name})) {
        $self->{options}->display_help();
        $self->{output}->option_exit();
    }
    if (defined($options{version}) && !defined($self->{mode_name}) && !defined($self->{dynmode_name})) {
        $self->version();
    }
    if (defined($self->{list_mode})) {
        $self->list_mode();
    }
    $self->{options}->set_sanity() if (!defined($self->{no_sanity_options}));

    # Output HELP
    $self->{options}->add_help(package => 'centreon::plugins::output', sections => 'OUTPUT OPTIONS');
    
    $self->load_password_mgr();
    
    # Load mode
    if (defined($self->{mode_name}) && $self->{mode_name} ne '') {
        $self->is_mode(mode => $self->{mode_name});
        centreon::plugins::misc::mymodule_load(output => $self->{output}, module => $self->{modes}{$self->{mode_name}}, 
                                               error_msg => "Cannot load module --mode.");
        $self->{mode} = $self->{modes}{$self->{mode_name}}->new(options => $self->{options}, output => $self->{output}, mode => $self->{mode_name});
    } elsif (defined($self->{dynmode_name}) && $self->{dynmode_name} ne '') {
        (undef, $self->{dynmode_name}) = centreon::plugins::misc::mymodule_load(output => $self->{output}, module => $self->{dynmode_name}, 
                                                                                error_msg => "Cannot load module --dyn-mode.");
        $self->{mode} = $self->{dynmode_name}->new(options => $self->{options}, output => $self->{output}, mode => $self->{dynmode_name});
    } else {
        $self->{output}->add_option_msg(short_msg => "Need to specify '--mode' or '--dyn-mode' option.");
        $self->{output}->option_exit();
    }

    if (defined($options{help})) {
        if (defined($self->{mode_name}) && $self->{mode_name} ne '') {
            $self->{options}->add_help(package => $self->{modes}{$self->{mode_name}}, sections => 'MODE');
        } else {
            $self->{options}->add_help(package => $self->{dynmode_name}, sections => 'MODE');
        }
        $self->{options}->display_help();
        $self->{output}->option_exit();
    }
    if (defined($options{version})) {
        $self->{mode}->version();
        $self->{output}->option_exit(nolabel => 1);
    }
    if (centreon::plugins::misc::minimal_version($self->{mode}->{version}, $self->{mode_version}) == 0) {
        $self->{output}->add_option_msg(short_msg => "Not good version for plugin mode. Excepted at least: " . $self->{mode_version} . ". Get: ".  $self->{mode}->{version});
        $self->{output}->option_exit();
    }
    
    $self->{options}->parse_options();
    $self->{option_results} = $self->{options}->get_options();

    $self->{pass_mgr}->manage_options(option_results => $self->{option_results}) if (defined($self->{pass_mgr}));
    $self->{mode}->check_options(
        option_results => $self->{option_results},
        default => $self->{default},
        modes => $self->{modes} # for meta mode multi
    );
}

sub load_password_mgr {
    my ($self, %options) = @_;
    
    return if (!defined($self->{option_results}->{pass_manager}) || $self->{option_results}->{pass_manager} eq '');

    (undef, my $pass_mgr_name) = centreon::plugins::misc::mymodule_load(
        output => $self->{output}, module => "centreon::plugins::passwordmgr::" . $self->{option_results}->{pass_manager}, 
        error_msg => "Cannot load module 'centreon::plugins::passwordmgr::" . $self->{option_results}->{pass_manager} . "'"
    );
    $self->{pass_mgr} = $pass_mgr_name->new(options => $self->{options}, output => $self->{output});
}

sub run {
    my $self = shift;

    if ($self->{output}->is_disco_format()) {
        $self->{mode}->disco_format();
        $self->{output}->display_disco_format();
        $self->{output}->exit(exit_litteral => 'ok');
    }
    if ($self->{output}->is_disco_show()) {
        $self->{mode}->disco_show(snmp => $self->{snmp});
        $self->{output}->display_disco_show();
        $self->{output}->exit(exit_litteral => 'ok');
    } else {
        $self->{mode}->run();
    }
}

sub is_mode {
    my ($self, %options) = @_;
    
    # $options->{mode} = mode
    if (!defined($self->{modes}{$options{mode}})) {
        $self->{output}->add_option_msg(short_msg => "mode '" . $options{mode} . "' doesn't exist (use --list-mode option to show available modes).");
        $self->{output}->option_exit();
    }
}

sub version {
    my $self = shift;    
    $self->{output}->add_option_msg(short_msg => "Plugin Version: " . $self->{version});
    $self->{output}->option_exit(nolabel => 1);
}

sub list_mode {
    my $self = shift;
    $self->{options}->display_help();
    
    $self->{output}->add_option_msg(long_msg => 'Modes Meta:');
    $self->{output}->add_option_msg(long_msg => '   multi');
    $self->{output}->add_option_msg(long_msg => '');
    $self->{output}->add_option_msg(long_msg => 'Modes Available:');
    foreach (sort keys %{$self->{modes}}) {
        next if ($_ eq 'multi');
        $self->{output}->add_option_msg(long_msg => '   ' . $_);
    }
    $self->{output}->option_exit(nolabel => 1);
}

1;

__END__

=head1 NAME

-

=head1 SYNOPSIS

-

=head1 GLOBAL OPTIONS

=over 8

=item B<--mode>

Define the mode in which you want the plugin to be executed (see --list-mode).

=item B<--dyn-mode>

Specify a mode with the module's path (advanced).

=item B<--list-mode>

List all available modes.

=item B<--mode-version>

Check minimal version of mode. If not, unknown error.

=item B<--version>

Return the version of the plugin.

=item B<--pass-manager>

Define the password manager you want to use.
Supported managers are: environment, file, keepass, hashicorpvault and teampass.

=back

=head1 DESCRIPTION

B<>.

=cut
