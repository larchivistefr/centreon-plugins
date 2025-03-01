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

package hardware::server::huawei::hmm::snmp::mode::components::psu;

use strict;
use warnings;

my %map_status = (
    1 => 'normal',
    2 => 'minor',
    3 => 'major',
    4 => 'critical',
);

my $mapping = {
    mpsuLocation            => { oid => '.1.3.6.1.4.1.2011.2.82.1.82.100.4.2001.1.2' },
    mpsuHealth              => { oid => '.1.3.6.1.4.1.2011.2.82.1.82.100.4.2001.1.3', map => \%map_status },
};
my $oid_psuManagementEntry = '.1.3.6.1.4.1.2011.2.82.1.82.100.4.2001.1';

sub load {
    my ($self) = @_;
    
    push @{$self->{request}}, { oid => $oid_psuManagementEntry };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => "Checking power supplies");
    $self->{components}->{psu} = {name => 'power supplies', total => 0, skip => 0};
    return if ($self->check_filter(section => 'psu'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_psuManagementEntry}})) {
        next if ($oid !~ /^$mapping->{mpsuHealth}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}->{$oid_psuManagementEntry}, instance => $instance);

        next if ($self->check_filter(section => 'psu', instance => $instance));
        $self->{components}->{psu}->{total}++;
        
        $self->{output}->output_add(long_msg => sprintf("Power supplies '%s' status is '%s' [instance = %s]",
                                    $result->{mpsuLocation}, $result->{mpsuHealth}, $instance, 
                                    ));
   
        my $exit = $self->get_severity(label => 'default', section => 'psu', value => $result->{mpsuHealth});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Power supplies '%s' status is '%s'", $result->{mpsuLocation}, $result->{mpsuHealth}));
        }
    }
}

1;