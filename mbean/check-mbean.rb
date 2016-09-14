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

  option :comparison,
         description: 'Type of comparison, one of gt or lt ; actual value is LHS, threshold is RHS',
         short: '-o COMPARISON',
         long: '--comparison COMPARISON',
         default: 'lt'

  def run_check(comparison, threshold, current_value, check_type)
    case comparison
      when 'gt'
        if current_value > threshold
          send(check_type, "#{current_value} is greater than threshold of #{threshold}")
        end
      when 'lt'
        if current_value < threshold
          send(check_type, "#{current_value} is less than threshold of #{threshold}")
        end
    end
  end

  def get_mbean_data(host, port, mbean, jmxterm_path)
    commands = "open #{host}:#{port}\nget -s -b #{mbean}\nclose"
    result = %x[echo "#{commands}" | java -jar #{jmxterm_path} -v silent -n].to_i

    return result
  end

  def run
    unknown 'Comparison must be lt or gt' unless config[:comparison] and ['lt','gt'].include? config[:comparison]
    unknown 'No mbean path specified' unless config[:mbean]
    unknown 'No warn or critical value specified' unless config[:warning_value] || config[:critical_value]
    unknown 'No host or port specified' unless config[:host] and config[:port]
    unknown 'No path to jmxterm jar specifed' unless config[:jmxterm_path]

    puts config[:comparison]

    current_value= get_mbean_data(config[:host], config[:port], config[:mbean], config[:jmxterm_path])

    run_check(config[:comparison], config[:critical_value].to_i, current_value, :critical) ||
        run_check(config[:comparison], config[:critical_value].to_i, current_value, :warn) ||
        ok("result = #{current_value} is ok")
  end
end