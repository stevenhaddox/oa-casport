require 'spec_helper'

describe OmniAuth::Strategies::Casport do

  app = lambda{|env| [200, {}, ["Hello World."]]}

  context "default client options" do
    subject do
      OmniAuth::Strategies::Casport.new(app)
    end

    it 'should have the correct name' do
      subject.options.name.should eq('casport')
    end

    it 'should have the correct site' do
      subject.options.client_options.cas_server.should eq("http://casport.dev")
    end

    it 'should have correct user authorize url' do
      subject.options.client_options.authorization_type.should eq('user')
      subject.options.client_options.authorize_path.should eq('/users')
    end

    context "success" do
      pending

      it "should return dn from raw_info if available" do
        subject.stub!(:raw_info).and_return({'dn' => 'givenName = Steven Haddox, ou = apache, ou = org'})
        subject.dn.should eq('givenName = Steven Haddox, ou = apache, ou = org')
      end

      it "should return email from raw_info if available" do
        subject.stub!(:raw_info).and_return({'email' => 'stevenhaddox@shortmail.com'})
        subject.email.should eq('stevenhaddox@shortmail.com')
      end

      it "should return nil if there is no raw_info and email access is not allowed" do
        subject.stub!(:raw_info).and_return({})
        subject.email.should be_nil
      end

      it "should return the first email if there is no raw_info and email access is allowed" do
        subject.stub!(:raw_info).and_return({})
        subject.options['scope'] = 'user'
        subject.stub!(:emails).and_return([ 'you@example.com' ])
        subject.email.should eq('you@example.com')
      end
    end

    context "failure" do
      pending
    end
  end

  context "group member authentication (AND SSL too!)" do
    subject do
      OmniAuth::Strategies::Casport.new(app, :client_options => {:cas_server => 'https://casport.dev', :authorization_type => 'group', :group_name => 'Developers'})
    end

    it 'should have custom options' do
      puts subject.options.client_options.inspect
    end

    it 'should have correct site' do
      subject.options.client_options.cas_server.should eq("https://casport.dev")
    end

    it 'should have correct group authorization url' do
      subject.options.client_options.authorization_type.should eq('group')
      subject.options.client_options.group_name.should eq('Developers')
      subject.options.client_options.authorization_path.should eq('https://casport.dev/groups/Developers')
    end

    context "success" do
      pending
    end

    context "failure" do
      pending
    end
  end
end
