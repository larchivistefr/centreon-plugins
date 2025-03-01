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

package network::versa::director::restapi::mode::devices;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use centreon::plugins::misc;
use Digest::MD5 qw(md5_hex);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'status services: %s [ping: %s] [sync: %s] [path: %s] [controller: %s]',
        $self->{result_values}->{services_status},
        $self->{result_values}->{ping_status},
        $self->{result_values}->{sync_status},
        $self->{result_values}->{path_status},
        $self->{result_values}->{controller_status}
    );
}

sub custom_memory_output {
    my ($self, %options) = @_;

    return sprintf(
        'memory total: %s %s used: %s %s (%.2f%%) free: %s %s (%.2f%%)',
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{total}),
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{used}),
        $self->{result_values}->{prct_used},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{free}),
        $self->{result_values}->{prct_free}
    );
}

sub custom_disk_output {
    my ($self, %options) = @_;

    return sprintf(
        'disk total: %s %s used: %s %s (%.2f%%) free: %s %s (%.2f%%)',
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{total}),
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{used}),
        $self->{result_values}->{prct_used},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{free}),
        $self->{result_values}->{prct_free}
    );
}

sub device_long_output {
    my ($self, %options) = @_;

    return "checking device '" . $options{instance_value}->{display} . "' [type: " . $options{instance_value}->{type} . ']';
}

sub prefix_device_output {
    my ($self, %options) = @_;

    return "Device '" . $options{instance_value}->{display} . "' ";
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Devices ';
}

sub prefix_alarm_output {
    my ($self, %options) = @_;

    return 'alarms ';
}

sub prefix_path_output {
    my ($self, %options) = @_;

    return 'paths ';
}

sub prefix_policy_output {
    my ($self, %options) = @_;

    return 'policy violation ';
}

