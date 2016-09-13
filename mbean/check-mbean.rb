#! /usr/bin/env ruby
#
#   check-mbean
#
# DESCRIPTION:
# Connect to a running JVM via JMX and alert if an mbean's numeric value is less
# than a threshold
#
# NOTES:
# Requires jmxterm be installed at /opt/jana-lib
# http://wiki.cyclopsgroup.org/jmxterm/features.html
#

require 'sensu-plugin/check/cli'

class CheckMbean  < Sensu::Plugin::Check::CLI
  option :host,
         description: 'Hostname where the target jvm is running',
         short: '-h HOST',
         long: '--host HOST'

  option :port,
         description: 'JMX port for the target jvm',
         short: '-p PORT',
         long: '--port PORT'

  option :mbean,
         description: 'Mbean value to check',
         short: '-b BEAN',
         long: '--bean BEAN'

  option :warning_value,
         description: 'Warn if value is less than amount',
         short: '-w VALUE',
         long: '--warning VALUE'

  option :critical_value,
         description: 'Critical if value is less than amount',
         short: '-c VALUE',
         long: '--critical VALUE'

  option :jmxterm_path,
         description: 'Path to the jmxterm jar',
         short: '-j PATH',
         long: '--jmxterm PATH'

  def run
    unknown 'No mbean path specified' unless config[:mbean]
    unknown 'No warn or critical value specified' unless config[:warning_value] || config[:critical_value]
    unknown 'No host or port specified' unless config[:host] and config[:port]
    unknown 'No path to jmxterm jar specifed' unless config[:jmxterm_path]

    commands = "open #{config[:host]}:#{config[:port]}\nget -s -b #{config[:mbean]}\nclose"
    result = %x[echo "#{commands}" | java -jar #{config[:jmxterm_path]} -v silent -n].to_i

    # todo parameterize the comparison
    critical "#{result} is less than #{config[:critical_value]} msgs / second" if result < config[:critical_value].to_i
    warning "#{result} is less than #{config[:warning_value]} msgs / second" if result < config[:warning_value].to_i
    ok "#{result} msgs / second"

  end
end