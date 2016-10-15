window.jazzy = {'docset': false}
if (typeof window.dash != 'undefined') {
  document.documentElement.className += ' dash'
  window.jazzy.docset = true
}
if (navigator.userAgent.match(/xcode/i)) {
  document.documentElement.className += ' xcode'
  window.jazzy.docset = true
}

var slideContent = function(link) {
  link
    .parent().parent().next()
    .slideToggle(300);
}

// On doc load, toggle the URL hash discussion if present
$(document).ready(function() {
  if (!window.jazzy.docset && window.location.hash) {
    slideContent(
      $('a[name="' + window.location.hash.substring(1) +'"]'));
  }
});

// On token click, toggle its discussion and animate token.marginLeft
$(".token").click(function(event) {
  if (window.jazzy.docset) {
    return;
  }
  
  slideContent($(this));

  // Keeps the document from jumping to the hash.
  var href = $(this).attr('href');
  if (history.pushState) {
    history.pushState({}, '', href);
  } else {
    location.hash = href;
  }
  event.preventDefault();
});
