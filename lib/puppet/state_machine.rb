module Puppet
  class StateMachine
    require 'puppet/state_machine/state'
    require 'puppet/state_machine/machine_context'
    require 'puppet/state_machine/machine_builder'

    def self.build(name, &block)
      MachineBuilder.new(name).build(&block)
    end

    attr_reader :name
    attr_reader :states

    def initialize(name, states, start_state)
      @name = name
      @states = states
      @start_state = start_state
    end

    def start_state
      @states[@start_state]
    end

    def state(state_name)
      @states[state_name]
    end

    def call
      MachineContext.new(self).call
    end
  end
end