sub prefix_health_output {
    my ($self, %options) = @_;

    return "health monitor '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'devices', type => 3, cb_prefix_output => 'prefix_device_output', cb_long_output => 'device_long_output', indent_long_output => '    ', message_multiple => 'All devices are ok',
            group => [
                { name => 'device_status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_memory', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_disk', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_alarms', type => 0, cb_prefix_output => 'prefix_alarm_output', skipped_code => { -10 => 1 } },
                { name => 'device_paths', type => 0, cb_prefix_output => 'prefix_path_output', skipped_code => { -10 => 1 } },
                { name => 'device_policy', type => 0, cb_prefix_output => 'prefix_policy_output', skipped_code => { -10 => 1 } },
                { name => 'device_bgp_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_config_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_ike_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_interface_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_port_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_path_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_reachability_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } },
                { name => 'device_service_health', cb_prefix_output => 'prefix_health_output', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'total', nlabel => 'devices.total.count', display_ok => 0, set => {
                key_values => [ { name => 'total'} ],
                output_template => 'total: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{device_status} = [
        { label => 'status', type => 2, critical_default => '%{ping_status} ne "reachable" or %{services_status} ne "good"', set => {
                key_values => [
                    { name => 'ping_status' }, { name => 'sync_status' },
                    { name => 'services_status' }, { name => 'path_status' },
                    { name => 'controller_status' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{device_memory} = [
        { label => 'memory-usage', nlabel => 'memory.usage.bytes', set => {
                key_values => [ { name => 'used' }, { name => 'free' }, { name => 'prct_used' }, { name => 'prct_free' }, { name => 'total' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_memory_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage-free', display_ok => 0, nlabel => 'memory.free.bytes', set => {
                key_values => [ { name => 'free' }, { name => 'used' }, { name => 'prct_used' }, { name => 'prct_free' }, { name => 'total' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_memory_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage-prct', display_ok => 0, nlabel => 'memory.usage.percentage', set => {
                key_values => [ { name => 'prct_used' }, { name => 'display' } ],
                output_template => 'memory used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{device_disk} = [
        { label => 'disk-usage', nlabel => 'disk.usage.bytes', set => {
                key_values => [ { name => 'used' }, { name => 'free' }, { name => 'prct_used' }, { name => 'prct_free' }, { name => 'total' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_disk_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'disk-usage-free', display_ok => 0, nlabel => 'disk.free.bytes', set => {
                key_values => [ { name => 'free' }, { name => 'used' }, { name => 'prct_used' }, { name => 'prct_free' }, { name => 'total' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_disk_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'disk-usage-prct', display_ok => 0, nlabel => 'disk.usage.percentage', set => {
                key_values => [ { name => 'prct_used' }, { name => 'display' } ],
                output_template => 'disk used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{device_alarms} = [];
    foreach (('critical', 'major', 'minor', 'warning', 'indeterminate')) {
        push @{$self->{maps_counters}->{device_alarms}}, {
            label => 'alarms-' . $_, nlabel => 'alarms.' . $_ . '.count', 
            set => {
                key_values => [ { name => $_ }, { name => 'display' } ],
                output_template => $_ . ': %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1 }
                ]
            }
        };
    }

    $self->{maps_counters}->{device_paths} = [
        { label => 'paths-up', nlabel => 'paths.up.count', set => {
                key_values => [ { name => 'up' },  { name => 'display' } ],
                output_template => 'up: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'paths-down', nlabel => 'paths.down.count', set => {
                key_values => [ { name => 'down' },  { name => 'display' } ],
                output_template => 'down: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{device_policy} = [
        { label => 'packets-dropped-novalidlink', nlabel => 'policy.violation.packets.dropped.novalidlink.count', set => {
                key_values => [ { name => 'dropped_novalidlink', diff => 1 },  { name => 'display' } ],
                output_template => 'packets dropped by no valid link: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'packets-dropped-slaaction', nlabel => 'policy.violation.packets.dropped.slaaction.count', set => {
                key_values => [ { name => 'dropped_sla', diff => 1 },  { name => 'display' } ],
                output_template => 'packets dropped by sla action: %s',
                perfdatas => [
                    { template => '%d', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    foreach my $monitor (('bgp', 'config', 'ike', 'interface', 'port', 'path', 'reachability', 'service')) {
        foreach my $status (('up', 'down', 'disabled')) {
            push @{$self->{maps_counters}->{'device_' . $monitor . '_health'}}, {
                label => $monitor . '-health-' . $status, nlabel => $monitor . '.health.' . $status . '.count', 
                set => {
                    key_values => [ { name => $status }, { name => 'display' } ],
                    output_template => $status . ': %s',
                    perfdatas => [
                        { template => '%d', min => 0, label_extra_instance => 1 }
                    ]
                }
            };
        }
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'organization:s'       => { name => 'organization' },
        'filter-org-name:s'    => { name => 'filter_org_name' },
        'filter-device-name:s' => { name => 'filter_device_name' },
        'filter-device-type:s' => { name => 'filter_device_type' },
        'add-paths'            => { name => 'add_paths' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($orgs, $root_org_name);
    my $devices = {};
    if (defined($self->{option_results}->{organization}) && $self->{option_results}->{organization} ne '') {
        my $result = $options{custom}->get_devices(org_name => $self->{option_results}->{organization});
        $devices = $result->{entries};
    } else {
        $orgs = $options{custom}->get_organizations();
        $root_org_name = $options{custom}->find_root_organization_name(orgs => $orgs);
        foreach my $org (values %{$orgs->{entries}}) {
            if (defined($self->{option_results}->{filter_org_name}) && $self->{option_results}->{filter_org_name} ne '' &&
                $org->{name} !~ /$self->{option_results}->{filter_org_name}/) {
                $self->{output}->output_add(long_msg => "skipping org '" . $org->{name} . "': no matching filter name.", debug => 1);
                next;
            }

            my $result = $options{custom}->get_devices(org_name => $org->{name});
            $devices = { %$devices, %{$result->{entries}} };
        }
    }
    if (defined($self->{option_results}->{add_paths}) && !defined($root_org_name)) {
        $orgs = $options{custom}->get_organizations();
        $root_org_name = $options{custom}->find_root_organization_name(orgs => $orgs);
    }

    $self->{global} = { total => 0 };
    $self->{devices} = {};

    foreach my $device (values %$devices) {
        if (defined($self->{option_results}->{filter_device_name}) && $self->{option_results}->{filter_device_name} ne '' &&
            $device->{name} !~ /$self->{option_results}->{filter_device_name}/) {
            $self->{output}->output_add(long_msg => "skipping device '" . $device->{name} . "': no matching filter name.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{filter_device_type}) && $self->{option_results}->{filter_device_type} ne '' &&
            $device->{type} !~ /$self->{option_results}->{filter_device_type}/) {
            $self->{output}->output_add(long_msg => "skipping device '" . $device->{name} . "': no matching filter type.", debug => 1);
            next;
        }

        #"pingStatus": "REACHABLE",
        #"syncStatus": "OUT_OF_SYNC",
        #"servicesStatus": "GOOD",
        #"overallStatus": "POWERED_ON",
        #"controllerStatus": "Unavailable",
        #"pathStatus": "Unavailable",
        #"hardware": {
        #     "memory": "7.80GiB",
	    #     "freeMemory": "1.19GiB",
	    #     "diskSize": "80G",
	    #     "freeDisk": "33G",
        #}

        $self->{devices}->{ $device->{name} } = {
            display => $device->{name},
            type => $device->{type},
            device_status => {
                display => $device->{name},
                ping_status => lc($device->{pingStatus}),
                sync_status => lc($device->{syncStatus}),
                services_status => lc($device->{servicesStatus}),
                path_status => lc($device->{pathStatus}),
                controller_status => defined($device->{controllerStatus}) ? lc($device->{controllerStatus}) : '-'
            },
            device_alarms => {
                display => $device->{name}
            },
            device_policy => {
                display => $device->{name},
                dropped_novalidlink => $device->{policyViolation}->{rows}->[0]->{columnValues}->[1],
                dropped_sla => $device->{policyViolation}->{rows}->[0]->{columnValues}->[2]
            },
            device_health => {}
        };

        my ($total, $free);
        if (defined($device->{hardware}->{memory})) {
            $total = centreon::plugins::misc::convert_bytes(
                value => $device->{hardware}->{memory},
                pattern => '([0-9\.]+)(.*)$'
            );
            $free = centreon::plugins::misc::convert_bytes(
                value => $device->{hardware}->{freeMemory},
                pattern => '([0-9\.]+)(.*)$'
            );
            $self->{devices}->{ $device->{name} }->{device_memory} = {
                display => $device->{name},
                total => $total,
                free => $free,
                used => $total - $free,
                prct_used => 100 - ($free * 100 / $total),
                prct_free => ($free * 100 / $total)
            };
        }

        if (defined($device->{hardware}->{diskSize})) {
            $total = centreon::plugins::misc::convert_bytes(
                value => $device->{hardware}->{diskSize},
                pattern => '([0-9\.]+)(.*)$'
            );
            $free = centreon::plugins::misc::convert_bytes(
                value => $device->{hardware}->{freeDisk},
                pattern => '([0-9\.]+)(.*)$'
            );
            $self->{devices}->{ $device->{name} }->{device_disk} = {
                display => $device->{name},
                total => $total,
                free => $free,
                used => $total - $free,
                prct_used => 100 - ($free * 100 / $total),
                prct_free => ($free * 100 / $total)
            };
        }

        foreach (@{$device->{alarmSummary}->{rows}}) {
            $self->{devices}->{ $device->{name} }->{device_alarms}->{ lc($_->{firstColumnValue}) } = $_->{columnValues}->[0];
        }

        my $health_mapping = {
            'BGP Adjacencies'       => 'device_bgp_health',
            'Config Sync Status'    => 'device_config_health',
            'IKE Status'            => 'device_ike_health',
            'Interfaces'            => 'device_interface_health',
            'Paths'                 => 'device_path_health',
            'Physical Ports'        => 'device_port_health',
            'Reachability Status'   => 'device_reachability_health',
            'Service Status'        => 'device_service_health'
        };

        foreach (@{$device->{cpeHealth}->{rows}}) {
            $self->{devices}->{ $device->{name} }->{ $health_mapping->{$_->{firstColumnValue}} } = {
                display => lc($_->{firstColumnValue}),
                up => $_->{columnValues}->[0],
                down => $_->{columnValues}->[1],
                disabled => $_->{columnValues}->[2],
                total => $_->{columnValues}->[0] + $_->{columnValues}->[1] + $_->{columnValues}->[2]
            };
        }

        if (defined($self->{option_results}->{add_paths})) {
            $self->{devices}->{ $device->{name} }->{device_paths} = {
                display => $device->{name},
                up => 0,
                down => 0
            };
            # we want all paths. So we check from root org
            my $paths = $options{custom}->get_device_paths(
                org_name => $root_org_name,
                device_name => $device->{name}
            );
            foreach (@{$paths->{entries}}) {
                $self->{devices}->{ $device->{name} }->{device_paths}->{ $_->{connState} }++;
            }
        }

        $self->{global}->{total}++;
    }

    $self->{cache_name} = 'versa_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{organization}) ? md5_hex($self->{option_results}->{organization}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_org_name}) ? md5_hex($self->{option_results}->{filter_org_name}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_device_name}) ? md5_hex($self->{option_results}->{filter_device_name}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_device_type}) ? md5_hex($self->{option_results}->{filter_device_type}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check devices.

=over 8

=item B<--organization>

Check device under an organization name.

=item B<--filter-org-name>

Filter organizations by name (Can be a regexp).

=item B<--filter-device-name>

Filter device by name (Can be a regexp).

=item B<--filter-device-type>

Filter device by type (Can be a regexp).

=item B<--add-paths>

Add path statuses count.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{ping_status}, %{services_status}, %{sync_status}, %{controller_status}, %{path_status}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{ping_status}, %{service_sstatus}, %{sync_status}, %{controller_status}, %{path_status}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (Default: '%{ping_status} ne "reachable" or %{services_status} ne "good"').
You can use the following variables: %{ping_status}, %{services_status}, %{sync_status}, %{controller_status}, %{path_status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'total','memory-usage', 'memory-usage-free', 'memory-usage-prct',
'disk-usage', 'disk-usage-free', 'disk-usage-prct',
'alarms-critical', 'alarms-major', 'alarms-minor', 'alarms-warning', 'alarms-indeterminate',
'bgp-health-up' 'bgp-health-down' 'bgp-health-disabled' 
'path-health-up' 'path-health-down' 'path-health-disabled'
'service-health-up' 'service-health-down' 'service-health-disabled' 
'port-health-up' 'port-health-down' 'port-health-disabled'
'reachability-health-up' 'reachability-health-down' 'reachability-health-disabled'
'interface-health-up' 'interface-health-down' 'interface-health-disabled' 
'ike-health-up' 'ike-health-down' 'ike-health-disabled'
'config-health-up' 'config-health-down' 'config-health-disabled'
'packets-dropped-novalidlink', 'packets dropped by sla action',
'paths-up', 'paths-down'.

=back

=cut
