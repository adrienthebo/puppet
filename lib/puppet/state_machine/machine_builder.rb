require 'puppet/state_machine/state'

module Puppet
  class StateMachine
    # Metaprogram a simple dsl, yo.
    class MachineBuilder
      def initialize(machine_name)
        @machine_name = machine_name
        @states = {}
        @start_state = nil
      end

      def build(&blk)
        yield self
        verify!
        Puppet::StateMachine.new(@machine_name, @states, @start_state)
      end

      def verify!
        verify_start_state!
        verify_transitions!
      end

      def start_state(name)
        @start_state = name
      end

      # @return [Puppet::StateMachine::State] The generated machine state
      def state(state_name, opts = {})
        if @states[state_name]
          raise ArgumentError, "State '#{state_name}' already defined for state machine '#{@machine_name}'"
        end
        trans = {}
        if opts[:transitions]
          opts[:transitions].each do |event, target|
            trans[event] = target
          end
        end
        @states[state_name] = State.new(state_name, opts[:action], opts[:event], opts, trans)
      end

      # @return [Hash<Event, Target>] The defined transitions for the named source state
      def transition(opts)
        source = opts[:source]
        target = opts[:target]
        event = opts[:on]
        source_state = @states[opts[:source]]

        if source.nil?
          raise ArgumentError, "Unable to add transition: source state not defined"
        end

        if target.nil?
          raise ArgumentError, "Unable to add transition: target state not defined"
        end

        if event.nil?
          raise ArgumentError, "Unable to add transition: transition event not defined"
        end

        if source_state.nil?
          raise ArgumentError, "Unable to add transition '#{opts[:source]}' to '#{opts[:target]}': source state '#{opts[:source]}' is not defined"
        end

        source_state.transitions[event] = target
        source_state.transitions
      end

      private

      def verify_start_state!
        if @start_state.nil?
          raise ArgumentError, "Unable to build state machine '#{@machine_name}': start state not named"
        elsif @states[@start_state].nil?
          raise ArgumentError, "Unable to build state machine '#{@machine_name}': start state '#{@start_state}' not defined"
        end
      end

      def verify_transitions!
        @states.values.each do |state|
          state.transitions.each_pair do |event, target|
            if @states[target].nil?
              raise ArgumentError, "Unable to build state machine '#{@machine_name}': invalid transition from from state '#{state.name}' to missing state '#{target}'"
            end
          end
        end
      end
    end
  end
end
