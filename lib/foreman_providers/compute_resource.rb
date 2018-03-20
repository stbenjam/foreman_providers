module ForemanProviders
  module ComputeResource
    def self.included(base)
      base.class_eval do
        after_create   :create_provider
        before_destroy :destroy_provider

        private

        def create_provider
          provider = provider_client.providers.find_by(:type => foreman_type_to_provider_type, :hostname => URI(url).host)
          return if provider

          provider_client.providers.create(
            :name     => name,
            :hostname => URI(url).host,
            :type     => foreman_type_to_provider_type,
            :credentials => {
              :userid => user,
              :password => password,
            }
          )
        end

        def destroy_provider
          provider = provider_client.providers.find_by(:hostname => URI(url).host, :type => foreman_type_to_provider_type)
          return if provider.nil?

          provider.delete
        end

        def foreman_type_to_provider_type
          case type
          when "Foreman::Model::Ovirt"
            "ManageIQ::Providers::Redhat::InfraManager"
          end
        end

        def provider_client
          @connection ||= begin
            client_opts = {
              :url      => "http://localhost:4000",
              :user     => "admin",
              :password => "smartvm",
            }

            require 'manageiq/api/client'
            ManageIQ::API::Client.new(client_opts)
          end
        end
      end
    end
  end
end
