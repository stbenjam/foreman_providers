module ForemanProviders
  module ComputeResource
    extend ActiveSupport::Concern

    included do
      after_create :create_provider
      before_destroy :destroy_provider
    end

    def create_provider
      provider_klass = foreman_type_to_provider_type.constantize

      ems = provider_klass.create!(:name => name, :hostname => URI(url).host)
      ems.update_authentication(:default => {:userid => user, :password => password})
      ems.default_endpoint.update_attributes(:verify_ssl => 0)
    end

    def destroy_provider
      provider_klass = foreman_type_to_provider_type.constantize
      provider_klass.find_by(:name => name).try(:destroy)
    end

    def foreman_type_to_provider_type
      case type
      when "Foreman::Model::Ovirt"
        "Providers::Ovirt::Manager"
      end
    end
  end
end
