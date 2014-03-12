#!/usr/bin/env perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use File::Basename qw(dirname);
use FindBin qw($Bin);
use Getopt::Long;

use lib '../eg-web-common/utils/'
use LibDirs;
use EnsEMBL::Web::DBSQL::WebsiteAdaptor;
use EnsEMBL::Web::Hub;  


my $nodelete;
GetOptions ("nodelete" => \$nodelete);

my $hub = new EnsEMBL::Web::Hub;
my $dbh = new EnsEMBL::Web::DBSQL::WebsiteAdaptor($hub)->db;
my $sd  = $hub->species_defs;
my $genomic_unit = $sd->GENOMIC_UNIT;

$dbh->do(
  'CREATE TABLE IF NOT EXISTS `seq_region_search` (
    `id` int NOT NULL AUTO_INCREMENT ,
    `seq_region_name` varchar(40) NOT NULL,
    `location` varchar(255) NOT NULL,
    `coord_system_name` varchar(40) NOT NULL,
    `species_name` varchar(255) NOT NULL,
    `genomic_unit` varchar(50) NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `seq_region_name` (`seq_region_name`) USING BTREE, 
    INDEX `seq_region_name_genomic_unit` (`seq_region_name`, `genomic_unit`) USING BTREE, 
    INDEX `seq_region_name_species_name` (`seq_region_name`, `species_name`) USING BTREE 
  )'
);

unless ($nodelete) {
  print "Deleting old seq regions for all $genomic_unit\n";
  $dbh->do("DELETE FROM seq_region_search WHERE genomic_unit = ?", undef, $genomic_unit);
}

foreach my $dataset (@ARGV ? @ARGV : @$SiteDefs::ENSEMBL_DATASETS) {   
  
  print "$dataset\n";
  
  my $seq_regions = get_seq_regions($dataset);
  
  my @insert;
  foreach my $sr (@$seq_regions) {
    my $max_len = 100000;
    my $location = $sr->{asm_seq_region_name} ?
      sprintf('%s:%s-%s', $sr->{asm_seq_region_name}, $sr->{asm_start}, $sr->{asm_end} > $sr->{asm_start} + $max_len - 1 ? $sr->{asm_start} + $max_len - 1 : $sr->{asm_end}) :
      sprintf('%s:%s-%s', $sr->{seq_region_name}, '1', $sr->{length} > $max_len ? $max_len : $sr->{length});
      
    push(@insert, sprintf('(%s, %s, %s, %s, %s)', 
      $dbh->quote($sr->{seq_region_name}),
      $dbh->quote($location),
      $dbh->quote($sr->{coord_system_name}),
      $dbh->quote($sr->{species_name}), 
      $dbh->quote($genomic_unit)
    ));
  }
  
  # insert in batches of 10,000
  while (@insert) {
    my $values = join(',', splice(@insert, 0, 10000));
    $dbh->do("INSERT INTO seq_region_search (seq_region_name, location, coord_system_name, species_name, genomic_unit) VALUES $values");
    #print "remaining " . (scalar @insert) . "\n";
  }  
}

print "Optimising table...\n";
$dbh->do("OPTIMIZE TABLE seq_region_search");

print "Done\n";

exit;

#------------------------------------------------------------------------------

sub get_seq_regions {
  my $dataset = shift;
  my @seq_regions;
  
  my $adaptor = $hub->get_adaptor('get_GeneAdaptor', 'core', $dataset);
  if (!$adaptor) {
    warn "core db doesn't exist for $dataset\n";
    next;
  }
  
  my %species_name;   
  my $sth = $adaptor->prepare("SELECT species_id, meta_value FROM meta WHERE meta_key = 'species.production_name'");
  $sth->execute();  
  while (my ($id, $name) = $sth->fetchrow_array) {
    $species_name{$id} = $name;
  }
  
  # get seq regions from top 2 levels - along with mapping to top level 
  $sth = $adaptor->prepare(
    "SELECT DISTINCT sr.name AS seq_region_name, sr.length, asm.name AS asm_seq_region_name, cmp.asm_start, cmp.asm_end, cs.name AS coord_system_name, cs.species_id
     FROM seq_region sr JOIN coord_system cs USING (coord_system_id)
     LEFT JOIN assembly cmp ON cmp.cmp_seq_region_id = sr.seq_region_id
     LEFT JOIN seq_region asm ON asm.seq_region_id = cmp.asm_seq_region_id
     LEFT JOIN seq_region_attrib sra ON sra.seq_region_id = asm.seq_region_id
     LEFT JOIN attrib_type `at` USING(attrib_type_id) 
     WHERE (at.name = 'Top Level' OR at.name IS NULL)
     AND cs.name != 'chunk' AND cs.name != 'ignored'
     AND FIND_IN_SET('default_version', cs.attrib)"
  ); 
  $sth->execute;  
  
  while (my $row = $sth->fetchrow_hashref) {
    $row->{species_name} = $species_name{$row->{species_id}},
    push @seq_regions, $row;  
  }
  
  return \@seq_regions;
}

