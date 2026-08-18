# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::RepositoryXray::ScanDependenciesWorker, type: :worker, feature_category: :code_suggestions do
  let_it_be(:project) do
    create(:project, :custom_repo, files:
      {
        'Gemfile.lock' =>
          <<~CONTENT
            GEM
              remote: https://rubygems.org/
              specs:
                bcrypt (3.1.20)
          CONTENT
      })
  end

  let(:worker) { described_class.new }

  include_examples 'an idempotent worker' do
    let(:job_args) { [project.id] }
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it 'has the option to reschedule once if deduplicated and a TTL' do
    expect(described_class.get_deduplication_options).to include(
      { if_deduplicated: :reschedule_once, ttl: Ai::RepositoryXray::ScanDependenciesService::LEASE_TIMEOUT })
  end

  describe '#perform' do
    let(:project_id) { project.id }

    subject(:perform) { worker.perform(project_id) }

    it 'calls Ai::RepositoryXray::ScanDependenciesService' do
      expect_next_instance_of(Ai::RepositoryXray::ScanDependenciesService) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      perform
    end

    it 'logs the service response' do
      expect(worker).to receive(:log_hash_metadata_on_done)
        .with(
          status: :success,
          message: 'Found 1 dependency config files',
          success_messages: ['Found 1 dependencies in `Gemfile.lock` (RubyGemsLock)'],
          error_messages: [],
          max_dependency_count: 1
        )

      perform
    end

    context 'when there is no project with the given ID' do
      let(:project_id) { 0 }

      it 'does not call Ai::RepositoryXray::ScanDependenciesService' do
        expect(Ai::RepositoryXray::ScanDependenciesService).not_to receive(:new)

        perform
      end
    end
  end
end
