# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::FailStuckWorkflowsWorker, feature_category: :duo_agent_platform do
  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'executes CleanStuckWorkflowsService' do
      expect_next_instance_of(::Ai::DuoWorkflows::CleanStuckWorkflowsService) do |instance|
        expect(instance).to receive(:execute)
      end

      worker.perform
    end
  end
end
