# frozen_string_literal: true

RSpec.shared_examples 'cron schedulable with delay' do
  describe '#schedule_next_run!' do
    around do |example|
      travel_to(Time.utc(2024, 12, 20)) { example.run }
    end

    before do
      schedule.update_columns(next_run_at: 1.day.ago)

      allow(schedule).to receive_messages(cron: '0 0 * * *', cron_timezone: 'UTC', time_window_seconds: 3600)
    end

    # With cron "0 0 * * *" at frozen 2024-12-20 00:00 UTC, next tick is 2024-12-21 00:00 UTC.
    let(:expected_next_cron_time) { Time.utc(2024, 12, 21) }

    it 'updates next_run_at with a random delay within the effective time window' do
      allow(Random).to receive(:rand).with(3600).and_return(1800)

      schedule.schedule_next_run!

      expect(schedule.next_run_at).to eq(expected_next_cron_time + 1800.seconds)
      expect(schedule.next_run_applied_delay).to eq(1800)
    end

    it 'persists the changes' do
      schedule.schedule_next_run!

      expect(schedule).to be_persisted
      expect(schedule.reload.next_run_applied_delay).to be_present
    end

    context 'when effective_time_window returns nil' do
      before do
        allow(schedule).to receive(:effective_time_window).and_return(nil)
      end

      it 'sets next_run_at without a delay' do
        schedule.schedule_next_run!

        expect(schedule.next_run_at).to eq(expected_next_cron_time)
        expect(schedule.next_run_applied_delay).to eq(0)
      end
    end

    context 'when effective_time_window is capped to zero' do
      before do
        allow(schedule).to receive(:effective_time_window).and_return(0)
      end

      it 'sets next_run_at without a delay' do
        schedule.schedule_next_run!

        expect(schedule.next_run_at).to eq(expected_next_cron_time)
        expect(schedule.next_run_applied_delay).to eq(0)
      end
    end

    context 'when Random.rand returns zero' do
      before do
        allow(Random).to receive(:rand).with(3600).and_return(0)
      end

      it 'sets next_run_at to exactly the cron time' do
        schedule.schedule_next_run!

        expect(schedule.next_run_at).to eq(expected_next_cron_time)
        expect(schedule.next_run_applied_delay).to eq(0)
      end
    end
  end
end
