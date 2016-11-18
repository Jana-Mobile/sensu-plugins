#! /usr/bin/env ruby
#
#   check-kafka-consumers
#
# DESCRIPTION:
# Connect to a burrow instance and pull statuses for all consumers on
# all clusters monitored by burrow.
#
# Any consumer in a non-OK state
#

require 'sensu-plugin/check/cli'
require 'net/http'
require 'json'

class CheckKafkaConsumers  < Sensu::Plugin::Check::CLI
  option :base_uri,
         description: 'Base burrow URI',
         short: '-u HOST',
         long: '--uri HOST'

  def check_consumer(cluster, consumer, http)
    consumers_url = "#{config[:base_uri]}/v2/kafka/#{cluster}/consumer/#{consumer}/status"
    req = Net::HTTP::Get.new(consumers_url)
    res = http.request(req)

    consumer_status = JSON.parse(res.body)
    return consumer_status['status']['status']
  end

  def check_cluster(cluster, http)
    consumers_url = "#{config[:base_uri]}/v2/kafka/#{cluster}/consumer"
    req = Net::HTTP::Get.new(consumers_url)
    res = http.request(req)

    consumers = JSON.parse(res.body)
    if consumers['error']
      return false
    end

    consumer_results = {}
    consumers['consumers'].each do|consumer|
      result = check_consumer(cluster, consumer, http)
      consumer_results[consumer] = result
    end

    return consumer_results

  end

  def run

    error_codes = {
        "NOTFOUND" => :unknown,
        "OK" => :ok,
        "WARN" => :warn,
        "ERR" => :warn,
        "STOP" => :warn,
        "STALL" => :warn,
        "REWIND" => :ok
    }
    error_codes.default = :ok



    uri = URI.parse(config[:base_uri])
    config[:host] = uri.host
    config[:port] = uri.port
    config[:request_uri] = uri.request_uri
    config[:ssl] = uri.scheme == 'https'

    http = nil
    http = Net::HTTP.new(config[:host], config[:port], nil, nil)

    clusters_url = "#{config[:base_uri]}/v2/kafka"
    req =  Net::HTTP::Get.new(clusters_url)
    res = http.request(req)

    clusters = JSON.parse(res.body)['clusters']
    cluster_results = {}

    aggregates = {}
    aggregates.default = 0

    clusters.each do|cluster|
      consumer_results = check_cluster(cluster, http)
      consumer_results.each do |consumer, result|
        aggregates[error_codes[result]] += 1
      end

      cluster_results[cluster] = consumer_results
    end


    pretty_results = JSON.pretty_generate(cluster_results)
    if aggregates[:critical] > 0
      critical('Cluster consumer check failed: '+ pretty_results)
    elsif aggregates[:warn] > 0
      warn('Cluster consumer check failed: '+ pretty_results)
    else
      ok('Cluster consumer check ok: ' + pretty_results)
    end

  end
end