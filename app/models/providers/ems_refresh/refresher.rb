module Providers
  module EmsRefresh
    class Refresher

      attr_accessor :ems_by_ems_id, :targets_by_ems_id

      def self.refresh(targets)
        new(targets).refresh
      end

      def initialize(targets)
        group_targets_by_ems(targets)
      end

      def refresh
        preprocess_targets

        targets_by_ems_id.each do |ems_id, targets|
          ems = ems_by_ems_id[ems_id]
          ems_refresh_start_time = Time.now

          refresh_targets_for_ems(ems, targets)
          post_refresh_ems_cleanup(ems, targets)

          ems.update_attributes(:last_refresh_error => nil, :last_refresh_date => Time.now.utc)
          post_refresh(ems, ems_refresh_start_time)
        end
      end

      def preprocess_targets
      end

      def refresh_targets_for_ems(ems, targets)
        targets_with_inventory = collect_inventory_for_targets(ems, targets)
        until targets_with_inventory.empty?
          target, inventory = targets_with_inventory.shift

          parsed = parse_targeted_inventory(ems, target, inventory)
          save_inventory(ems, target, parsed)
        end
      end

      def collect_inventory_for_targets(ems, targets)
        raise NotImplementedError, _("must be implemented in a subclass")
      end

      def parse_targeted_inventory(ems, target, inventory)
        raise NotImplementedError, _("must be implemented in a subclass")
      end

      def save_inventory(ems, target, parsed)
        EmsRefresh.save_ems_inventory(ems, parsed, target)
      end

      def post_refresh_ems_cleanup(_ems, _targets)
        # Clean up any resources opened during inventory collection
      end

      def post_process_refresh_classes
        # Return the list of classes that need post processing
        []
      end

      def post_refresh(ems, ems_refresh_start_time)
        post_process_refresh_classes.each do |klass|
        end
      end

      private

      def group_targets_by_ems(targets)
        non_ems_targets = targets.select { |t| !t.kind_of?(ExtManagementSystem) && t.respond_to?(:ext_management_system) }

        self.ems_by_ems_id     = {}
        self.targets_by_ems_id = Hash.new { |h, k| h[k] = [] }

        targets.each do |t|
          if t.kind_of?(ManagerRefresh::Target)
            ems_by_ems_id[t.manager_id] ||= t.manager
            targets_by_ems_id[t.manager_id] << t
          else
            ems = case
                  when t.respond_to?(:ext_management_system) then t.ext_management_system
                  when t.respond_to?(:manager)               then t.manager
                  else                                            t
                  end
            if ems.nil?
              _log.warn("Unable to perform refresh for #{t.class} [#{t.name}] id [#{t.id}], since it is not on an EMS.")
              next
            end

            ems_by_ems_id[ems.id] ||= ems
            targets_by_ems_id[ems.id] << t
          end
        end
      end
    end
  end
end
