# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::RemoveOldDependencyGraphs, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:now) { Time.zone.now }
  let_it_be(:yesterday) { now - 1.day }
  let_it_be(:old_graph) { create_list(:sbom_graph_path, 4, project: project, created_at: yesterday) }
  let_it_be(:new_graph) { create_list(:sbom_graph_path, 4, project: project, created_at: now) }
  let(:expected_cache_key) { Sbom::LatestGraphTimestampCacheKey.new(project: project).cache_key }

  subject(:service) { described_class.new(project) }

  it 'attempts to read the timestamp from cache' do
    expect(Rails.cache).to receive(:read).with(expected_cache_key)
    service.execute
  end

  context 'when the runtime limit is not exceeded' do
    it 'removes old dependency graphs' do
      expect { service.execute }.to change { Sbom::GraphPath.by_projects(project).count }.from(8).to(4)
      expect(Sbom::GraphPath.by_projects(project).pluck(:created_at)).to all(be_like_time(now))
    end

    it 'exits with expected state' do
      expect(service.execute.payload).to eq({ job_status: :completed, deleted: 4 })
    end
  end

  context 'when the runtime limiter is exceeded' do
    let(:runtime_limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter, over_time?: true) }

    it 'exits after finishing the current batch' do
      stub_const("#{described_class.name}::BATCH_SIZE", 2)
      expect(Gitlab::Metrics::RuntimeLimiter).to receive(:new).with(4.minutes).and_return(runtime_limiter)

      expect(service.execute.payload).to eq({ job_status: :runtime_limit_reached, deleted: 2 })
    end
  end
end
