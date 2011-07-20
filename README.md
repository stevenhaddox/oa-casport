# oa-casport is a custom strategy for OmniAuth authentication via Casport

## Examples:

You can see how to set it up and use it with a Rails 3 application at: [https://github.com/stevenhaddox/oa-casport-rails3](https://github.com/stevenhaddox/oa-casport-rails3)

\#TODO: You can see how to set it up and use it with a Sinatra application at: [https://github.com/stevenhaddox/oa-casport-sinatra](https://github.com/stevenhaddox/oa-casport-sinatra)

## Configuration Parameters:

Configuration within the initializer for OmniAuth:

    # @example Basic Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #        :setup => true
    #      }
    # @example Full Options Usage
    #
    #  use OmniAuth::Strategies::Casport, {
    #        :setup         => true,
    #        :cas_server    => 'http://cas.slkdemos.com/users/',
    #        :format        => 'json', 'xml', 'html', etc. || Defaults to 'xml'
    #        :format_header => 'application/xml',
    #        :ssl_ca_file   => 'path/to/ca_file.crt',
    #        :pem_cert      => '/path/to/cert.pem',
    #        :pem_cert_pass => 'keep it secret, keep it safe.'
    #      }

  
