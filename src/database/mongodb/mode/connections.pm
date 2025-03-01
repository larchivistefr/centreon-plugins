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

package database::mongodb::mode::connections;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_output {
    my ($self, %options) = @_;

    return 'Connections ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_output' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'active', nlabel => 'connections.active.count', set => {
                key_values => [ { name => 'active' } ],
                output_template => 'active: %d',
                perfdatas => [
                    { template => '%d', min => 0 }
                ]
            }
        },
        { label => 'current', nlabel => 'connections.current.count', set => {
                key_values => [ { name => 'current' } ],
                output_template => 'current: %d',
                perfdatas => [
                    { template => '%d', min => 0 }
                ]
            }
        },
        { label => 'usage', nlabel => 'connections.usage.percentage', set => {
                key_values => [ { name => 'usage' } ],
                output_template => 'usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%' }
                ]
            }
        },
        { label => 'total-created', nlabel => 'connections.created.persecond', set => {
                key_values => [ { name => 'totalCreated', per_second => 1 } ],
                output_template => 'created: %.2f/s',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1, statefile => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {};

    my $server_stats = $options{custom}->run_command(
        database => 'admin',
        command => $options{custom}->ordered_hash(serverStatus => 1),
    );
    
    $self->{global}->{active} = $server_stats->{connections}->{active};
    $self->{global}->{current} = $server_stats->{connections}->{current};
    $self->{global}->{usage} = $server_stats->{connections}->{current} / ($server_stats->{connections}->{current} + $server_stats->{connections}->{available});
    $self->{global}->{totalCreated} = $server_stats->{connections}->{totalCreated};

    $self->{cache_name} = 'mongodb_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check connections statistics.

=over 8

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'active', 'current', 'usage', 'total-created'.

=back

=cut
