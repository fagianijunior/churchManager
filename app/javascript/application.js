// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "jquery"
import "@fortawesome/fontawesome-free"

import "chartkick"
import "Chart.bundle"

import jquery from 'jquery'
window.jQuery = jquery
window.$ = jquery

// When load page
if($('#transaction_wallet_id option:selected').text() != "Dízimos") {
  // hide Users if noy selected
  $('#transaction_user_id_group').hide();
} else {
  // Disable type of saida if users is selected
  $('#transaction_kind_of').children('option[value=saida]')
  .attr('disabled', true).siblings().removeAttr('disabled');
  $('#transaction_kind_of').val(['entrada']);
}

$('#transaction_wallet_id').change(function() {
  if($('#transaction_wallet_id option:selected').text() == 'Dízimos') {
    // If wallet is Dízimos, then show Users and hide type_of saida
    $('#transaction_user_id_group').show();
    $('#transaction_kind_of').children('option[value=saida]')
      .attr('disabled', true).siblings().removeAttr('disabled');
    $('#transaction_kind_of').val(['entrada']);
  } else {
    // Remove value from users, hide it and enable type_of saida.
    $('#transaction_user_id').val([]);
    $('#transaction_user_id_group').hide();
    $('#transaction_kind_of').children('option[value=saida]')
      .attr('disabled', false).siblings().removeAttr('disabled');
  };
});