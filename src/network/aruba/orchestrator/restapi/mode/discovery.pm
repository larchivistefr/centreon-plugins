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

package network::aruba::orchestrator::restapi::mode::discovery;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use JSON::XS;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'resource-type:s' => { name => 'resource_type' },
        'prettify'        => { name => 'prettify' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{resource_type}) || $self->{option_results}->{resource_type} eq '') {
        $self->{option_results}->{resource_type} = 'appliance';
    }
    if ($self->{option_results}->{resource_type} !~ /^appliance$/) {
        $self->{output}->add_option_msg(short_msg => 'unknown resource type');
        $self->{output}->option_exit();
    }
}

sub get_groups {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api(
        endpoint => '/gms/group'
    );
    my $groups = {};
    foreach (@$results) {
        $groups->{ $_->{id} } = { name => $_->{name}, parentId => $_->{parentId} }; 
    }

    return $groups;
}

sub get_group {
    my ($self, %options) = @_;

    my @groups = ();
    my $groupId = $options{groupId};
    while (defined($groupId)) {
        unshift(@groups, $options{groups}->{$groupId}->{name});
        $groupId = $options{groups}->{$groupId}->{parentId};
    }

    return join(' > ', @groups);
}

sub discovery_appliance {
    my ($self, %options) = @_;

    my $appliances = $options{custom}->request_api(endpoint => '/appliance');
    my $groups = $self->get_groups(custom => $options{custom});

    my $map_state = {
        0 => 'unknown', 1 => 'normal', 2 => 'unreachable',
        3 => 'unsupportedVersion', 4 => 'outOfSynchronization', 5 => 'synchronizationInProgress'
    };

    my $disco_data = [];
    foreach my $appliance (@$appliances) {
        my $node = {};
        $node->{uuid} = $appliance->{uuid};
        $node->{serial} = $appliance->{serial};
        $node->{hostname} = $appliance->{hostName};
        $node->{site} = $appliance->{site};
        $node->{model} = $appliance->{model};
        $node->{platform} = $appliance->{platform};
        $node->{ip} = $appliance->{ip};
        $node->{state} = $map_state->{ $appliance->{state} };
        $node->{group} = $self->get_group(groups => $groups, groupId => $appliance->{groupId});

        push @$disco_data, $node;
    }

    return $disco_data;
}

sub run {
    my ($self, %options) = @_;

    my $disco_stats;
    $disco_stats->{start_time} = time();

    my $results = [];
    if ($self->{option_results}->{resource_type} eq 'appliance') {
        $results = $self->discovery_appliance(
            custom => $options{custom}
        );
    }

    $disco_stats->{end_time} = time();
    $disco_stats->{duration} = $disco_stats->{end_time} - $disco_stats->{start_time};
    $disco_stats->{discovered_items} = scalar(@$results);
    $disco_stats->{results} = $results;

    my $encoded_data;
    eval {
        if (defined($self->{option_results}->{prettify})) {
            $encoded_data = JSON::XS->new->utf8->pretty->encode($disco_stats);
        } else {
            $encoded_data = JSON::XS->new->utf8->encode($disco_stats);
        }
    };
    if ($@) {
        $encoded_data = '{"code":"encode_error","message":"Cannot encode discovered data into JSON format"}';
    }
    
    $self->{output}->output_add(short_msg => $encoded_data);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1);
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Resources discovery.

=over 8

=item B<--resource-type>

Choose the type of resources to discover (Can be: 'appliance').

=back

=cut
