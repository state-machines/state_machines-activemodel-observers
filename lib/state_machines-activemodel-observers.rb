require 'active_model'
require 'rails/observers/active_model'
require 'state_machines-activemodel'
require_relative 'state_machines/integrations/active_model'

ActiveModel::Observer.send(:include, StateMachines::Integrations::ActiveModel::Observer)