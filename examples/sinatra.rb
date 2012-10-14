$:.push File.dirname(__FILE__) + '/../lib'

require 'oa-casport'
require 'sinatra'

use Rack::Session::Cookie
use OmniAuth::Builder do
  provider :casport, :client_options => {:cas_server => 'http://localhost:3000'}
end

get '/' do
  "<a href='/auth/casport'>Log in via CASPORT</a>"
end

get '/auth/casport/setup' do
  # replace request.env['SSL_CLIENT_S_DN'] with your web server's user DN string from SSL
  request.env['omniauth.strategy'].options[:dn] = '1'
  content_type 'text/plain'
  'Setup complete'
end

get '/auth/casport/callback' do
  content_type 'text/html'
  "<h2>Processed Response from CAS Server:</h2>"
  "<code><pre>"
  request.env['omniauth.auth'].inspect
  "</code></pre>"
end
