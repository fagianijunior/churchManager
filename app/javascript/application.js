// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "jquery"
import "@fortawesome/fontawesome-free"

import "chartkick"
import "Chart.bundle"

// Import user search component
import "user_search"
// Import amount handler component
import "amount_handler"
// Import debug script (temporary)
import "debug_user_search"

import jquery from 'jquery'
window.jQuery = jquery
window.$ = jquery