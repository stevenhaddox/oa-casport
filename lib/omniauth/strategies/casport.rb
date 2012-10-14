#require 'multi_xml'
#require 'multi_json'
require 'omniauth'
require 'redis'
require 'uri'
require 'yaml'

module OmniAuth
  module Strategies
    #
    # Authentication to CASPORT
    #
    # @example Basic Usage
    #
    #  use OmniAuth::Strategies::Casport
    #
    # @example Full Options Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #    :cas_server    => 'http://cas.slkdemos.com/users/',
    #    :format        => 'json', 'xml', 'html', etc. || Defaults to 'xml'
    #    :format_header => 'application/json', 'application/xml' || Defaults to 'application/xml'
    #    :redis_options => 'disabled' or opts: {:host => '127.0.0.1', :port => 6739} || Default is 'disabled'
    #    :ssl_ca_file   => 'path/to/ca_file.crt',
    #    :pem_cert      => '/path/to/cert.pem',
    #    :pem_cert_pass => 'keep it secret, keep it safe.',
    #  }
    class Casport
      include OmniAuth::Strategy

      option :name, 'casport'
      option :uid_field, :dn
      option :setup, true

      # Default values for Casport client
      option :client_options, {
        'cas_server'         => 'http://casport.dev',
        'format'             => 'xml',
        'format_header'      => 'application/xml',
        'authorization_type' => 'user'
      }

      def authorization_path
        if options.client_options[:authorization_path].nil?
          auth_path = case options.client_options[:authorization_type]
          when 'group'
            #TODO
            "/groups/#{options.client_options[:group_name]}/"
          when 'user'
            '/users'
          end
        else
          auth_path = options.client_options[:authorization_path]
        end
      end

      def request_phase
        raise "No UID set in request.env['omniauth.strategy'].options[:dn]" if options.dn.nil?
        # Request JSON / XML object via multi_json or multi_xml

        # Return response to the callback_url
        redirect callback_url
        #redirect "#{options.client_options.cas_server}#{authorization_path}/#{options.dn}"
      end

#      uid { request.params[options.uid_field.to_s] }

#      info do
#        options.fields.inject({}) do |hash, field|
#          hash[field] = request.params[field]
#          hash
#        end
#      end

      def callback_phase
        puts '!'*80
        puts 'IN #callback_phase'
        puts '!'*80

        super
      end

      def auth_hash
        # store user in a local var to avoid new method calls for each attribute
        user_obj = user
        begin
          # convert all Java camelCase keys to Ruby snake_case, it just feels right!
          user_obj = user_obj['userinfo'].inject({}){|memo, (k,v)| memo[k.gsub(/[A-Z]/){|c| '_'+c.downcase}] = v; memo}
        rescue => e
          fail!(:invalid_user, e)
        end
        OmniAuth::Utils.deep_merge(super, {
          'uid'       => user_obj['dn'],
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
        headers 'Accept'               => opts[:format_header]
        headers 'Content-Type'         => opts[:format_header]
        headers 'X-XSRF-UseProtection' => 'false' if opts[:format] == 'json'
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
          # Fix DN order (if we have a DN) for CASPORT to work properly
          if @options[:uid].include?('/') or @options[:uid].include?(',')
            # Convert '/' to ',' and split on ','
            @options[:uid] = @options[:uid].gsub('/',',').split(',').reject{|array| array.all? {|el| el.nil? || el.strip.empty? }}
            # See if the DN is in the order CASPORT expects (and fix it if needed)
            @options[:uid] = @options[:uid].reverse if @options[:uid].first.downcase.include? 'c='
            # Join our array of DN elements back together with a comma as expected by CASPORT
            @options[:uid] = @options.join ','
          end
        rescue => e
          fail!(:uid_not_found, e)
        end

        begin
          raise Errno::ECONNREFUSED if @options[:redis_options] == 'disabled'
          cache = @options[:redis_options].nil? ? Redis.new : Redis.new(@options[:redis_options])
          unless @user = (cache.get @options[:uid])
            # User is not in the cache
            # Retrieving the user data from CASPORT
            # {'userinfo' => {{'uid' => UID}, {'fullName' => NAME},...}},
            get_user
            if @user
              # Set Redis object for the user, and expire after 24 hours
              cache.set @options[:uid], @user.to_yaml
              cache.expire @options[:uid], 1440
            end
          else
            # We found our user in the cache, let's parse it into a Ruby object
            @user = YAML::load(@user)
          end
        # If we can't connect to Redis...
        rescue Errno::ECONNREFUSED => e
          get_user
        end
        @user
      end

      # Query for the user against CASPORT, return as nil or parsed object
      def get_user
        return if @user # no extra http calls
        url = URI.escape("#{@options[:cas_server]}/#{@options[:uid]}.#{@options[:format]}")
        response = Casport.get(url)
        if response.success?
          @user = response.parsed_response
        else
          @user = nil
        end
      end

    end
  end
end
