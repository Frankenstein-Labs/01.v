# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversation::CleanupCronWorker, feature_category: :duo_chat, type: :worker do
  describe '#perform' do
    let_it_be(:setting) { create(:application_setting) }

    it_behaves_like 'an idempotent worker'

    it 'executes CleanupService' do
      expect_next_instance_of(Ai::Conversation::CleanupService) do |service|
        expect(service).to receive(:execute)
      end

      described_class.new.perform
    end
  end
end
