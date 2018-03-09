module Providers
  class BaseManager < ExtManagementSystem
    def ext_management_system
      self
    end

    def refresher
      self.class::Refresher
    end
  end
end
