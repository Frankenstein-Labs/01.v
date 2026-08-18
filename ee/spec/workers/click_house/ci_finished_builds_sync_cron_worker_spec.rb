# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::CiFinishedBuildsSyncCronWorker, :click_house, :freeze_time, feature_category: :fleet_visibility do
  let(:worker) { described_class.new }
  let(:total_workers) { 3 }
  let(:args) { [total_workers] }

  subject(:perform) { worker.perform(*args) }

  it 'invokes 3 workers' do
    expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(0, 3).once
    expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(1, 3).once
    expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(2, 3).once

    perform
  end

  context 'when arguments are not specified' do
    let(:args) { [] }

    it 'invokes 1 worker with specified arguments' do
      expect(ClickHouse::CiFinishedBuildsSyncWorker).to receive(:perform_async).with(0, 1)

      perform
    end
  end

  context 'when job version is nil' do
    before do
      allow(worker).to receive(:job_version).and_return(nil)
    end

    context 'when arguments are not specified' do
      it 'does nothing' do
        expect(ClickHouse::CiFinishedBuildsSyncWorker).not_to receive(:perform_async)

        perform
      end
    end
  end

  context 'when clickhouse database is not available' do
    before do
      allow(Gitlab::ClickHouse).to receive(:configured?).and_return(false)
    end

    it 'does nothing' do
      expect(ClickHouse::CiFinishedBuildsSyncWorker).not_to receive(:perform_async)

      perform
    end
  end
end
