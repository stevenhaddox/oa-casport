require 'spec_helper'
#require File.expand_path(File.dirname(__FILE__) + '/../lib/omniauth/strategies/casport.rb')


describe "Casport" do
  before(:all) do
    FakeWeb.clean_registry
  end
  
  let(:app) { lamdba { |env| [200, {}, ['Test']] } }

  it "should have correct xml returned" do
    result = {'userinfo' => {'name' => 'Tyler Durden'}}
    userinfo = '<userinfo><name>Tyler Durden</name></userinfo>'
    FakeWeb.register_uri(:get, 'http://cas.dev/dn', :body => userinfo)
    options = {:dn => 'dn', :cas_server => 'http://cas.dev/'}
    user = OmniAuth::Strategies::Casport.new(app, options).user
    user.should == result
  end
end
