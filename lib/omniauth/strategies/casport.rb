require 'omniauth'
require 'uri'
require 'yaml'
require 'httparty'

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
    #    :ssl_ca_file   => 'path/to/ca_file.crt',
    #    :pem_cert      => '/path/to/cert.pem',
    #    :pem_cert_pass => 'keep it secret, keep it safe.',
    #  }
    class Casport
      include OmniAuth::Strategy

      option :uid_field, 'dn'
      option :setup, true
      option :cas_server, 'http://default_setting_changeme.casport.dev'
      option :ssl_ca_file, nil
      option :pem_cert, 'default_path_changeme/path/to/cert.pem'
      option :pem_cert_pass, nil
      option :format_header, 'application/json'
      option :format, 'json'
      option :dn_header, 'HTTP_SSL_CLIENT_S_DN'
      option :debug, nil
      option :log_file, nil
      option :fake_dn, nil

      CASPORT_DEFAULTS = {
        :dn => nil,
        :fullName => nil,
        :lastName => nil,
        :uid => nil,
        :firstName => "",
        :displayName => "",
        :title => "",
        :email => "",
        :employee_id => "",
        :personal_title => "",
        :telephone_number => "",
      }

      @user = {}
      @user_uid = ""

      def request_phase
        if !$LOG && @options[:debug] && @options[:log_file]
          require 'logger'
          $LOG ||= Logger.new(@options[:log_file])
        end
        $LOG.debug "#request_phase IN, user_uid: '#{@user_uid}', reqenv: #{request.env[@options[:dn_header]]}" if $LOG

        # Setup HTTParty
        $LOG.debug "Setting up HTTParty" if $LOG
        CasportHTTParty.setup_httparty @options

        # Call to fill the user object
        get_user

        # Return response to the callback_url
        $LOG.debug "#request_phase OUT" if $LOG
        redirect callback_url
      end

      def auth_hash
        $LOG.debug "#auth_hash IN, user_uid: '#{@user_uid}', reqenv: #{request.env[@options[:dn_header]]}" if $LOG
        user_obj = get_user

        $LOG.debug "#auth_hash OUT" if $LOG
        username = user_obj['firstName']+" "+user_obj['lastName']
        OmniAuth::Utils.deep_merge(super, {
          'uid' => user_obj[@options[:uid_field]],
          'info' => {
            'name' => username,
            'email' => user_obj['email']
          },
          'extra'     => {'user_hash' => user_obj}
        })
      end

      # Query for the user against CASPORT, return as nil or parsed object
      def get_user
        $LOG.debug "#get_user IN, user_uid: '#{@user_uid}', reqenv: #{request.env[@options[:dn_header]]}" if $LOG
        return if @user # no extra http calls

        $LOG.debug "Must get user from CASPORT" if $LOG
        #$LOG.debug @options[:fake_dn].nil?

        if @user_uid.nil? or @user_uid.empty?
          # Checking for DN
          if request.env[@options[:dn_header]].nil? or request.env[@options[:dn_header]].empty? and @options[:fake_dn].nil?
            # No clue what the DN or UID is...
            $LOG.debug @options[:fake_dn]
            $LOG.debug "#request_phase Error: No DN provided for UID in request.env[#{@options[:dn_header]}]" if $LOG
            raise "#request_phase Error: No DN provided for UID"
          else
            # Set UID to DN
           if !@options[:fake_dn].nil?
            @user_uid=@options[:fake_dn]
           else
            @user_uid = request.env[@options[:dn_header]]
            end
          end
        end
        # Fix DN order (if we have a DN) for CASPORT to work properly
        if @user_uid.include?('/') or @user_uid.include?(',')
          # Convert '/' to ',' and split on ','
          @user_uid = @user_uid.gsub('/',',').split(',').reject{|array| array.empty? }
          # See if the DN is in the order CASPORT expects (and fix it if needed)
          @user_uid = @user_uid.reverse if @user_uid.first.downcase.include? 'c='
          # Join our array of DN elements back together with a comma as expected by CASPORT
          @user_uid = @user_uid.join(',')
        end
        url = URI.escape("#{@options[:cas_server]}/#{@user_uid}")
        puts "#get_user Requesting URI: #{url}"
        $LOG.debug "#get_user Requesting URI: #{url}" if $LOG
        response = CasportHTTParty.get(url)
        if response.success?
          $LOG.debug "#get_user Response:  Success!" if $LOG
          $LOG.debug "#get_user response contents: #{response}" if $LOG
          $LOG.debug "#get_user OUT" if $LOG
          @user = response.parsed_response
        else
          $LOG.error "#get_user Response: failure." if $LOG
          @user = nil
        end
      end
    end

    #Helper class to setup HTTParty, as OmniAuth 1.0+ seems to conflict with HTTParty.
    class CasportHTTParty
      include HTTParty

      def self.setup_httparty(options)
        options[:format]        ||= 'json'
        options[:format_header] ||= 'application/json'

        headers 'Accept'       => options[:format_header]
        headers 'Content-Type' => options[:format_header]
        headers 'X-XSRF-UseProtection' => 'false' if options[:format_header]
        if options[:ssl_ca_file]
          ssl_ca_file options[:ssl_ca_file]
          if options[:pem_cert_pass]
            pem File.read(options[:pem_cert]), options[:pem_cert_pass]
          else
            pem File.read(options[:pem_cert])
          end
        end
      end
    end

  end
end
