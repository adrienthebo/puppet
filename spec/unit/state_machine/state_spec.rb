require 'spec_helper'
require 'puppet/state_machine/state'

RSpec.context Puppet::StateMachine::State do
  context "state types" do
    it "can be an error state" do
      state = described_class.new(:test, nil, nil, {type: :error})
      expect(state).to be_error
    end

    it "can be a final state" do
      state = described_class.new(:test, nil, nil, {type: :final})
      expect(state).to be_final
    end
  end
end
