#! /usr/bin/env ruby
#
#   check-redis-status
#
# DESCRIPTION:
#   This plugin checks redis for the value of a key.
#   based off of https://github.com/sensu-plugins/sensu-plugins-redis/blob/master/bin/check-redis-info.rb
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
#

require 'sensu-plugin/check/cli'
require 'redis'

class RedisKeyStatus < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Redis Host to connect to',
         required: false,
         default: '127.0.0.1'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Redis Port to connect to',
         proc: proc(&:to_i),
         required: false,
         default: 6379

  option :database,
         short: '-n DATABASE',
         long: '--dbnumber DATABASE',
         description: 'Redis database number to connect to',
         proc: proc(&:to_i),
         required: false,
         default: 0

  option :password,
         short: '-P PASSWORD',
         long: '--password PASSWORD',
         description: 'Redis Password to connect with'

  option :redis_info_key,
         short: '-K KEY',
         long: '--redis-info-key KEY',
         description: 'Redis info key to monitor',
         required: true

  option :redis_info_value,
         short: '-V VALUE',
         long: '--redis-info-key-value VALUE',
         description: 'expected redis value',
         required: false,
         default: '0'

  option :redis_critical_value,
         short: '-c CRITICAL',
         long: '--critical critical',
         description: 'expected critical value',
         required: false
         default: '2'


  def run
    options = { host: config[:host], port: config[:port], db: config[:database] }
    options[:password] = config[:password] if config[:password]
    redis = Redis.new(options)

    value = redis.get(config[:redis_info_key].to_s)
    if value == config[:redis_info_value].to_s
      ok "Redis #{config[:redis_info_key]} is OK"
    else
      if value != config[:redis_critical_value]
        message = value
      else
        message = "#{config[:redis_info_key]} is CRITICAL!"
      end
      critical message
    end
  end
end
