# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqConfig::CronJobInitializer, feature_category: :build do
  describe '.execute', :allow_unrouted_sidekiq_calls do
    subject(:execute) { described_class.execute }

    around do |example|
      Gitlab::SidekiqConfig::CronJobs.reset!
      example.run
      Gitlab::SidekiqConfig::CronJobs.reset!
    end

    before do
      allow(Gitlab::CurrentSettings).to receive(:uuid).and_return('d9e2f4e8-db1f-4e51-b03d-f427e1965c4a')
      allow(described_class).to receive(:rand).with(60).and_return(34, 43)
      allow(described_class).to receive(:rand).with(3..4).and_return(4)
    end

    context 'for sync_seat_link_worker cron job' do
      # explicit use of UTC for self-managed instances to ensure job runs after a Customers Portal job
      it 'schedules the job at the correct time' do
        execute

        jobs = Gitlab::SidekiqConfig.cron_jobs
        expect(jobs['sync_seat_link_worker']['cron']).to eq('34 4 * * * UTC')
      end
    end

    context 'for sync_service_token_worker cron job' do
      # explicit use of UTC for self-managed instances to ensure job runs after a SyncSeatLink job
      it 'schedules the job at the correct time' do
        execute

        jobs = Gitlab::SidekiqConfig.cron_jobs
        expect(jobs['sync_service_token_worker']['cron']).to eq('43 * * * * UTC')
      end
    end

    it 'configures mirror and geo cron jobs' do
      expect(Gitlab::Mirror).to receive(:configure_cron_job!)
      expect(Gitlab::Geo).to receive(:configure_cron_jobs!)

      execute
    end

    context 'for FOSS' do
      before do
        allow(GitlabEdition).to receive(:ee?).and_return(false)
      end

      it 'does not configure mirror and geo cron jobs' do
        expect(Gitlab::Mirror).not_to receive(:configure_cron_job!)
        expect(Gitlab::Geo).not_to receive(:configure_cron_jobs!)

        execute
      end
    end

    context 'as integration tests', :allow_unrouted_sidekiq_calls do
      before do
        allow(Gitlab::CurrentSettings).to receive(:uuid).and_return('d9e2f4e8-db1f-4e51-b03d-f427e1965c4a')
        allow(Gitlab::Mirror).to receive(:configure_cron_job!)
        allow(Gitlab::Geo).to receive(:configure_cron_jobs!)
      end

      context 'with EE schedule' do
        it 'provisions EE-only cron jobs into the registry' do
          described_class.execute

          job_names = Sidekiq::Cron::Job.all.map(&:name)
          expect(job_names).to include('geo_registry_sync_worker')
        end

        context 'for FOSS' do
          before do
            allow(GitlabEdition).to receive(:ee?).and_return(false)
          end

          it 'does not provision EE-only jobs' do
            described_class.execute

            expect(Sidekiq::Cron::Job.all.map(&:name)).not_to include('geo_registry_sync_worker')
          end
        end
      end

      context 'with SaaS schedule' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        it 'provisions SaaS-only cron jobs into the registry' do
          described_class.execute

          job_names = Sidekiq::Cron::Job.all.map(&:name)
          expect(job_names).to include('block_pipl_users_worker',
            'namespaces_schedule_dormant_member_removal_worker')
        end

        context 'when not on SaaS' do
          before do
            allow(Gitlab).to receive(:com?).and_return(false)
          end

          it 'does not provision SaaS-only jobs' do
            described_class.execute

            expect(Sidekiq::Cron::Job.find('block_pipl_users_worker')).to be_nil
          end
        end
      end
    end
  end
end
