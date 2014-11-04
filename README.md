[![Gem Version](https://badge.fury.io/rb/oa-casport.svg)](http://badge.fury.io/rb/oa-casport)
[![Build Status](https://travis-ci.org/stevenhaddox/oa-casport.svg)](https://travis-ci.org/stevenhaddox/oa-casport)
[![Code Climate](https://codeclimate.com/github/stevenhaddox/oa-casport/badges/gpa.svg)](https://codeclimate.com/github/stevenhaddox/oa-casport)

# oa-casport

The goal of this gem is to allow CASPORT integartion with your rack-based application easily through OmniAuth.

## Installation

Add the following line to your Gemfile:

  gem 'oa-casport'

## Configuration Parameters:

Configuration within the initializer for OmniAuth:

    # @example Basic Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #    :setup => true
    #  }
    # 
    # @example Full Options Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #    :setup         => true,
    #    :cas_server    => 'http://cas.slkdemos.com/users/',
    #    :format        => 'json', 'xml' || Defaults to 'xml'
    #    :format_header => 'application/xml', 'application/json' || Defaults to 'application/xml'
    #    :ssl_ca_file   => 'path/to/ca_file.crt',
    #    :pem_cert      => '/path/to/cert.pem',
    #    :pem_cert_pass => 'keep it secret, keep it safe.',
    #    :redis_options => 'disabled'
    #  }

## Example Applications

You can see how to set it up and use it with a Rails 3 application at: [https://github.com/stevenhaddox/oa-casport-rails3](https://github.com/stevenhaddox/oa-casport-rails3)

\#TODO: You can see how to set it up and use it with a Sinatra application at: [https://github.com/stevenhaddox/oa-casport-sinatra](https://github.com/stevenhaddox/oa-casport-sinatra)

