module ForemanProviders
  module Logging
    def _log
      Foreman::Logging.logger("foreman_providers")
    end
  end
end
