$:.unshift File.dirname(__FILE__) + '/../lib'
require 'rack'
require 'rspec'
require 'oa-casport'
require 'fakeweb'
require 'httparty'
require 'redis'

RSpec.configure do |config|
  # some (optional) config here
end