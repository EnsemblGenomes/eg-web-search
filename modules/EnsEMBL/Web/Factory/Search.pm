package EnsEMBL::Web::Factory::Search;

use strict;
use EBeyeSearch;
use CGI;
use base qw(EnsEMBL::Web::Factory);

sub createObjects {
  my $self = shift;
  my $ebeye = new EBeyeSearch($self->hub);
  $self->DataObjects($self->new_object('Search', $ebeye, $self->__data));
}

1;
