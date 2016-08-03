# Copyright 2015 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets 
# the needs in IT infrastructure and application monitoring for 
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0  
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package centreon::vmware::cmdbase;

use strict;
use warnings;

my %handlers = (ALRM => {});

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;
    
    $self->{logger} = $options{logger};
    $self->{case_insensitive} = defined($options{case_insensitive}) ? $options{case_insensitive} : 0;
    
    return $self;
}

sub getCommandName {
    my $self = shift;
    return $self->{commandName};
}

sub set_signal_handlers {
    my $self = shift;

    $SIG{ALRM} = \&class_handle_ALRM;
    $handlers{ALRM}->{$self} = sub { $self->handle_ALRM() };
}

sub class_handle_ALRM {
    foreach (keys %{$handlers{ALRM}}) {
        &{$handlers{ALRM}->{$_}}();
    }
}

sub handle_ALRM {
    my $self = shift;
    
    $self->{logger}->writeLogError("Child process autokill!!");
    exit(0);
}

sub set_connector {
    my ($self, %options) = @_;
    
    $self->{connector} = $options{connector};
    $self->set_signal_handlers();
    alarm(300);
}

sub build_filter {
    my ($self, %options) = @_;
    
    my $filters = {};
    if (defined($self->{$options{search_option}}) && !defined($self->{$options{is_regexp}})) {
        if ($self->{case_insensitive} == 1) {
            $filters->{name} = qr/^\Q$self->{$options{search_option}}\E$/i;
        } else {
            $filters->{name} = qr/^\Q$self->{$options{search_option}}\E$/;
        }
    } elsif (!defined($self->{$options{search_option}})) {
        $filters->{name} = qr/.*/;
    } else {
        if ($self->{case_insensitive} == 1) {
            $filters->{name} = qr/$self->{$options{search_option}}/i;
        } else {
            $filters->{name} = qr/$self->{$options{search_option}}/;
        }
    }
    
    return $filters;
}

1;
