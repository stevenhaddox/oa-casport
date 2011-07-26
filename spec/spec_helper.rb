require 'rubygems'
require 'bundler/setup'

require 'fakeweb'
require 'oa-casport'
require 'httparty'
require 'redis'

RSpec.configure do |config|
  # some (optional) config here
end

before(:each) do
  FakeWeb.clean_registry
end
