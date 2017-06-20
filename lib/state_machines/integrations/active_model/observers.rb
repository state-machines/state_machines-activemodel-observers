require 'state_machines/integrations/active_model'
require 'rails/observers/active_model'
require_relative 'observers/version'
require_relative 'observers/observer_update'

module StateMachines
  module Integrations
    module ActiveModel
      # Classes that include ActiveModel::Observing
      # will automatically use the ActiveModel integration.
      def self.matching_ancestors
        [::ActiveModel ::ActiveModel::Observing ::ActiveModel::Validations]
      end

      # Adds a set of default callbacks that utilize the Observer extensions
      def add_default_callbacks
        callbacks[:before] << StateMachines::Callback.new(:before) { |object, transition| notify(:before, object, transition) }
        callbacks[:after] << StateMachines::Callback.new(:after) { |object, transition| notify(:after, object, transition) }
        callbacks[:failure] << StateMachines::Callback.new(:failure) { |object, transition| notify(:after_failure_to, object, transition) }
      end

      # Notifies observers on the given object that a callback occurred
      # involving the given transition.  This will attempt to call the
      # following methods on observers:
      # * <tt>#{type}_#{qualified_event}_from_#{from}_to_#{to}</tt>
      # * <tt>#{type}_#{qualified_event}_from_#{from}</tt>
      # * <tt>#{type}_#{qualified_event}_to_#{to}</tt>
      # * <tt>#{type}_#{qualified_event}</tt>
      # * <tt>#{type}_transition_#{machine_name}_from_#{from}_to_#{to}</tt>
      # * <tt>#{type}_transition_#{machine_name}_from_#{from}</tt>
      # * <tt>#{type}_transition_#{machine_name}_to_#{to}</tt>
      # * <tt>#{type}_transition_#{machine_name}</tt>
      # * <tt>#{type}_transition</tt>
      #
      # This will always return true regardless of the results of the
      # callbacks.
      def notify(type, object, transition)
        name = self.name
        event = transition.qualified_event
        from = transition.from_name || 'nil'
        to = transition.to_name || 'nil'

        # Machine-specific updates
        ["#{type}_#{event}", "#{type}_transition_#{name}"].each do |event_segment|
          ["_from_#{from}", nil].each do |from_segment|
            ["_to_#{to}", nil].each do |to_segment|
              object.class.changed if object.class.respond_to?(:changed)
              object.class.notify_observers('update_with_transition', ObserverUpdate.new([event_segment, from_segment, to_segment].join, object, transition))
            end
          end
        end

        # Generic updates
        object.class.changed if object.class.respond_to?(:changed)
        object.class.notify_observers('update_with_transition', ObserverUpdate.new("#{type}_transition", object, transition))

        true
      end

      def add_callback(type, options, &block)
        options[:terminator] = callback_terminator
        @callbacks[type == :around ? :before : type].insert(-2, callback = StateMachines::Callback.new(type, options, &block))
        add_states(callback.known_states)
        callback
      end

      # Initializes class-level extensions and defaults for this machine
      def after_initialize
        super()
        add_default_callbacks
      end

      # Adds support for invoking callbacks on ActiveModel observers with more
      # than one argument (e.g. the record *and* the state transition).  By
      # default, ActiveModel only supports passing the record into the
      # callbacks.
      #
      # For example:
      #
      #   class VehicleObserver < ActiveModel::Observer
      #     # The default behavior: only pass in the record
      #     def after_save(vehicle)
      #     end
      #
      #     # Custom behavior: allow the transition to be passed in as well
      #     def after_transition(vehicle, transition)
      #       Audit.log(vehicle, transition)
      #     end
      #   end
      module Observer
        def update_with_transition(observer_update)
          method = observer_update.method
          send(method, *observer_update.args) if respond_to?(method)
        end
      end
    end
  end
end

ActiveModel::Observer.class_eval do
  include StateMachines::Integrations::ActiveModel::Observer
end
