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

  context "composing machines" do
    let(:m1) do
      described_class.new("m1").build do |m|
        m.start_state(:start)
        m.state :start,
          action: -> { },
          event: ->(x) { :e1 },
          transitions: {e1: :final}

        m.state :final,
          final: true,
          action: -> { },
          event: ->(x) { :e2 },
          transitions: {e2: :final}
      end
    end

    let(:m2) do
      described_class.new("m2").build do |m|
        m.start_state(:start)
        m.state :start,
          action: -> { },
          event: ->(x) { :e3 },
          transitions: {e3: :final}

        m.state :final,
          final: true,
          action: -> { },
          event: ->(x) { :e4 },
          transitions: {e4: :final}
      end
    end

    let(:composed) do
      subject.compose(m1: m1, m2: m2) do |m|
        m.start_state([:m1, :start])
      end
    end

    it "composes all of the machine states" do
      state_names = composed.states.keys
      expect(state_names).to include([:m1, :start])
      expect(state_names).to include([:m1, :final])
      expect(state_names).to include([:m2, :start])
      expect(state_names).to include([:m2, :final])
    end

    it "composes all of the machine transitions" do
      m1_start = composed.state([:m1, :start])
      m1_final = composed.state([:m1, :final])
      m2_start = composed.state([:m2, :start])
      m2_final = composed.state([:m2, :final])

      expect(m1_start.transition_for(:e1)).to eq([:m1, :final])
      expect(m1_final.transition_for(:e2)).to eq([:m1, :final])

      expect(m2_start.transition_for(:e3)).to eq([:m2, :final])
      expect(m2_final.transition_for(:e4)).to eq([:m2, :final])
    end
  end
end
