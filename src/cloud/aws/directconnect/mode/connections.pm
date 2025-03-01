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

package cloud::aws::directconnect::mode::connections;

use base qw(cloud::aws::custom::mode);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub get_metrics_mapping {
    my ($self, %options) = @_;

    my $metrics_mapping = {
        extra_params => {
            message_multiple => 'All connections are ok'
        },
        metrics => {
            ConnectionBpsEgress => {
                output => 'outbound data',
                label => 'connection-egress',
                nlabel => {
                    absolute => 'connection.egress.bitspersecond',
                },
                unit => 'bps'
            },
            ConnectionBpsIngress => {
                output => 'inbound data',
                label => 'connection-ingress',
                nlabel => {
                    absolute => 'connection.ingress.bitspersecond',
                },
                unit => 'bps'
            },
            ConnectionPpsEgress => {
                output => 'outbound packets data',
                label => 'connection-packets-egress',
                nlabel => {
                    absolute => 'connection.egress.packets.persecond',
                },
                unit => '/s'
            },
            ConnectionPpsIngress => {
                output => 'inbound packet data',
                label => 'connection-packets-ingress',
                nlabel => {
                    absolute => 'connection.ingress.packets.persecond',
                },
                unit => '/s'
            },
            ConnectionLightLevelTx => {
                output => 'outbound light level',
                label => 'connection-ligh-level-outbound',
                nlabel => {
                    absolute => 'connection.outbound.light.level.dbm',
                },
                unit => 'dBm'
            },
            ConnectionLightLevelRx => {
                output => 'inbound light level',
                label => 'connection-ligh-level-inbound',
                nlabel => {
                    absolute => 'connection.inbound.light.level.dbm',
                },
                unit => 'dBm'
            }
        }
    };

    return $metrics_mapping;
}

sub custom_status_output {
    my ($self, %options) = @_;
    
    return sprintf('state: %s [bandwidth: %s]', $self->{result_values}->{state}, $self->{result_values}->{bandwidth});
}

sub prefix_metric_output {
    my ($self, %options) = @_;

    return "connection '" . $options{instance_value}->{display} . "' ";
}

sub long_output {
    my ($self, %options) = @_;

    return "Checking connection '" . $options{instance_value}->{display} . "' ";
}

sub prefix_statistics_output {
    my ($self, %options) = @_;

    return "statistic '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->SUPER::set_counters(%options);

    unshift @{$self->{maps_counters_type}->[0]->{group}}, {
        name => 'status',
        type => 0, skipped_code => { -10 => 1 }
    };

    $self->{maps_counters}->{status} = [
        { label => 'status', type => 2, set => {
                key_values => [ { name => 'state' }, { name => 'bandwidth' }, { name => 'connectionName' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        'filter-connection-id:s' => { name => 'filter_connection_id' }
    });
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $connections = $options{custom}->directconnect_describe_connections();

    foreach my $connection_id (keys %$connections) {
        next if (defined($self->{option_results}->{filter_connection_id}) && $self->{option_results}->{filter_connection_id} ne ''
            && $connection_id !~ /$self->{option_results}->{filter_connection_id}/);

        $self->{metrics}->{$connection_id} = {
            display => $connections->{$connection_id}->{name},
            status => {
                connectionName => $connections->{$connection_id}->{name},
                bandwidth => $connections->{$connection_id}->{bandwidth},
                state => $connections->{$connection_id}->{state}
            },
            statistics => {}
        };

        my $cw_metrics = $options{custom}->cloudwatch_get_metrics(
            namespace => 'AWS/DX',
            dimensions => [ { Name => 'ConnectionId', Value => $connection_id } ],
            metrics => $self->{aws_metrics},
            statistics => $self->{aws_statistics},
            timeframe => $self->{aws_timeframe},
            period => $self->{aws_period}
        );

        foreach my $metric (@{$self->{aws_metrics}}) {
            foreach my $statistic (@{$self->{aws_statistics}}) {
                next if (!defined($cw_metrics->{$metric}->{lc($statistic)}) &&
                    !defined($self->{option_results}->{zeroed}));

                $self->{metrics}->{$connection_id}->{display} = $connections->{$connection_id}->{name};
                $self->{metrics}->{$connection_id}->{statistics}->{lc($statistic)}->{display} = $statistic;
                $self->{metrics}->{$connection_id}->{statistics}->{lc($statistic)}->{timeframe} = $self->{aws_timeframe};
                $self->{metrics}->{$connection_id}->{statistics}->{lc($statistic)}->{$metric} = 
                    defined($cw_metrics->{$metric}->{lc($statistic)}) ? 
                    $cw_metrics->{$metric}->{lc($statistic)} : 0;
            }
        }
    }

    if (scalar(keys %{$self->{metrics}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No connection found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check direct connect connections.

Example: 
perl centreon_plugins.pl --plugin=cloud::aws::directconnect::plugin --custommode=paws --mode=connections --region='eu-west-1'
--filter-metric='ConnectionBpsEgress' --statistic='average' --critical-connection-egress='10Mb' --verbose

See 'https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html' for more informations.

Default statistic: 'average' / All satistics are valid.

=over 8

=item B<--filter-connection-id>

Filter connection id (can be a regexp).

=item B<--filter-metric>

Filter metrics (Can be: 'ConnectionBpsEgress', 'ConnectionBpsIngress', 
'ConnectionPpsEgress', 'ConnectionPpsIngress', 'ConnectionLightLevelTx', 'ConnectionLightLevelRx') 
(Can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{bandwidth}, %{connectionName}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{state}, %{bandwidth}, %{connectionName}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be 'connection-egress', 'connection-ingress', 
'connection-packets-egress', 'connection-packets-ingress',
'connection-ligh-level-outbound', 'connection-ligh-level-inbound.

=back

=cut
