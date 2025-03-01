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

package network::cambium::epmp::snmp::mode::license;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'status', 
        type => 2, 
        unknown_default => '%{status} =~ /unknown/i',
        warning_default => '%{status} =~ /validation fail|not provided/i',
        critical_default => '%{status} =~ /not valid/i',
        set => {
                key_values => [ { name => 'status' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub custom_status_output { 
    my ($self, %options) = @_;

    return 'License status: ' . $self->{result_values}->{status};
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

}

my $map_status = {
    0 => 'Unknown',
    1 => 'License Valid',
    2 => 'Validation procedure was not provided',
    3 => 'Validation Fail',
    4 => 'License not valid for current device'
};

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_cambLicenseStatus = '.1.3.6.1.4.1.17713.21.1.8.5.0';

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ $oid_cambLicenseStatus ], 
        nothing_quit => 1
    );

    $self->{global} = {
        status => $map_status->{ $snmp_result->{$oid_cambLicenseStatus} }
    };
}

1;

__END__

=head1 MODE

Check Cambium license status.

=over 8

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (Default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (Default: '%{status} =~ /validation fail|not provided/i').
You can use the following variables: %{status}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (Default: '%{status} =~ /not valid/i').
You can use the following variables: %{status}

=back

=cut