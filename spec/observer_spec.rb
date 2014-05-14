require 'spec_helper'

context 'ObserverUpdate' do
  before(:each) do
    @model = new_model { include ActiveModel::Observing }
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite

    @record = @model.new(state: 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)

    @observer_update = StateMachines::Integrations::ActiveModel::ObserverUpdate.new(:before_transition, @record, @transition)
  end

  it 'should_have_method' do
    assert_equal :before_transition, @observer_update.method
  end

  it 'should_have_object' do
    assert_equal @record, @observer_update.object
  end

  it 'should_have_transition' do
    assert_equal @transition, @observer_update.transition
  end

  it 'should_include_object_and_transition_in_args' do
    assert_equal [@record, @transition], @observer_update.args
  end

  it 'should_use_record_class_as_class' do
    assert_equal @model, @observer_update.class
  end
end

context 'WithObservers' do
  before(:each) do
    @model = new_model { include ActiveModel::Observing }
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite
    @record = @model.new(state: 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)
  end

  it 'should_call_all_transition_callback_permutations' do
    callbacks = [
      :before_ignite_from_parked_to_idling,
      :before_ignite_from_parked,
      :before_ignite_to_idling,
      :before_ignite,
      :before_transition_state_from_parked_to_idling,
      :before_transition_state_from_parked,
      :before_transition_state_to_idling,
      :before_transition_state,
      :before_transition
    ]

    observer = new_observer(@model) do
      callbacks.each do |callback|
        define_method(callback) do |*|
          notifications << callback
        end
      end
    end

    instance = observer.instance

    @transition.perform
    assert_equal callbacks, instance.notifications
  end

  it 'should_call_no_transition_callbacks_when_observers_disabled' do
    callbacks = [
      :before_ignite,
      :before_transition
    ]

    observer = new_observer(@model) do
      callbacks.each do |callback|
        define_method(callback) do |*|
          notifications << callback
        end
      end
    end

    instance = observer.instance

    @model.observers.disable(observer) do
      @transition.perform
    end

    assert_equal [], instance.notifications
  end

  it 'should_pass_record_and_transition_to_before_callbacks' do
    observer = new_observer(@model) do
      def before_transition(*args)
        notifications << args
      end
    end
    instance = observer.instance

    @transition.perform
    assert_equal [[@record, @transition]], instance.notifications
  end

  it 'should_pass_record_and_transition_to_after_callbacks' do
    observer = new_observer(@model) do
      def after_transition(*args)
        notifications << args
      end
    end
    instance = observer.instance

    @transition.perform
    assert_equal [[@record, @transition]], instance.notifications
  end

  it 'should_call_methods_outside_the_context_of_the_record' do
    observer = new_observer(@model) do
      def before_ignite(*)
        notifications << self
      end
    end
    instance = observer.instance

    @transition.perform
    assert_equal [instance], instance.notifications
  end

  it 'should_support_nil_from_states' do
    callbacks = [
      :before_ignite_from_nil_to_idling,
      :before_ignite_from_nil,
      :before_transition_state_from_nil_to_idling,
      :before_transition_state_from_nil
    ]

    observer = new_observer(@model) do
      callbacks.each do |callback|
        define_method(callback) do |*|
          notifications << callback
        end
      end
    end

    instance = observer.instance

    transition = StateMachines::Transition.new(@record, @machine, :ignite, nil, :idling)
    transition.perform
    assert_equal callbacks, instance.notifications
  end

  it 'should_support_nil_to_states' do
    callbacks = [
      :before_ignite_from_parked_to_nil,
      :before_ignite_to_nil,
      :before_transition_state_from_parked_to_nil,
      :before_transition_state_to_nil
    ]

    observer = new_observer(@model) do
      callbacks.each do |callback|
        define_method(callback) do |*|
          notifications << callback
        end
      end
    end

    instance = observer.instance

    transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, nil)
    transition.perform
    assert_equal callbacks, instance.notifications
  end
end

context 'WithNamespacedObservers' do
  before(:each) do
    @model = new_model { include ActiveModel::Observing }
    @machine = StateMachines::Machine.new(@model, :state, namespace: 'alarm')
    @machine.state :active, :off
    @machine.event :enable
    @record = @model.new(state: 'off')
    @transition = StateMachines::Transition.new(@record, @machine, :enable, :off, :active)
  end

  it 'should_call_namespaced_before_event_method' do
    observer = new_observer(@model) do
      def before_enable_alarm(*args)
        notifications << args
      end
    end
    instance = observer.instance

    @transition.perform
    expect(instance.notifications).to eq([[@record, @transition]])
  end

  it 'should_call_namespaced_after_event_method' do
    observer = new_observer(@model) do
      def after_enable_alarm(*args)
        notifications << args
      end
    end
    instance = observer.instance

    @transition.perform
    assert_equal [[@record, @transition]], instance.notifications
  end
end

context 'WithFailureCallbacks' do
  before(:each) do
    @model = new_model { include ActiveModel::Observing }
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite
    @record = @model.new(state: 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)

    @notifications = []

    # Create callbacks
    @machine.before_transition { false }
    @machine.after_failure { @notifications << :callback_after_failure }

    # Create observer callbacks
    observer = new_observer(@model) do
      def after_failure_to_ignite(*)
        notifications << :observer_after_failure_ignite
      end

      def after_failure_to_transition(*)
        notifications << :observer_after_failure_transition
      end
    end
    instance = observer.instance
    instance.notifications = @notifications

    @transition.perform
  end

  it 'should_invoke_callbacks_in_specific_order' do
    expected = [
      :callback_after_failure,
      :observer_after_failure_ignite,
      :observer_after_failure_transition
    ]

    expect(@notifications).to eq(expected)
  end
end

context 'WithMixedCallbacks' do
  before(:each) do
    @model = new_model { include ActiveModel::Observing }
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite
    @record = @model.new(state: 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)

    @notifications = []

    # Create callbacks
    @machine.before_transition { @notifications << :callback_before_transition }
    @machine.after_transition { @notifications << :callback_after_transition }
    @machine.around_transition { |block| @notifications << :callback_around_before_transition; block.call; @notifications << :callback_around_after_transition }

    # Create observer callbacks
    observer = new_observer(@model) do
      def before_ignite(*)
        notifications << :observer_before_ignite
      end

      def before_transition(*)
        notifications << :observer_before_transition
      end

      def after_ignite(*)
        notifications << :observer_after_ignite
      end

      def after_transition(*)
        notifications << :observer_after_transition
      end
    end
    instance = observer.instance
    instance.notifications = @notifications

    @transition.perform
  end

  it 'should_invoke_callbacks_in_specific_order' do
    expected = [
      :callback_before_transition,
      :callback_around_before_transition,
      :observer_before_ignite,
      :observer_before_transition,
      :callback_around_after_transition,
      :callback_after_transition,
      :observer_after_ignite,
      :observer_after_transition
    ]

    expect(@notifications).to eq(expected)
  end
end

describe StateMachines::Integrations::ActiveModel do
  it 'should match if class includes observing feature' do
    expect(StateMachines::Integrations::ActiveModel.matches?(new_model { include ActiveModel::Observing })).to be_truthy
  end

  describe '.matching_ancestors' do
    it do
      expect(StateMachines::Integrations::ActiveModel.matching_ancestors).to include('ActiveModel')
    end

    it do
      expect(StateMachines::Integrations::ActiveModel.matching_ancestors).to include('ActiveModel::Observing')
    end

    it do
      expect(StateMachines::Integrations::ActiveModel.matching_ancestors).to include('ActiveModel::Validations')
    end
  end

end
