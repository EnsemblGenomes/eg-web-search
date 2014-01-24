#!/usr/bin/env perl
use strict;
use warnings;

use File::Basename qw(dirname);
use FindBin qw($Bin);
use Data::Dumper;

BEGIN {
  my $serverroot = dirname($Bin) . "/../../";
  unshift @INC, "$serverroot/conf", $serverroot;
  
  require SiteDefs;
  
  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::DBSQL::WebsiteAdaptor;
  require EnsEMBL::Web::Hub;  
}

my $hub = new EnsEMBL::Web::Hub;
my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
my $sd  = $hub->species_defs;

# the keys to use in the index
my @INDEX_META_KEYS = qw(
  species.classification
  species.common_name
  species.production_name
  species.scientific_name
  species.alias
  species.division
  species.taxonomy_id
  assembly.name
  assembly.accession
  assembly.default
);

$dbh->do(
  'CREATE TABLE IF NOT EXISTS `species_search` (
    `species` varchar(255) NOT NULL,
    `name` varchar(255) NOT NULL,
    `genomic_unit` varbinary(50) NOT NULL,
    `keywords` text NOT NULL,
    `collection` varchar(50) default NULL,
    `taxonomy_id` varchar(50) default NULL,
    `assembly_name` varchar(50) default NULL,
    `ena_records` text default NULL,
    PRIMARY KEY  (`species`),
    FULLTEXT KEY `keywords` (`keywords`)
  ) ENGINE = MYISAM'
);

foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {   
  
  print "$dataset\n";

  my $species_data = get_species_data($dataset);

  foreach my $species (keys (%{$species_data})) {
    #print "Inserting $species\n";
    
    my $data = $species_data->{$species};
    
    $dbh->do("DELETE FROM species_search WHERE species = ?", undef, $species);
    $dbh->do(
      "INSERT INTO species_search SET species = ?, name = ?, genomic_unit = ?, collection = ?, assembly_name = ?, taxonomy_id = ?, keywords = ?, ena_records = ?", 
      undef,
      $species,
      $data->{name},
      $data->{genomic_unit},
      $data->{collection},
      $data->{assembly_name},
      $data->{taxonomy_id},
      join(' ', @{$data->{keywords}}, @{$data->{ena_records}}),
      join(' ', @{$data->{ena_records}}),
    );
  }
}

exit;

#------------------------------------------------------------------------------

# get hash of species/meta data
sub get_species_data {
  my $dataset = shift;
  my %data;
      
  my $adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core', $dataset);
  if (!$adaptor) {
    warn "core db doesn't exist for $dataset\n";
    return {};
  }
  
  # get collection name
  my $dbs = $sd->get_config($dataset, 'databases');
  my $db = $dbs->{DATABASE_CORE}->{NAME};
  my $collection;
  if ($db =~ /^(.+)_collection/i) {
    $collection = $1;  
  }  
  
  # process each species
  my $sth = $adaptor->prepare("SELECT DISTINCT species_id FROM meta WHERE species_id IS NOT null"); 
  $sth->execute;  
  
  while (my $id = $sth->fetchrow_array) {
    next unless my $production_name = get_meta_value($adaptor, $id, 'species.production_name');

    my %keywords;
    foreach my $meta_key (@INDEX_META_KEYS) {
      if (my @keywords = get_meta_value($adaptor, $id, $meta_key)) {
        foreach my $keyword (@keywords) {
          $keyword =~ s/_/ /;
          $keywords{$keyword} = 1;
        }
      }
    }

    my $genomic_unit = lc(get_meta_value($adaptor, $id, 'species.division'));
    $genomic_unit =~ s/^ensembl//; # eg EnsemblProtists -> protists
    
    $data{$production_name} = {
      id => $id,
      keywords => [keys %keywords],
      genomic_unit => $genomic_unit,
      collection => $collection,
      name => get_meta_value($adaptor, $id, 'species.display_name'),
      assembly_name => get_meta_value($adaptor, $id, 'assembly.name'),
      taxonomy_id => get_meta_value($adaptor, $id, 'species.taxonomy_id'),
      ena_records => [get_ena_records($adaptor, $id)],
    }   
  }

  return \%data;
}

# get value(s) for given meta key
sub get_meta_value {
  my ($adaptor, $species_id, $meta_key) = @_;
  my $sth = $adaptor->prepare("SELECT meta_value FROM meta WHERE species_id = ? AND meta_key = ?"); 
  $sth->execute($species_id, $meta_key);  
  my @values;
  while (my $value = $sth->fetchrow_array) {
    push @values, $value;
  }
  return wantarray ? @values : $values[0];
}

# fetch ena records using toplevel synonyms
sub get_ena_records {
  my ($adaptor, $species_id) = @_;
  
  my $sth = $adaptor->prepare(q{
    SELECT sr.name FROM seq_region sr 
    JOIN coord_system cs USING (coord_system_id) 
    WHERE cs.species_id= ? AND cs.name = 'contig'
    ORDER BY sr.name
  });
  $sth->execute($species_id);
  
  my @records;
  while (my $record = $sth->fetchrow_array) {
    push @records, $record;
  }
  
  return @records;
}


