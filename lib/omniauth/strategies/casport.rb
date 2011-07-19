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
    #        :setup       => true
    #      }
    # @example Full Options Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #        :setup         => true,
    #        :cas_server    => 'http://cas.slkdemos.com/users/',
    #        :format        => 'xml',
    #        :format_header => 'application/xml',
    #        :ssl_ca_file   => 'path/to/ca_file.crt',
    #        :pem_cert      => '/path/to/cert.pem',
    #        :pem_cert_pass => 'keep it secret, keep it safe.'
    #      }
    class Casport

      include OmniAuth::Strategy
      include HTTParty

      debug_output $stderr
      
      def initialize(app, options)
        super(app, :casport)
        @options = options
        @options[:cas_server]    ||= 'http://cas.dev/users'
        @options[:format]        ||= 'xml'
        @options[:format_header] ||= 'application/xml'
      end

      def request_phase
#        begin
#          # Can't get user data without their UID for the CASPORT server 
#          raise "No UID set in request.env['omniauth.strategy'].options[:uid]" if @options[:uid].nil?
#        rescue StandardError => e
#          fail!(:uid_not_found, e)
#        end
        Casport.setup_httparty(@options)
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
        # store user in a local var to avoid new method calls for each attribute
        # convert all Java camelCase keys to Ruby snake_case, it just feels right!
        user_obj = user.inject({}){|memo, (k,v)| memo[k.gsub(/[A-Z]/){|c| '_'+c.downcase}] = v; memo}
        begin
          user_obj = user_obj['userinfo']
        rescue => e
          fail!(:invalid_user, e)
        end
        OmniAuth::Utils.deep_merge(super, {
          'uid'       => user_obj['uid'],
          'user_info' => {
                          'name' => user_obj['full_name'],
                          'email' => user_obj['email']
                         },
          'extra'     => {'user_hash' => user_obj}
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
          @options[:uid] = @options[:uid].to_s
        rescue => e
          fail!(:uid_not_found, e)
        end

        url = URI.escape("#{@options[:cas_server]}/#{@options[:uid]}.#{@options[:format]}")
        begin
          cache = @options[:redis_options].nil? ? Redis.new : Redis.new(@options[:redis_options])
          unless @user = (cache.get @options[:uid])
            # User is not in the cache
            # Retrieving the user data from CASPORT
            # {'userinfo' => {{'uid' => UID}, {'fullName' => NAME},...}},
            @user = Casport.get(url).parsed_response
            cache.set @options[:uid], @user
            # CASPORT expiration time for user (24 hours => 1440 seconds)
            cache.expire @options[:uid], 1440
          end
        # If we can't connect to Redis...
        rescue Errno::ECONNREFUSED => e
          @user ||= Casport.get(url).parsed_response
        end
        @user = nil if user_empty?
        @user
      end

      # Investigate user_obj to see if it's empty (or anti-pattern data)
      def user_empty?
        is_empty = false
        is_empty = true if @user.nil?
        is_empty = true if @user.empty?
        # If it isn't empty yet, let's convert it into a Hash object for easy parsing via eval
        unless @user.class == Hash
          is_empty = true
          raise "String returned when a Hash was expected."
        end
        is_empty == true ? true : nil
      end
      
    end
  end
end
