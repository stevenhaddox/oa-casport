require 'omniauth/core'
require 'httparty'
require 'redis'
require 'uri'

module OmniAuth
  module Strategies
    #
    # Authentication to CASPORT
    #
    # @example Basic Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #        :setup       => true, 
    #        :ssl_ca_file => 'path/to/ca_file.crt', 
    #        :pem_cert    => '/path/to/cert.pem'
    #      }
    # @example Full Options Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #        :setup         => true,
    #        :cas_server    => 'https://cas.dev',
    #        :format        => 'xml',
    #        :format_header => 'application/xml',
    #        :ssl_ca_file   => 'path/to/ca_file.crt',
    #        :pem_cert      => '/path/to/cert.pem',
    #        :pem_cert_pass => 'keep it secret, keep it safe.'
    #      }
    class Casport

      include OmniAuth::Strategy
      include HTTParty
      
      def initialize(app, options)
        super(app, :casport)
        @options = options
        @options[:cas_server]    ||= 'https://cas.dev/users/'
        @options[:ssl_ca_file]   ||= '/etc/pki/tls/certs/ca_cert.crt'
        @options[:format]        ||= 'xml'
        @options[:format_header] ||= 'application/xml'
        raise "oa-casport requires a PEM Cert!" unless @options[:pem_cert]
      end

      def request_phase
        # Can't get user data without their UID for the CASPORT server 
        raise "No UID set in request.env['omniauth.strategy'].options[:uid]" if @options[:uid].nil?
        Casport.setup_httparty(@options)
        url = URI.escape(@options[:cas_server] + @options[:uid]) 
        begin 
          cache = @options[:redis_options].nil? ? Redis.new : Redis.new(@options[:redis_options])
          unless @user = (cache.get @options[:uid])
            # User is not cached
            # Retrieving the user data from CASPORT
            # {"userinfo" => {{"dn"=>DN, {fullName=>NAME},...}},
            @user = Casport.get(url).parsed_response
            cache.set @options[:uid], @user
            # CASPORT expiration time for a user (24 hrs. => 1440 seconds)
            cache.expire @options[:uid], 1440
          end

        # If we can't connect to Redis...
        rescue Errno::ECONNREFUSED => e
          @user = Casport.get(url).parsed_response
        end
        @user = nil if @user && @user.empty? # sanity check to ensure we have a user, not just empty data
      end
    
      def callback_phase
        begin
          super
        rescue => e
          fail!(:invalid_credentials, e)
        end
      end

      def auth_hash
        if @user
          OmniAuth::Utils.deep_merge(super, {
            'uid'       => @user[userinfo][uid],
            'user_info' => {"name" => @user[userinfo][fullName]},
            'extra'     => @user
          })
        end
      end

      # Set HTTParty params that we need to set after initialize is called
      # These params come from @options within initialize and include the following:
      # :ssl_ca_file - SSL CA File for SSL connections
      # :format - 'json', 'xml', 'html', etc. || Defaults to 'xml'
      # :format_header - :format Header string || Defaults to 'application/xml'
      # :pem_cert - /path/to/a/pem_formatted_certificate.pem for SSL connections
      # :pem_cert_pass - plaintext password, not recommended!
      def self.setup_httparty(opts)
        format opts[:format].to_sym
        headers 'Accept' => opts[:format_header]
        ssl_ca_file opts[:ssl_ca_file]
        unless opts[:pem_cert_pass].nil?
          pem File.read(opts[:pem_cert]), opts[:pem_cert_pass]
        else
          pem File.read(opts[:pem_cert]
        end
      end
    
    end

  end
end
