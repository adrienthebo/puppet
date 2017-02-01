module Puppet
  class StateMachine
    class MachineContext
      attr_reader :result

      def initialize(machine)
        @machine = machine
        @result = :notrun
      end

      def call
        Puppet.info("State machine #{@machine.name}: starting")
        @result = :running
        current = @machine.start_state
        loop do
          event = current.call
          next_state_name = current.transition_for(event)
          next_state = @machine.state(next_state_name)
          if next_state.nil?
            @result = :errored
            puts "No transition defined for state #{current.name} and event #{event}"
            break
          end

          if next_state.error?
            @result = :errored
            puts "Halting state machine due to entering error state #{next_state.name}"
            break
          end

          if next_state.final?
            @result = :complete
            break
          else
            Puppet.info("State machine #{@machine.name}: transition State[#{current.name}] -> State[#{next_state.name}]")
            current = next_state
          end
        end
        @result
      end
    end
  end
end
