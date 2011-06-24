require 'omniauth/core'
require 'httparty'
require 'redis'

module OmniAuth
  module Strategies
    #
    #
    # @example Basic Usage
    #
    #  use OmniAuth::Strategies::Casport, {:setup => true, :ssl_ca_file => 'path/to/ca_file.crt', :pem_cert => '/path/to/cert.pem'}
    class Casport

      include OmniAuth::Strategy
      include HTTParty
      format :xml
      headers 'Accept' => 'application/rdf+xml'
      
      def initialize(app, options)
        super(app, :casport)
        @options = options
        @options[:cas_server]    ||= 'https://some.server.com/ld/v1/users/'
        @options[:ssl_ca_file]   ||= '/etc/pki/tls/certs/ca_cert.crt'
        @options[:pem_cert]      ||= nil
        @options[:pem_cert_pass] ||= nil
        raise "oa-casport requires a PEM Cert!" unless @options[:pem_cert]
      end

      def request_phase
        # Grab the DN
        dn = 'stevenhaddox' #TODO
        Casport.setup_httparty(@options)
        
        begin 
          cache = @options[:redis_options].nil? ? Redis.new : Redis.new(@options[:redis_options])
          unless @user = (cache.get dn)
            # User is not cached
            # Retrieving the user data from CASPORT
            # {"userinfo" => {{"dn"=>DN, {fullName=>NAME},...}},
            @user = Casport.get(@options[:cas_server] << dn).parsed_response
            cache.set dn, @user
            # CASPORT expiration time for a user (24 hrs. => 1440 seconds)
            cache.expire dn, 1440
          end

        # If we can't connect to Redis...
        rescue Errno::ECONNREFUSED => e
          @user = Casport.get(@options[:cas_server] << dn).parsed_response
        end
        raise @user.to_yaml
      end
    
      def callback_phase
        begin
          super
        rescue => e
          fail!(:invalid_credentials, e)
        end
      end

      def auth_hash
        OmniAuth::Utils.deep_merge(super, {
          'uid'       => @user[userinfo][uid],
          'user_info' => {"name" => @user[userinfo][fullName]},
          'extra'     => @user
        })
      end

      # Set HTTParty params that aren't available until after initialize is called
      def self.setup_httparty(opts)
        ssl_ca_file opts[:ssl_ca_file]
        pem File.read(opts[:pem_cert]
      end
    
    end

  end
end
