require 'spec_helper'
require 'puppet/state_machine/machine_builder'

context Puppet::StateMachine::MachineBuilder do
  subject { described_class.new("test") }

  context "defining a state" do
    it "creates a state with the defined properties" do
      s = subject.state(:newstate,
        action: -> { "action invoked" },
        event: ->(result) { "event emitted for action: '#{result}'" },
        transitions: {
          up: :up_state,
          down: :down_state,
        })

      expect(s.action).to eq "action invoked"
      expect(s.event('action result')).to eq "event emitted for action: 'action result'"
      expect(s.transitions).to eq(up: :up_state, down: :down_state)
    end

    it "raises an error when attempting to define a duplicate state" do
      subject.state(:x)
      expect {
        subject.state(:x)
      }.to raise_error(ArgumentError, "State 'x' already defined for state machine 'test'")
    end

    it "raises an error when given unhandled options"

    it "raises an error when defining a state with no action proc"
    it "raises an error when defining a state with no event proc"
  end

  context "defining a transition" do
    before do
      subject.state(:x,
        action: -> { "action invoked" },
        event: ->(result) { "event emitted for action: '#{result}'" })

      subject.state(:y,
        action: -> { "action invoked" },
        event: ->(result) { "event emitted for action: '#{result}'" })
    end

    it "raises an error when the source state is not provided" do
      expect {
        subject.transition({})
      }.to raise_error(ArgumentError,  "Unable to add transition: source state not defined")
    end

    it "raises an error when the target state is not provided" do
      expect {
        subject.transition({source: :x})
      }.to raise_error(ArgumentError,  "Unable to add transition: target state not defined")
    end

    it "raises an error when the triggering event is not provided" do
      expect {
        subject.transition({source: :x, target: :y})
      }.to raise_error(ArgumentError,  "Unable to add transition: transition event not defined")
    end

    it "raises an error when the source state is provided but does not exist" do
      expect {
        subject.transition({source: :q, target: :y, on: :event})
      }.to raise_error(ArgumentError, "Unable to add transition 'q' to 'y': source state 'q' is not defined")
    end

    it "defines the transition when all preconditions are satisfied" do
      transitions = subject.transition({source: :x, target: :y, on: :event})
      expect(transitions).to eq(event: :y)
    end
  end

  context "verifying the state machine" do
    context "verifying the start state" do
      it "raises an error if a start state was not named" do
        expect {
          subject.verify!
        }.to raise_error(ArgumentError, "Unable to build state machine 'test': start state not named")
      end

      it "raises an error if the named start state does not exist" do
        subject.start_state(:nope)
        expect {
          subject.verify!
        }.to raise_error(ArgumentError, "Unable to build state machine 'test': start state 'nope' not defined")
      end
    end

    context "verifying transitions" do
      it "raises an error if there are transitions with undefined target states" do
        subject.state(:s, transitions: {e: :missing})
        subject.start_state(:s)

        expect {
          subject.verify!
        }.to raise_error(ArgumentError, "Unable to build state machine 'test': invalid transition from from state 's' to missing state 'missing'")
      end
    end
  end
end
