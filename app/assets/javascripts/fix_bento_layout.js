
$(document).ready(function() {
    // adjust column sizes so that bookmark checkboxes don't overflow their columns,
    // in the catalog results panel of bento box page. this is less terrible than adding
    // conditionals to the places where these classes are rendering in views.
    $('.catalog-results').find(".col-lg-10").removeClass("col-lg-10").addClass("col-lg-9");
    $('.catalog-results').find(".col-lg-2").removeClass("col-lg-2").addClass("col-lg-3");
});
