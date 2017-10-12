#! /usr/bin/env ruby
#
#   check_india_proxy
#
# DESCRIPTION:
# Alert if the India forward proxy is not working.
# Gives a warning level alert if the check of urla fails but urlb succeeds.
# Gives a critical level alert if neither url check succeeds.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux, BSD
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# NOTES:
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'

class CheckIndiaProxy < Sensu::Plugin::Check::CLI
  option :critical,
         short: '-c CRITICAL_FILE',
         default: '/tmp/CRITICAL'

  option :ua,
         short: '-x USER-AGENT',
         long: '--user-agent USER-AGENT',
         description: 'Specify a USER-AGENT',
         default: 'Sensu-HTTP-Check'

  option :host,
         short: '-h HOST',
         long: '--hostname HOSTNAME',
         description: 'A HOSTNAME to connect to'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         description: 'Select another port',
         default: 80

  option :request_uri,
         short: '-p PATH',
         long: '--request-uri PATH',
         description: 'Specify a uri path'

  option :urla,
         short: '-ua URL',
         long: '--urla URL',
         description: 'First URL to connect to'

  option :urlb,
         short: '-ub URL',
         long: '--urlb URL',
         description: 'Second URL to connect to'

  option :timeout,
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         description: 'Set the timeout',
         default: 15

  option :insecure,
         short: '-k',
         boolean: true,
         description: 'Enabling insecure connections',
         default: false

  option :ssl,
         short: '-s',
         boolean: true,
         description: 'Enabling SSL connections',
         default: false

  option :whole_response,
         short: '-w',
         long: '--whole-response',
         description: 'Print whole output when check fails',
         boolean: true,
         default: false

  def run
    urla_up = false
    urlb_up = false
    urla_error_msg = ''
    urlb_error_msg = ''

    if config[:urla]
      urla_up, urla_error_msg = check_url(config[:urla])
    else
      # #YELLOW
      unknown 'No urla specified'
    end

    if config[:urlb]
      urlb_up, urlb_error_msg = check_url(config[:urlb])
    else
      # #YELLOW
      unknown 'No urlb specified'
    end

    if not(urla_up or urlb_up)
        critical urla_error_msg + '' + urlb_error_msg
    elsif urlb_up and not urla_up
            warning "Bhangra is not responding but India proxy looks ok: " + urla_error_msg + '' + urlb_error_msg
    else
        ok urla_error_msg + '' + urlb_error_msg
    end
  end

  def check_url(urlx)
    uri = URI.parse(urlx)
    config[:host] = uri.host
    config[:port] = uri.port
    config[:request_uri] = uri.request_uri
    config[:ssl] = uri.scheme == 'https'
    urlx_up = false
    urlx_error_msg = ''

    begin
      timeout(config[:timeout]) do
        urlx_up, urlx_error_msg = acquire_resource
      end
    rescue Timeout::Error
      urlx_error_msg = '#{config[:host]} request timed out'
    rescue => e
      urlx_error_msg = "#{config[:host]}: Request error: #{e.message}"
    end

    return urlx_up, urlx_error_msg
  end

  def acquire_resource
    http = nil
    http = Net::HTTP.new(config[:host], config[:port])

    if config[:ssl]
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if config[:insecure]
    end

    req = Net::HTTP::Get.new(config[:request_uri], 'User-Agent' => config[:ua])

    res = http.request(req)

    body = if config[:whole_response]
             "\n" + res.body
           else
             ''
    end

    size = res.body.nil? ? '0' : res.body.size

    case res.code
    when /^2/, /^3/
      return true, ("#{config[:host]}, #{res.code}, #{size} bytes" + body)
    else
      return false, ("#{config[:host]}, #{res.code}, #{size} bytes" + body)
    end
  end
end
