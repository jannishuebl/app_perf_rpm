module AppPerfRpm
  module Instruments
    module FaradayConnection
      def run_request_with_trace(method, url, body, headers, &block)
        if ::AppPerfRpm.tracing?
          instance = ::AppPerfRpm::Tracer.start_instance("faraday")
          result = run_request_without_trace(method, url, body, headers, &block)
          instance.finish

          opts = {}
          opts["middleware"] = @builder.handlers
          opts["backtrace"] = ::AppPerfRpm::Backtrace.backtrace
          opts["source"] = ::AppPerfRpm::Backtrace.source_extract
          opts["protocol"] = @url_prefix.scheme
          opts["remote_host"] = @url_prefix.host
          opts["remote_port"] = @url_prefix.port
          opts["service_url"] = url
          opts["http_method"] = method
          opts["http_status"] = result.status

          instance.submit(opts)

          result
        else
          run_request_without_trace(method, url, body, headers, &block)
        end
      end
    end
  end
end

if ::AppPerfRpm.configuration.instrumentation[:faraday][:enabled] && defined?(::Faraday)
  ::AppPerfRpm.logger.info "Initializing faraday tracer."

  ::Faraday::Connection.send(:include, AppPerfRpm::Instruments::FaradayConnection)
  ::Faraday::Connection.class_eval do
    alias_method :run_request_without_trace, :run_request
    alias_method :run_request, :run_request_with_trace
  end
end
