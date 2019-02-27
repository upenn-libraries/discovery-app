$(document).ready(function() {
  $('#facet-group-selector').on('change', function(){
    selectID = 'facets_' + $(this).val();
    $('#facets .facet-group').each(function(idx, element) {
      facetGroup = $(element);
      if (element.id == selectID) {
        facetGroup.removeClass('hide');
      } else {
        facetGroup.addClass('hide');
      }
    });
  })
});
