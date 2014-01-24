package EG::EBEyeSearch::SiteDefs;
use strict;

sub update_conf {   
    
    $SiteDefs::EBEYE_FILTER = 1;  
    $SiteDefs::EBEYE_FILTER_AUTOCOMPLETE = 0;
    
    $SiteDefs::EBEYE_SEARCH_UNITS = [qw(bacteria fungi metazoa plants protists)];
    
    $SiteDefs::EBEYE_SITE_NAMES = {
      ena      => 'ENA',
      microme  => 'Microme',
      bacteria => 'Ensembl Bacteria',
      fungi    => 'Ensembl Fungi',
      metazoa  => 'Ensembl Metazoa',
      plants   => 'Ensembl Plants',
      protists => 'Ensembl Protists',
      ensembl  => 'Ensembl',
    };
    
}   

1;
