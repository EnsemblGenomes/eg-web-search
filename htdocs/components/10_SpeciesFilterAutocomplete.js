// $Revision: 1.4 $

Ensembl.Panel.SpeciesFilterAutocomplete = Ensembl.Panel.extend({  
  init: function () {
    // SPECIES AUTOCOMPLETE
    var panel = this;
    var ac = $("#species_autocomplete", this.el);
    var speciesList = eval($('#species_autocomplete_json', this.el).val());
    
    ac.autocomplete({
      minLength: 3,
      select: function(event, ui) { if (ui.item) Ensembl.redirect(document.location.href + '&filter_species=' + ui.item.value) },
      source: function( request, response ) { response( panel.filterArray( speciesList, request.term ) ) }
    }).submit(function() {
    	ac.autocomplete('search');
      return false;
    }).focus(function(){ 
    	// add placeholder text
      if($(this).val() == $(this).attr('title')) {
        ac.val('');
        ac.removeClass('inactive');
      } else if($(this).val() != '')  {
        ac.autocomplete('search');
      }
    }).blur(function(){
      // remove placeholder text
      ac.removeClass('invalid');
      ac.addClass('inactive');
      ac.val($(this).attr('title'));
    }).keyup(function(){
      // highlight invalid search strings
      if (ac.val().length >= 3) {
        var matches = panel.filterArray(speciesList, ac.val());
        if (matches && matches.length) {
          ac.removeClass('invalid');
        } else {
          ac.addClass('invalid');
        }
      } else {
        ac.removeClass('invalid');
      }
    }).data("ui-autocomplete")._renderItem = function (ul, item) {
      // highlight the term within each match
      var regex = new RegExp("(?![^&;]+;)(?!<[^<>]*)(" + $.ui.autocomplete.escapeRegex(this.term) + ")(?![^<>]*>)(?![^&;]+;)", "gi");
      item.label = item.label.replace(regex, "<strong>$1</strong>");
      return $("<li></li>").data("ui-autocomplete-item", item).append("<a>" + item.label + "</a>").appendTo(ul);
    };
    
    $(window).bind("unload", function() {}); // hack - this forces page to reload if user returns here via the Back Button

  },
  
  filterArray: function(array, term) {
    term = term.replace(/[^a-zA-Z0-9 ]/g, '').toUpperCase();
    var matcher = new RegExp( $.ui.autocomplete.escapeRegex(term), "i" );
    var matches = $.grep( array, function(value) {
      return matcher.test( value.replace(/[^a-zA-Z0-9 ]/g, '') );
    });
    matches.sort(function(a, b) {
      // give priority to matches that begin with the term
      var aBegins = a.toUpperCase().substr(0, term.length) == term;
      var bBegins = b.toUpperCase().substr(0, term.length) == term;
      if (aBegins == bBegins) {
        if (a == b) return 0;
        return a < b ? -1 : 1;
      }
      return aBegins ? -1 : 1;
    });
    return matches;   
  } 
});
