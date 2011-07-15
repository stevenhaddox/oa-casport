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
        @options[:cas_server]    ||= 'http://cas.dev/users/'
        @options[:format]        ||= 'xml'
        @options[:format_header] ||= 'application/xml'
      end

      def request_phase
        # Can't get user data without their UID for the CASPORT server 
#        raise "No UID set in request.env['omniauth.strategy'].options[:uid]" if @options[:uid].nil?
        Casport.setup_httparty(@options)
        url = URI.escape(@options[:cas_server] + @options[:uid].to_s)
        redirect(callback_path)
      end
    
      def callback_phase
        begin
          raise 'We seemed to have misplaced your credentials... O_o' if user.nil?
          super
        rescue => e
          redirect(request_path)
#          fail!(:invalid_credentials, e)
        end
        call_app!
      end

      def auth_hash
        user_obj = user['hash'] # store user in local var to prevent multiple method queries
ap user_obj
        OmniAuth::Utils.deep_merge(super, {
          'uid'       => user_obj['userinfo']['uid'],
          'user_info' => {
                          'name' => user_obj['userinfo']['fullName'],
                          'email' => user_obj['userinfo']['email']
                         },
          'extra'     => user_obj
        })
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
        if opts[:ssl_ca_file]
          ssl_ca_file opts[:ssl_ca_file]
          if opts[:pem_cert_pass]
            pem File.read(opts[:pem_cert]), opts[:pem_cert_pass]
          else
            pem File.read(opts[:pem_cert])
          end
        end
      end
      
      def user
        # Can't get user data without a UID from the application
        begin
          raise "No UID set in request.env['omniauth.strategy'].options[:uid]" if @options[:uid].nil?
        rescue => e
          fail!(:uid_not_found, e)
        end
        
        url = URI.escape(@options[:cas_server] + @options[:uid].to_s)
        begin
          cache = @options[:redis_options].nil? ? Redis.new : Redis.new(@options[:redis_options])
          unless @user = (cache.get @options[:uid].to_s)
            # User is not in the cache
            # Retrieving the user data from CASPORT
            # {'userinfo' => {{'uid' => UID}, {'fullName' => NAME},...}},
            @user = Casport.get(url).parsed_response
            cache.set @options[:uid].to_s, @user
            # CASPORT expiration time for user (24 hours => 1440 seconds)
            cache.expire @options[:uid].to_s, 1440
          end
        # If we can't connect to Redis...
        rescue Errno::ECONNREFUSED => e
          @user ||= Casport.get(url).parsed_response
        end
        @user = nil if empty_user?(@user)
        return eval(@user) unless @user.nil?
      end

      # Investigate user_obj to see if it's empty (or anti-pattern data)
      def empty_user?(user_obj)
        is_empty = false
        is_empty = true if user_obj.nil?
        is_empty = true if user_obj.empty?
        if user_obj.class == String
          case user_obj.to_s
            when "User has not been authenticated! Verify you are using 2-way SSL."
              is_empty = true
          end
        end
        is_empty == true ? true : nil
      end
    end

  end
end
