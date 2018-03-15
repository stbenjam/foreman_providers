module Providers
  module EmsRefresh
    extend SaveInventory
    extend SaveInventoryBlockStorage
    extend SaveInventoryCloud
    extend SaveInventoryInfra
    extend SaveInventoryPhysicalInfra
    extend SaveInventoryContainer
    extend SaveInventoryNetwork
    extend SaveInventoryObjectStorage
    extend SaveInventoryHelper
    extend SaveInventoryProvisioning
    extend SaveInventoryConfiguration
    extend SaveInventoryAutomation
    extend SaveInventoryOrchestrationStacks
    extend LinkInventory
    extend MetadataRelats
    extend ForemanProviders::Logging

    def self.debug_trace
      false
    end

    # If true, Refreshers will raise any exceptions encountered, instead
    # of quietly recording them as failures and continuing.
    mattr_accessor :debug_failures

    def self.refresh(target, id = nil)
      # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
      targets = get_target_objects(target, id).uniq

      # Store manager records to avoid n+1 queries
      manager_by_manager_id = {}

      # Split the targets into refresher groups
      groups = targets.group_by do |t|
        ems = case
              when t.respond_to?(:ext_management_system) then t.ext_management_system
              when t.respond_to?(:manager_id)            then manager_by_manager_id[t.manager_id] ||= t.manager
              when t.respond_to?(:manager)               then t.manager
              else                                            t
              end
        ems.class::Refresher
      end

      # Do the refreshes
      groups.each do |refresher, group_targets|
        refresher.refresh(group_targets) if refresher
      end
    end

    def self.refresh_new_target(ems_id, target_hash, target_class, target_find)
      ems = ExtManagementSystem.find(ems_id)
      target_class = target_class.constantize if target_class.kind_of?(String)

      save_ems_inventory_no_disconnect(ems, target_hash)

      target = target_class.find_by(target_find)
      if target.nil?
        _log.warn("Unknown target for event data: #{target_hash}.")
        return
      end

      ems.refresher.refresh(get_target_objects(target))
      target.post_create_actions_queue if target.respond_to?(:post_create_actions_queue)
      target
    end

    def self.get_target_objects(target, single_id = nil)
      # Handle targets passed as a single class/id pair, an array of class/id pairs, an array of references
      target = [[target, single_id]] unless single_id.nil?
      return [target] unless target.kind_of?(Array)
      return target unless target[0].kind_of?(Array)

      # Group by type for a more optimized search
      targets_by_type = target.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(target_class, id), hash|
        # Take care of both String or Class type being passed in
        target_class = target_class.to_s.constantize unless target_class.kind_of?(Class)

        if ManagerRefresh::Inventory.persister_class_for(target_class).blank? &&
           [VmOrTemplate, Host, PhysicalServer, ExtManagementSystem, ManagerRefresh::Target].none? { |k| target_class <= k }
          _log.warn("Unknown target type: [#{target_class}].")
          next
        end

        hash[target_class] << id
      end

      # Do lookups to get ActiveRecord objects or initialize ManagerRefresh::Target for ids that are Hash
      targets_by_type.each_with_object([]) do |(target_class, ids), target_objects|
        ids.uniq!

        recs = if target_class <= ManagerRefresh::Target
                 ids.map { |x| ManagerRefresh::Target.load(x) }
               else
                 active_record_recs = target_class.where(:id => ids)
                 active_record_recs = active_record_recs.includes(:ext_management_system) unless target_class <= ExtManagementSystem
                 active_record_recs
               end

        if recs.length != ids.length
          missing = ids - recs.collect(&:id)
          _log.warn("Unable to find a record for [#{target_class}] ids: #{missing.inspect}.")
        end

        target_objects.concat(recs)
      end
    end

    #
    # Helper methods for advanced debugging
    #

    def self.log_inv_debug_trace(inv, log_header, depth = 1)
      return unless debug_trace

      inv.each do |k, v|
        if depth == 1
          $log.debug("#{log_header} #{k.inspect}=>#{v.inspect}")
        else
          $log.debug("#{log_header} #{k.inspect}=>")
          log_inv_debug_trace(v, "#{log_header}  ", depth - 1)
        end
      end
    end

    def self.log_format_deletes(deletes)
      ret = deletes.collect do |d|
        s = "id: [#{d.id}]"

        [:name, :product_name, :device_name].each do |k|
          next unless d.respond_to?(k)
          v = d.send(k)
          next if v.nil?
          s << " #{k}: [#{v}]"
          break
        end

        s
      end

      ret.join(", ")
    end
  end
end
