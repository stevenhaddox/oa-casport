$:.push File.expand_path('lib', __FILE__)

require "oa-casport/version"
require 'omniauth/core'

module OmniAuth
  module Strategies
    autoload :Casport, 'omniauth/strategies/casport'
  end
end
