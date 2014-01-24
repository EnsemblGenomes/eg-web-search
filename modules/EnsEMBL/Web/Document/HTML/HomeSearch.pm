package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

use EnsEMBL::Web::Form;

sub render {
  my $self = shift;
  
  return if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;
  
  my $hub                 = $self->hub;
  my $species_defs        = $hub->species_defs;
  my $page_species        = $hub->species || 'Multi';
  my $species_name        = $page_species eq 'Multi' ? '' : $species_defs->DISPLAY_NAME;
  my $search_url          = $species_defs->ENSEMBL_WEB_ROOT . "$page_species/psychic";
  my $is_home_page        = $page_species eq 'Multi';
  my $is_bacteria         = $species_defs->GENOMIC_UNIT =~ /bacteria/i;
  my $default_search_code = $is_home_page ? 'ensemblunit' : 'ensemblthis';
  my $input_size          = $is_home_page ? 30 : 50;
  my $q                   = $hub->param('q');

  my $collection;
  if ($is_bacteria and !$species_name and !$is_home_page) {
    $collection = (split('/', $ENV{REQUEST_URI}))[1];
    $collection = undef unless grep {$_ eq $collection} @{$species_defs->ENSEMBL_DATASETS};
  }
  
  # form
  my $form = EnsEMBL::Web::Form->new({'action' => $search_url, 'method' => 'get', 'skip_validation' => 1, 'class' => [ $is_home_page ? 'homepage-search-form' : (), 'search-form', 'clear' ]});
  $form->add_hidden({'name' => 'site', 'value' => $default_search_code});

  # examples
  my $examples;
  my $sample_data;

  if ($is_home_page) {
    $sample_data = $species_defs->get_config('MULTI', 'GENERIC_DATA') || {};
  } else {
    $sample_data = { %{$species_defs->SAMPLE_DATA || {}} };
    $sample_data->{'GENE_TEXT'} = "$sample_data->{'GENE_TEXT'}" if $sample_data->{'GENE_TEXT'};
  }

  if (keys %$sample_data) {
    my $collection_param = $collection ? ";collection=$collection" : '';
    $examples = join ' or ', map { $sample_data->{$_}
      ? qq(<a class="nowrap" href="$search_url?q=$sample_data->{$_};site=$default_search_code$collection_param">$sample_data->{$_}</a>)
      : ()
    } qw(GENE_TEXT LOCATION_TEXT SEARCH_TEXT);
    $examples = qq(<p class="search-example">e.g. $examples</p>) if $examples;
  }

  # form field
  my $f_params = {'notes' => $examples};
  $f_params->{'label'} = 'Search' if $is_home_page;
  my $field = $form->add_field($f_params);

  # species dropdown
  if ($page_species eq 'Multi') {
    if ($is_bacteria) {
      $self->_add_collection_dropdown($field, $collection);
    } else {
      $self->_add_species_dropdown($field);
    }
  }

  # search input box & submit button
  my $q_params = {'type' => 'string', 'value' => $q, 'id' => 'q', 'size' => $input_size, 'name' => 'q', 'class' => 'query input inactive'};
  $q_params->{'value'} = "Search $species_name..." unless $is_home_page;
  $field->add_element($q_params, 1);
  $field->add_element({'type' => 'submit', 'value' => 'Go'}, 1);

  my $elements_wrapper = $field->elements->[0];
  $elements_wrapper->append_child('span', {'class' => 'inp-group', 'children' => [ splice @{$elements_wrapper->child_nodes}, 0, 2 ]})->after({'node_name' => 'wbr'}) for (0..1);

  return sprintf '<div id="SpeciesSearch" class="js_panel"><input type="hidden" class="panel_type" value="SearchBox" />%s</div>', $form->render;
}

sub _add_species_dropdown {
  my ($self, $field) = @_;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $favourites   = $hub->get_favourite_species;
  my %species      = map { $species_defs->get_config($_, 'DISPLAY_NAME') => $_ } @{$species_defs->ENSEMBL_DATASETS};
  my %common_names = reverse %species;

  $field->add_element({
    'type'    => 'dropdown',
    'name'    => 'species',
    'id'      => 'species',
    'class'   => 'input',
    'values'  => [
      {'value' => '', 'caption' => 'All species'},
      {'value' => '', 'caption' => '---', 'disabled' => 1},
      map({ $common_names{$_} ? {'value' => $_, 'caption' => $common_names{$_}, 'group' => 'Favourite species'} : ()} @$favourites),
      {'value' => '', 'caption' => '---', 'disabled' => 1},
      map({'value' => $species{$_}, 'caption' => $_}, sort { uc $a cmp uc $b } keys %species)
    ]
  }, 1)->first_child->after('label', {'inner_HTML' => 'for', 'for' => 'q'});
}

sub _add_collection_dropdown {
  my ($self, $field, $collection) = @_;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my %species; 
  my $display_name;
  foreach(@{$species_defs->ENSEMBL_DATASETS}) {
    (my $display_name = $species_defs->get_config($_, 'DISPLAY_NAME')) =~ s/_/ /; # hack for E/S
    $species{$display_name} = $_; 
  }
  my %common_names = reverse %species;

  $field->add_element({
    'type'    => 'dropdown',
    'name'    => 'collection',
    'id'      => 'species',
    'class'   => 'input',
    'values'  => [
      {'value' => '', 'caption' => 'All collections'},
      {'value' => '', 'caption' => '---', 'disabled' => 1},
      map({'value' => $species{$_}, 'caption' => $_, 'selected' => $_ eq $collection}, sort { uc $a cmp uc $b } keys %species)
    ]
  }, 1)->first_child->after('label', {'inner_HTML' => 'for', 'for' => 'q'});
}


1;
