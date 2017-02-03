require 'puppet/state_machine'

module Puppet
  class StateMachine
    class State

      attr_reader :name
      attr_reader :transitions

      def initialize(name, action_cb, event_cb, options, transitions = {})
        @name = name
        @action_cb = action_cb
        @event_cb = event_cb
        @options = options

        @transitions = transitions
      end

      def call
        event(action)
      end

      def action
        @action_cb.call.tap {|x| puts "State #{@name} action returned #{x.inspect}" }
      rescue => e
        require 'pry'; binding.pry
      end

      def event(result)
        @event_cb.call(result).tap {|x| puts "State #{@name} event for result #{result.inspect} returned #{x.inspect}"}
      end

      def transition_for(event)
        @transitions[event]
      end

      def error?
        @options[:type] == :error
      end

      def final?
        @options[:type] == :final
      end

      # Generate a new state with namespaced transitions
      #
      # @param ns [Symbol]
      # @return [Puppet::StateMachine::State]
      def namespace(ns)
        new_name = Array(@name).dup.unshift(ns)
        new_transitions = Hash[@transitions.map do |(event, target)|
          [event, Array(target).dup.unshift(ns)]
        end]

        new_options = @options.dup
        case new_options[:type]
        when :final
          new_event_cb = ->(_) { :'*final*' }
          new_options.delete(:type)
        when :error
          new_event_cb = ->(_) { :'*error*' }
        else
          new_event_cb = @event_cb
        end
        Puppet::StateMachine::State.new(new_name, @action_cb, new_event_cb, new_options, new_transitions)
      end
    end
  end
end
