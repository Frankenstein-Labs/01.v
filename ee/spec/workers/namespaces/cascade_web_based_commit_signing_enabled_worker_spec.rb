# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::CascadeWebBasedCommitSigningEnabledWorker, type: :worker, feature_category: :source_code_management do
  let(:group) do
    create(:group, namespace_settings: namespace_settings)
  end

  let(:namespace_settings) do
    create(:namespace_settings, web_based_commit_signing_enabled: web_based_commit_signing_enabled)
  end

  let(:web_based_commit_signing_enabled) { true }

  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'calls cascade_for_instance on service with the correct argument' do
      expect_next_instance_of(Namespaces::CascadeWebBasedCommitSigningEnabledService,
        web_based_commit_signing_enabled) do |service|
        expect(service).to receive(:execute)
      end

      worker.perform(group.id)
    end
  end
end
