require 'rubygems'
require 'bundler'

Bundler.require

require './server.rb'
run Dsnblog::Dsnblog.new