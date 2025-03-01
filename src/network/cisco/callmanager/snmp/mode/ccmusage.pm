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

package network::cisco::callmanager::snmp::mode::ccmusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return 'status : ' . $self->{result_values}->{status};
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{status} = $options{new_datas}->{$self->{instance} . '_ccmStatus'};
    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_ccmName'};
    return 0;
}

sub prefix_ccm_output {
    my ($self, %options) = @_;

    return "CCM '" . $options{instance_value}->{ccmName} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'ccm', type => 1, cb_prefix_output => 'prefix_ccm_output', message_multiple => 'All CCM are ok' }
    ];
    
    $self->{maps_counters}->{ccm} = [
        { label => 'status', type => 2, critical_default => '%{status} !~ /up/', set => {
                key_values => [ { name => 'ccmStatus' }, { name => 'ccmName' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
    
    my @map = (
        ['phones-registered', 'Phones Registered : %s', 'ccmRegisteredPhones', 'phones.registered.count'],
        ['phones-unregistered', 'Phones Unregistered : %s', 'ccmUnregisteredPhones', 'phones.unregistered.count'],
        ['phones-rejected', 'Phones Rejected : %s', 'ccmRejectedPhones', 'phones.rejected.count'],
        ['gateways-registered', 'Gateways Registered : %s', 'ccmRegisteredGateways', 'gateways.registered.count'],
        ['gateways-unregistered', 'Gateways Unregistered : %s', 'ccmUnregisteredGateways', 'gateways.unregistered.count'],
        ['gateways-rejected', 'Gateways Rejected : %s', 'ccmRejectedGateways', 'gateways.rejected.count'],
        ['mediadevices-registered', 'Media Devices Registered : %s', 'ccmRegisteredMediaDevices', 'media_devices.registered.count'],
        ['mediadevices-unregistered', 'Media Devices Unregistered : %s', 'ccmUnregisteredMediaDevices', 'media_devices.unregistered.count'],
        ['mediadevices-rejected', 'Media Devices Rejected : %s', 'ccmRejectedMediaDevices', 'media_devices.rejected.count']
    );

    $self->{maps_counters}->{global} = [];
    foreach (@map) {
        my $label = $_->[0];
        $label =~ tr/-/_/;
        push @{$self->{maps_counters}->{global}}, {
            label => $_->[0], nlabel => $_->[3], set => {
                key_values => [ { name => $_->[2] } ],
                output_template => $_->[1],
                perfdatas => [
                    { label => $label, value => $_->[2] , template => '%s', min => 0 }
                ]
            }
        };
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

my %mapping_status = (1 => 'unknown', 2 => 'up', 3 => 'down');

my $mapping = {
    ccmRegisteredPhones     => { oid => '.1.3.6.1.4.1.9.9.156.1.5.5' },
    ccmUnregisteredPhones   => { oid => '.1.3.6.1.4.1.9.9.156.1.5.6' },
    ccmRejectedPhones       => { oid => '.1.3.6.1.4.1.9.9.156.1.5.7' },
    ccmRegisteredGateways   => { oid => '.1.3.6.1.4.1.9.9.156.1.5.8' },
    ccmUnregisteredGateways => { oid => '.1.3.6.1.4.1.9.9.156.1.5.9' },
    ccmRejectedGateways     => { oid => '.1.3.6.1.4.1.9.9.156.1.5.10' },
    ccmRegisteredMediaDevices   => { oid => '.1.3.6.1.4.1.9.9.156.1.5.11' },
    ccmUnregisteredMediaDevices => { oid => '.1.3.6.1.4.1.9.9.156.1.5.12' },
    ccmRejectedMediaDevices     => { oid => '.1.3.6.1.4.1.9.9.156.1.5.13' }
};
my $mapping2 = {
    ccmName     => { oid => '.1.3.6.1.4.1.9.9.156.1.1.2.1.2' },
    ccmStatus   => { oid => '.1.3.6.1.4.1.9.9.156.1.1.2.1.5', map => \%mapping_status }
};

my $oid_ccmGlobalInfo = '.1.3.6.1.4.1.9.9.156.1.5';
my $oid_ccmEntry = '.1.3.6.1.4.1.9.9.156.1.1.2.1';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $oid_ccmGlobalInfo, end => $mapping->{ccmRejectedMediaDevices}->{oid} },
            { oid => $oid_ccmEntry, end => $mapping2->{ccmStatus}->{oid} }
        ],
        nothing_quit => 1
    );
    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result->{$oid_ccmGlobalInfo}, instance => '0');
    $self->{global} = $result;

    $self->{ccm} = {};
    foreach my $oid (keys %{$snmp_result->{$oid_ccmEntry}}) {
        next if ($oid !~ /^$mapping2->{ccmStatus}->{oid}\.(.*)/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping2, results => $snmp_result->{$oid_ccmEntry}, instance => $instance);

        $self->{ccm}->{$instance} = $result;
    }
}
    
1;

__END__

=head1 MODE

Check cisco call manager global usage.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='phone'

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (Default: '').
You can use the following variables: %{status}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (Default: '%{status} !~ /up/').
You can use the following variables: %{status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds.

Can be: 'phones-registered', 'phones-unregistered', 'phones-rejected', 
'gateways-registered', 'gateways-unregistered', 'gateways-rejected', 
'mediadevices-registered', 'mediadevices-unregistered', 'mediadevices-rejected'.

=back

=cut
