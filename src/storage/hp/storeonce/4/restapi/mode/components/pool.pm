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

package storage::hp::storeonce::4::restapi::mode::components::pool;

use strict;
use warnings;

sub load {}

sub check {
    my ($self) = @_;
    
    $self->{output}->output_add(long_msg => 'checking pools');
    $self->{components}->{pool} = { name => 'pool', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'pool'));

    foreach my $entry (@{$self->{subsystems}->{pool}}) {
        my $instance = $entry->{name};
        next if ($self->check_filter(section => 'pool', instance => $instance));
        $self->{components}->{drive}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "pool '%s' status is %s",
                $entry->{name},
                $entry->{status}
            )
        );
        my $exit = $self->get_severity(label => 'default', section => 'pool', value => $entry->{status});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity =>  $exit,
                short_msg => sprintf(
                    "pool '%s' status is %s",
                    $entry->{name}, $entry->{status}
                )
            );
        }
    }
}

1;
