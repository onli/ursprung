require 'rubygems'
require 'bundler'

Bundler.require

# Enable persistent sessions using moneta ###
require 'moneta'
require 'rack/session/moneta'

use Rack::Session::Moneta,
    expire_after: 2592000,
    store: Moneta.new(:Sqlite, file: "sessions.db")


require './server.rb'
run Ursprung::Ursprung.new