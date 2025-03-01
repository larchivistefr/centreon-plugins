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

package network::cisco::meraki::cloudcontroller::restapi::mode::networks;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_network_output {
    my ($self, %options) = @_;
    
    return "Network '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'networks', type => 1, cb_prefix_output => 'prefix_network_output', message_multiple => 'All networks are ok' }
    ];

    $self->{maps_counters}->{networks} = [
        { label => 'connections-success', nlabel => 'network.connections.success.count', set => {
                key_values => [ { name => 'assoc' }, { name => 'display' } ],
                output_template => 'connections success: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'connections-auth', nlabel => 'network.connections.auth.count', display_ok => 0, set => {
                key_values => [ { name => 'auth' }, { name => 'display' } ],
                output_template => 'connections auth: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'connections-assoc', nlabel => 'network.connections.assoc.count', display_ok => 0, set => {
                key_values => [ { name => 'assoc' }, { name => 'display' } ],
                output_template => 'connections assoc: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'connections-dhcp', nlabel => 'network.connections.dhcp.count', display_ok => 0, set => {
                key_values => [ { name => 'dhcp' }, { name => 'display' } ],
                output_template => 'connections dhcp: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'connections-dns', nlabel => 'network.connections.dns.count', display_ok => 0, set => {
                key_values => [ { name => 'dns' }, { name => 'display' } ],
                output_template => 'connections dns: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'traffic-in', nlabel => 'network.traffic.in.bitspersecond', set => {
                key_values => [ { name => 'traffic_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'b/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'traffic-out', nlabel => 'network.traffic.out.bitspersecond', set => {
                key_values => [ { name => 'traffic_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'b/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-network-name:s'      => { name => 'filter_network_name' },
        'filter-organization-name:s' => { name => 'filter_organization_name' },
        'filter-organization-id:s'   => { name => 'filter_organization_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{cache_name} = 'meraki_' . $self->{mode} . '_' . $options{custom}->get_token()  . '_' .
        md5_hex(
            (defined($self->{option_results}->{filter_counters}) ? $self->{option_results}->{filter_counters} : 'all') . '_' .
            (defined($self->{option_results}->{filter_network_name}) ? $self->{option_results}->{filter_network_name} : 'all') . '_' .
            (defined($self->{option_results}->{filter_organization_id}) ? $self->{option_results}->{filter_organization_id} : 'all') . '_' .
            (defined($self->{option_results}->{filter_organization_name}) ? $self->{option_results}->{filter_organization_name} : 'all')
        );

    my $datas = $options{custom}->get_datas(skipDevices => 1, skipDevicesStatus => 1);

    $self->{networks} = {};
    foreach my $id (keys %{$datas->{networks}}) {
        next if (defined($self->{option_results}->{filter_network_name}) && $self->{option_results}->{filter_network_name} ne '' &&
            $datas->{networks}->{$id}->{name} !~ /$self->{option_results}->{filter_network_name}/);

        next if (defined($self->{option_results}->{filter_organization_id}) && $self->{option_results}->{filter_organization_id} ne '' &&
            $datas->{networks}->{$id}->{organizationId} !~ /$self->{option_results}->{filter_organization_id}/);
        next if (defined($self->{option_results}->{filter_organization_name}) && $self->{option_results}->{filter_organization_name} ne '' &&
            $datas->{orgs}->{ $datas->{networks}->{$id}->{organizationId} }->{name} !~ /$self->{option_results}->{filter_organization_name}/);

        my $connections = $options{custom}->get_networks_connection_stats(network_id => $id);
        my $clients = $options{custom}->get_networks_clients(network_id => $id);

        $self->{networks}->{$id} = {
            display => $datas->{networks}->{$id}->{name},
            assoc => defined($connections->{assoc}) ? $connections->{assoc} : 0,
            auth => defined($connections->{auth}) ? $connections->{auth} : 0,
            dhcp => defined($connections->{dhcp}) ? $connections->{dhcp} : 0,
            dns => defined($connections->{dns}) ? $connections->{dns} : 0,
            success => defined($connections->{success}) ? $connections->{success} : 0,
            traffic_in => 0, traffic_out => 0
        };

        if (defined($clients)) {
            foreach my $client (@$clients) {
                $self->{networks}->{$id}->{traffic_in} += $client->{usage}->{recv} * 8;
                $self->{networks}->{$id}->{traffic_out} += $client->{usage}->{sent} * 8;
            }
        }
    }

    if (scalar(keys %{$self->{networks}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No networks found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check networks.

=over 8

=item B<--filter-network-name>

Filter network name (Can be a regexp).

=item B<--filter-organization-id>

Filter networks by organization id (Can be a regexp).

=item B<--filter-organization-name>

Filter networks by organization name (Can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'connections-success', 'connections-auth', 'connections-assoc',
'connections-dhcp', 'connections-dns', 'traffic-in', 'traffic-out'.

=back

=cut
