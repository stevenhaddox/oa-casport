require 'omniauth'
require 'uri'
require 'yaml'
require 'json'
require 'multi_xml'
require 'net/http'

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
    #    :format        => 'json', 'xml', 'html', etc. || Defaults to 'json'
    #    :format_header => 'application/json', 'application/xml' || Defaults to 'application/json'
    #    :ssl_ca_file   => 'path/to/ca_file.crt',
    #    :client_cert      => '/path/to/cert.pem',
    #    :client_key      => '/path/to/cert.key',
    #    :client_key_pass      => 'keep it secret, keep it safe.',
    #  }
    class Casport
      include OmniAuth::Strategy

      option :uid_field, 'dn'
      option :setup, false
      option :cas_server, 'http://default_setting_changeme.casport.dev'
      option :ssl_ca_file, nil
      option :client_cert, 'default_path_changeme/path/to/cert.cer'
      option :client_key, 'default_path_changeme/path/to/cert.key'
      option :client_key_pass, nil
      option :format_header, 'application/json'
      option :format, 'json'
      option :dn_header, 'HTTP_SSL_CLIENT_S_DN'
      option :issuer_dn_header, 'HTTP_SSL_CLIENT_I_DN'
      option :ssl_version, :SSLv3
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
        @user_uid = split_reverse_dn(@user_uid)
        @user_issuer_dn = split_reverse_dn(request.env[@options[:issuer_dn_header]])

        url_text = "#{@options[:cas_server]}/#{@user_uid}"
        url_text += "?issuerDn=#{@user_issuer_dn}" unless @user_issuer_dn.nil?
        url = URI(URI.escape("url_text"))
        puts "#get_user Requesting URI: #{url}"
        $LOG.debug "#get_user Requesting URI: #{url}" if $LOG
        response = call_casport (url)
        case response
        when Net::HTTPSuccess then
          $LOG.debug "#get_user response contents: #{response.inspect}" if $LOG
          case @options[:format]
          when 'json' then
            @user = JSON.parse(response.body)
          when 'xml' then
            @user = MultiXml.parse(response.body)
          else
            @user = response.body
          end
          $LOG.debug "#get_user Parsed user: #{@user.inspect}" if $LOG
          $LOG.debug "#get_user OUT" if $LOG
          @user
        else
          $LOG.error "#get_user Response: failure. Response was: #{response.inspect}" if $LOG
          @user = nil
          @user
        end
      end

      protected

      def split_reverse_dn (dn)
        if !dn.nil? and (dn.include?('/') or dn.include?(','))
          # Convert '/' to ',' and split on ','
          dn = dn.gsub('/',',').split(',').reject{|array| array.empty? }
          # See if the DN is in the order CASPORT expects (and fix it if needed)
          dn = dn.reverse if dn.first.downcase.include? 'c='
          # Join our array of DN elements back together with a comma as expected by CASPORT
          dn = dn.join(',')
        end
        dn
      end

      def call_casport (url)
          req = Net::HTTP::Get.new(url.request_uri, http_headers)
          res = https.start { https.request(req) }
          res
      end

      def http_headers
        if @http_headers
          @http_headers
        else
          @http_headers = {
            'Accept' => @options[:format_header],
            'Content-Type' => @options[:format_header],
            'X-XSRF-UseProtection' => ('false' if @options[:format_header]),
            'user-agent' => "net/http #{RUBY_VERSION}"
          }
        end
      end

      def https
        if @https
          @https
        else
          uri = URI.parse(@options[:cas_server])
          @https = Net::HTTP.new(uri.host, uri.port)
          @https.use_ssl = true
          @https.verify_mode = OpenSSL::SSL::VERIFY_PEER
          @https.ssl_version = @options[:ssl_version] || :SSLv3

          @https.ca_file = @options[:ssl_ca_file]
          @https.ssl_timeout = 120 # seconds
          @https.verify_depth = 5 # max length of cert chain to be verified
          @https.cert = OpenSSL::X509::Certificate.new(File.read(@options[:client_cert]))
          if @options[:client_key_pass].nil?
            @https.key = OpenSSL::PKey::RSA.new(File.read(@options[:client_key]))
          else
            @https.key = OpenSSL::PKey::RSA.new(File.read(@options[:client_key]), @options[:client_key_pass])
          end
        end
        @https
      end
    end

  end
end
