#! /usr/bin/env ruby
#
#   check-twemproxy-stat
#
# DESCRIPTION:
#   This plugin checks a given twemproxy stat
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# NOTES:
#   Currently the check only performs a less-than comparison
#
# LICENSE:
#

require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'
require 'json'

class CheckTwemproxyStat < Sensu::Plugin::Metric::CLI::Graphite
  SKIP_ROOT_KEYS = %w(service source version uptime timestamp).freeze

  option :host,
         description: 'Twemproxy stats host to connect to',
         short: '-h HOST',
         long: '--host HOST',
         required: false,
         default: '127.0.0.1'

  option :port,
         description: 'Twemproxy stats port to connect to',
         short: '-p PORT',
         long: '--port PORT',
         required: false,
         proc: proc(&:to_i),
         default: 22_222

  option :timeout,
         description: 'Timeout in seconds to complete the operation',
         short: '-t SECONDS',
         long: '--timeout SECONDS',
         required: false,
         proc: proc(&:to_i),
         default: 5

  option :critical_value,
         description: 'Critical if stats key is less than provided threshold',
         short: '-C',
         long: '--critical CRITICAL_VALUE',
         required: true,
         proc: proc(&:to_i)

  option :stat_key,
         description: 'Backend stats key to check',
         short: '-k',
         long: '--key KEY',
         required: true


  def run
    Timeout.timeout(config[:timeout]) do
      sock = TCPSocket.new(config[:host], config[:port])
      data = JSON.parse(sock.read)
      pools = data.keys - SKIP_ROOT_KEYS
      criticals = []

      pools.each do |pool_key|
        if not data[pool_key].is_a?(Hash)
          next
        end
        data[pool_key].each do |key, value|
          if not value.is_a?(Hash)
            next
          end
          value.each do |key_server, value_server|
            if key_server != config[:stat_key]
              next
            end
            if value_server.to_i < config[:critical_value]
              criticals << "#{value_server} #{key_server} (backend = #{key}) is less than critical threshold of #{config[:critical_value]}"
            end
          end
        end
      end

      if criticals.any?
        critical criticals.join("\n")
        return
      end
      ok "no errors"
    end
  rescue Timeout::Error
    warning 'Connection timed out'
  rescue Errno::ECONNREFUSED
    warning "Can't connect to #{config[:host]}:#{config[:port]}"
  end
end