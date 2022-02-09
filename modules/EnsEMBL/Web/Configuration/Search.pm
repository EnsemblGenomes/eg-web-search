=head1 LICENSE

Copyright [2009-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

# $Id: Search.pm,v 1.11 2013-02-12 12:19:49 nl2 Exp $

package EnsEMBL::Web::Configuration::Search;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  
  $self->{'_data'}{'default'} = 'New';
}

sub modify_page_elements {
  my $self = shift;
  my $page = $self->page;
  $page->remove_body_element('tool_buttons');
}


sub populate_tree {
  my $self   = shift;
  
  return unless $self->object;
  
  my $hub            = $self->hub;
  my $search         = $self->object->Obj;
  my $filter_species = $hub->param('filter_species') ? 'filter_species='.$hub->param('filter_species') : '';
  my $sp             = $hub->species =~ /^(multi|common)/i ? 'all species' : '<i>' . $hub->species_defs->species_display_label($hub->species) . '</i>';
  my $title          = "Search results for '" . $search->query_term . "'";

  $self->create_node('New', 'New Search',
    [qw(new EnsEMBL::Web::Component::Search::New)],
    { availability => 1, 'concise' => "Search $sp" }
  );

  my $hit_counts = $search->get_hit_counts;
  
  foreach my $index (sort keys %$hit_counts) {
    my $counts = $hit_counts->{$index};
    (my $display_index = ucfirst($index)) =~ s/_/ /;
    my $menu = $self->create_submenu( $index,  $display_index . " ($counts->{total})" );   

    foreach my $unit (sort {$search->unit_sort($a, $b)} keys %{$counts->{by_unit}}) {           
      my $site_name = $SiteDefs::EBEYE_SITE_NAMES->{lc($unit)} || ucfirst($unit);
      $menu->append( $self->create_subnode(
        "Results/${index}_$unit", "$site_name ($counts->{by_unit}->{$unit})",
        [ qw(results EnsEMBL::Web::Component::Search::Results) ],
        { 
          'availability' => 1, 
          'concise' => $title ,
          'url' => $hub->url({ action => "Results", function => "${index}_$unit" }) . ';' . $search->query_string . ';' . ($index ne 'genome' ? $filter_species : ''),
        }
      ));
    }
  }

  $self->create_node('Results', $title,
    [qw(results EnsEMBL::Web::Component::Search::Results)],
    { no_menu_entry => 1 }
  );
}

1;
