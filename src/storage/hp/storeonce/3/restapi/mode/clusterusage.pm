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

package storage::hp::storeonce::3::restapi::mode::clusterusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    
    return 'status: ' . $self->{result_values}->{health};
}

sub custom_usage_perfdata {
    my ($self, %options) = @_;
    
    my $nlabel = 'cluster.space.usage.bytes';
    my $value_perf = $self->{result_values}->{used};
    if (defined($self->{instance_mode}->{option_results}->{free})) {
        $nlabel = 'cluster.space.free.bytes';
        $value_perf = $self->{result_values}->{free};
    }

    my %total_options = ();
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $total_options{total} = $self->{result_values}->{total};
        $total_options{cast_int} = 1;
    }

    $self->{output}->perfdata_add(
        nlabel => $nlabel,
        unit => 'B',
        instances => $self->{result_values}->{display},
        value => $value_perf,
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}, %total_options),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}, %total_options),
        min => 0, max => $self->{result_values}->{total}
    );
}

sub custom_usage_threshold {
    my ($self, %options) = @_;
    
    my ($exit, $threshold_value);
    $threshold_value = $self->{result_values}->{used};
    $threshold_value = $self->{result_values}->{free} if (defined($self->{instance_mode}->{option_results}->{free}));
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $threshold_value = $self->{result_values}->{prct_used};
        $threshold_value = $self->{result_values}->{prct_free} if (defined($self->{instance_mode}->{option_results}->{free}));
    }
    $exit = $self->{perfdata}->threshold_check(
        value => $threshold_value,
        threshold => [
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-'. $self->{thlabel}, exit_litteral => 'warning' }
        ]
    );
    return $exit;
}

sub custom_usage_output {
    my ($self, %options) = @_;
    
    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used});
    my ($total_free_value, $total_free_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free});
    return sprintf(
        "Usage Total: %s Used: %s (%.2f%%) Free: %s (%.2f%%)",
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, $self->{result_values}->{prct_used},
        $total_free_value . " " . $total_free_unit, $self->{result_values}->{prct_free}
    );
}

sub custom_usage_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};    
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_total'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_used'};
    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_free} = 100 - $self->{result_values}->{prct_used};
    
    return 0;
}

sub prefix_cluster_output {
    my ($self, %options) = @_;
    
    return "Cluster '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'cluster', type => 1, cb_prefix_output => 'prefix_cluster_output', message_multiple => 'All clusters are ok' }
    ];
    
    $self->{maps_counters}->{cluster} = [
        {
            label => 'status',
            type => 2,
            warning_default => '%{health} =~ /warning/',
            critical_default => '%{health} =~ /critical/',
            set => {
                key_values => [ { name => 'health' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'usage', set => {
                key_values => [ { name => 'display' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        },
        { label => 'dedup', nlabel => 'cluster.deduplication.ratio.count', set => {
                key_values => [ { name => 'dedup' }, { name => 'display' } ],
                output_template => 'Dedup Ratio: %.2f',
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => { 
        'filter-name:s' => { name => 'filter_name' },
        'units:s'       => { name => 'units', default => '%' },
        'free'          => { name => 'free' }
    });

    return $self;
}

my %mapping_health_level = (
    0 => 'unknown',
    1 => 'ok',
    2 => 'information',
    3 => 'warning',
    4 => 'critical'
);

sub manage_selection {
    my ($self, %options) = @_;

    $self->{cluster} = {};
    my $result = $options{custom}->get(path => '/cluster', ForceArray => ['cluster']);
    if (defined($result->{cluster})) {
        foreach my $entry (@{$result->{cluster}}) {
            if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
                $entry->{properties}->{applianceName} !~ /$self->{option_results}->{filter_name}/) {
                $self->{output}->output_add(long_msg => "skipping  '" . $entry->{properties}->{applianceName} . "': no matching filter.", debug => 1);
                next;
            }

            my $total = defined($entry->{properties}->{capacity}) ? $entry->{properties}->{capacity} * 1024 * 1024 * 1024 : $entry->{properties}->{localCapacityBytes};
            my $used = $total - (defined($entry->{properties}->{freeSpace}) ? $entry->{properties}->{freeSpace} * 1024 * 1024 * 1024 : $entry->{properties}->{localFreeBytes});
            
            $self->{cluster}->{$entry->{properties}->{serialNumber}} = { 
                display => $entry->{properties}->{applianceName}, 
                health => $mapping_health_level{$entry->{properties}->{healthLevel}},
                total => $total,
                used => $used,
                dedup => $entry->{properties}->{dedupeRatio}
            };
        }
    }

    if (scalar(keys %{$self->{cluster}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No cluster found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check cluster usages.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^status$'

=item B<--filter-name>

Filter cluster name (can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (Default: '%{health} =~ /warning/').
You can use the following variables: %{health}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (Default: '%{health} =~ /critical/').
You can use the following variables: %{health}, %{display}

=item B<--warning-*>

Warning threshold.
Can be: 'usage', 'dedup'.

=item B<--critical-*>

Critical threshold.
Can be: 'usage', 'dedup'.

=item B<--units>

Units of thresholds (Default: '%') ('%', 'B').

=item B<--free>

Thresholds are on free space left.

=back

=cut
