# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::FlushActivityStatsWriteBufferCronWorker,
  :clean_gitlab_redis_shared_state, :freeze_time, feature_category: :dependency_firewall do
  let_it_be(:project) { create(:project) }
  let_it_be(:rule) { create(:dependency_firewall_policy_rule) }

  let(:stat_model) { Security::DependencyFirewallActivityStat }
  let(:hour) { Time.current.utc.beginning_of_hour }

  subject(:worker) { described_class.new }

  def record_blocked(times = 1)
    times.times { stat_model.increment!(rule_id: rule.id, project_id: project.id, outcome: :blocked) }
  end

  it_behaves_like 'an idempotent worker' do
    before do
      record_blocked(3)
    end

    it 'applies buffered counts exactly once across repeated runs' do
      perform_idempotent_work

      expect(stat_model.sum(:count)).to eq(3)
    end
  end

  it 'does nothing when the buffer is empty' do
    expect { worker.perform }.not_to change { stat_model.count }
  end

  it 'writes buffered activity to the database', :aggregate_failures do
    record_blocked

    expect { worker.perform }.to change { stat_model.count }.by(1)

    expect(stat_model.order(:id).last).to have_attributes(
      dependency_firewall_policy_rule_id: rule.id,
      project_id: project.id,
      outcome: 'blocked',
      count: 1,
      stat_time: be_like_time(hour)
    )
  end

  it 'collapses repeat activity into one row carrying the total', :aggregate_failures do
    record_blocked(5)

    expect { worker.perform }.to change { stat_model.count }.by(1)
    expect(stat_model.order(:id).last.count).to eq(5)
  end

  it 'accumulates onto an existing row from an earlier flush', :aggregate_failures do
    record_blocked(2)
    worker.perform

    record_blocked(3)
    expect { worker.perform }.not_to change { stat_model.count }

    expect(stat_model.order(:id).last.count).to eq(5)
  end

  it 'writes allowed activity with a NULL rule_id' do
    stat_model.increment!(project_id: project.id, outcome: :allowed)

    worker.perform

    expect(stat_model.order(:id).last).to have_attributes(
      dependency_firewall_policy_rule_id: nil, outcome: 'allowed', count: 1
    )
  end

  it 'empties the buffer so a second run is a no-op', :aggregate_failures do
    record_blocked
    worker.perform

    expect { worker.perform }.not_to change { stat_model.count }
    expect(stat_model.order(:id).last.count).to eq(1)
  end

  it 'reports what it flushed' do
    record_blocked(5)
    stat_model.increment!(project_id: project.id, outcome: :allowed)

    expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
      status: :processed, flushed_buckets: 2, discarded_buckets: 0, remaining_buckets: 0
    })

    worker.perform
  end

  it 'accumulates the tally across batches rather than reporting only the last one' do
    stub_const("#{described_class}::BATCH_SIZE", 1)
    record_blocked(5)
    stat_model.increment!(project_id: project.id, outcome: :allowed)

    expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
      status: :processed, flushed_buckets: 2, discarded_buckets: 0, remaining_buckets: 0
    })

    worker.perform
  end

  it 'counts activity that arrives mid-flush on the next run rather than dropping it', :aggregate_failures do
    record_blocked(2)

    allow(stat_model).to receive(:bulk_increment!).and_wrap_original do |original, rows|
      record_blocked # lands in the live buffer while the staged batch is being written
      original.call(rows)
    end

    worker.perform
    expect(stat_model.order(:id).last.count).to eq(2)

    worker.perform
    expect(stat_model.order(:id).last.count).to eq(3)
  end

  context 'when the database write fails' do
    before do
      allow(stat_model).to receive(:bulk_increment!).and_raise(ActiveRecord::StatementInvalid, 'boom')
    end

    it 'raises so Sidekiq retries' do
      record_blocked

      expect { worker.perform }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'keeps the counts staged so a later run applies them exactly once', :aggregate_failures do
      record_blocked(3)

      expect { worker.perform }.to raise_error(ActiveRecord::StatementInvalid)
      expect(stat_model.count).to eq(0)

      allow(stat_model).to receive(:bulk_increment!).and_call_original
      worker.perform

      expect(stat_model.order(:id).last.count).to eq(3)
    end
  end

  context 'when clearing the staged counts fails' do
    it 'rolls the write back so the counts are not applied without being cleared', :aggregate_failures do
      record_blocked(4)

      # write_buffer is memoized on the model, so stub the instance the worker will actually use.
      allow(stat_model.write_buffer).to receive(:remove_staged).and_raise(Redis::ConnectionError, 'redis gone')

      expect { worker.perform }.to raise_error(Redis::ConnectionError)
      expect(stat_model.count).to eq(0)
    end
  end

  context 'when a buffered project no longer exists' do
    it 'discards the orphaned counts and still writes the rest', :aggregate_failures do
      record_blocked(2)
      stat_model.increment!(project_id: non_existing_record_id, outcome: :allowed)

      expect { worker.perform }.not_to raise_error

      expect(stat_model.where(project_id: project.id).sum(:count)).to eq(2)
      expect(stat_model.where(project_id: non_existing_record_id)).to be_empty
    end

    it 'keeps saving counts on later runs once a deleted project has been discarded', :aggregate_failures do
      stat_model.increment!(project_id: non_existing_record_id, outcome: :allowed)
      worker.perform

      record_blocked(3)

      expect { worker.perform }.not_to raise_error
      expect(stat_model.where(project_id: project.id).sum(:count)).to eq(3)
    end
  end

  context 'when a batch mixes discardable and writable buckets' do
    let_it_be(:other_project) { create(:project) }

    # Not let_it_be: this rule is deleted, which must stay local to this context.
    let(:doomed_rule) { create(:dependency_firewall_policy_rule) }

    before do
      stat_model.increment!(project_id: non_existing_record_id, outcome: :allowed)
      2.times { stat_model.increment!(rule_id: doomed_rule.id, project_id: project.id, outcome: :blocked) }
      stat_model.increment!(project_id: other_project.id, outcome: :allowed)

      # Orphans the blocked bucket too, so the retry must arbitrate both kinds of dead reference.
      doomed_rule.delete
    end

    it 'discards each dead bucket and writes each live one, with nothing left staged', :aggregate_failures do
      expect { worker.perform }.not_to raise_error

      expect(stat_model.where(project_id: other_project.id).sum(:count)).to eq(1)
      expect(stat_model.where(project_id: project.id)).to be_empty
      expect(stat_model.write_buffer.staged_size).to eq(0)
    end

    it 'reports the discarded buckets, which is the signal that counts are being dropped' do
      expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
        status: :processed, flushed_buckets: 1, discarded_buckets: 2, remaining_buckets: 0
      })

      worker.perform
    end
  end

  context 'when the runtime limit is hit during the row-by-row retry' do
    it 'leaves unprocessed buckets staged for the next run instead of outliving the lease', :aggregate_failures do
      stat_model.increment!(project_id: non_existing_record_id, outcome: :allowed)
      record_blocked(2)

      over_time = true
      allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
        allow(limiter).to receive(:over_time?) { over_time }
        allow(limiter).to receive(:was_over_time?) { over_time }
      end

      worker.perform

      expect(stat_model.count).to eq(0)
      expect(stat_model.write_buffer.staged_size).to eq(2)

      over_time = false
      described_class.new.perform

      expect(stat_model.where(project_id: project.id).sum(:count)).to eq(2)
      expect(stat_model.write_buffer.staged_size).to eq(0)
    end

    it 'keeps the tally for the rows it did process before stopping', :aggregate_failures do
      stat_model.increment!(project_id: non_existing_record_id, outcome: :allowed)
      record_blocked(2)

      checks = 0
      allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
        allow(limiter).to receive(:over_time?) { (checks += 1) > 1 }
        allow(limiter).to receive(:was_over_time?) { checks > 1 }
      end

      payload = nil
      allow(worker).to receive(:log_extra_metadata_on_done) { |_, value| payload = value }

      worker.perform

      # Redis hash order is arbitrary, so the one processed row is either flushed or discarded.
      expect(payload[:status]).to eq(:over_time)
      expect(payload[:flushed_buckets] + payload[:discarded_buckets]).to eq(1)
      expect(stat_model.write_buffer.staged_size).to eq(1)
    end
  end

  context 'when another flush already holds the lease' do
    it 'defers, reporting the real staged backlog rather than a zero', :aggregate_failures do
      record_blocked(2)
      stat_model.write_buffer.stage! # as if the lease holder staged and has not finished

      allow(worker).to receive(:in_lock).and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
      expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
        status: :lease_taken, flushed_buckets: 0, discarded_buckets: 0, remaining_buckets: 1
      })

      expect { worker.perform }.not_to raise_error
      expect(stat_model.count).to eq(0)
    end
  end
end
