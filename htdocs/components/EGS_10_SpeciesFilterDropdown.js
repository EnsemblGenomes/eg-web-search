// $Revision: 1.2 $

Ensembl.Panel.SpeciesFilterDropdown = Ensembl.Panel.extend({  
  init: function () {
		$("select", this.el).change(function () {
			var selected = $("select option:selected").val()
			if(selected.length) {
				Ensembl.redirect(document.location.href + '&filter_species=' + selected);
			}
    });
  }
});
