# frozen_string_literal: true

module PrometheusExporter::Instrumentation
  class SidekiqProcess
    def self.start(client: nil, frequency: 30)
      client ||= PrometheusExporter::Client.default
      sidekiq_process_collector = new

      Thread.new do
        loop do
          begin
            client.send_json(sidekiq_process_collector.collect)
          rescue StandardError => e
            STDERR.puts("Prometheus Exporter Failed To Collect Sidekiq Processes metrics #{e}")
          ensure
            sleep frequency
          end
        end
      end
    end

    def initialize
      @pid = ::Process.pid
      @hostname = Socket.gethostname
    end

    def collect
      {
        type: 'sidekiq_process',
        process: collect_stats
      }
    end

    def collect_stats
      process = current_process
      return {} unless process

      {
        busy: process['busy'],
        concurrency: process['concurrency'],
        labels: {
          labels: process['labels'].sort.join(','),
          queues: process['queues'].sort.join(','),
          quiet: process['quiet'],
          tag: process['tag'],
          hostname: process['hostname'],
          identity: process['identity'],
        }
      }
    end

    def current_process
      ::Sidekiq::ProcessSet.new.find do |sp|
        sp['hostname'] == @hostname && sp['pid'] == @pid
      end
    end
  end
end
