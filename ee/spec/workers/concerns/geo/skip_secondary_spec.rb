# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Geo::SkipSecondary, feature_category: :global_search do
  let_it_be(:project) { create(:project) }
  let!(:worker) do
    Class.new do
      def perform(project_id)
        project = Project.find(project_id)

        Search::Elastic::Indexer.new(project).run
      end

      def self.name
        'DummyIndexingWorker'
      end

      include ApplicationWorker
      prepend ::Geo::SkipSecondary
    end.new
  end

  let(:worker_args) { [project.id] }

  it 'includes all workers with feature_category :global_search' do
    exceptions = [
      PauseControl::ResumeWorker,
      ConcurrencyLimit::ResumeWorker
    ]

    workers = ObjectSpace.each_object(::Class).select do |klass|
      klass < ApplicationWorker &&
        klass.get_feature_category == :global_search &&
        exceptions.exclude?(klass)
    end

    workers.each do |worker|
      expect(worker.ancestors).to include(::Geo::SkipSecondary)
    end
  end

  context 'when ::Gitlab::Geo.secondary? is true' do
    before do
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(true)
    end

    it 'returns nil' do
      expect(worker).to receive(:geo_logger).once.and_call_original
      expect(Gitlab::Geo::Logger).to receive(:info).once.and_call_original
      expect(worker.perform(*worker_args)).to be_nil
    end
  end
end
