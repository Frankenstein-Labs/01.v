# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::CronManager, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  geo_jobs = %w[
    repository_check_worker
    geo_checksum_mismatch_reporting_worker
    geo_ci_job_artifact_verification_summary_calculator_worker
    geo_registry_sync_worker
    geo_repository_registry_sync_worker
    geo_metrics_update_worker
    geo_prune_event_log_worker
    geo_verification_cron_worker
    geo_secondary_usage_data_cron_worker
    geo_sync_timeout_cron_worker
    concurrency_limit_resume_worker
  ].freeze

  non_geo_jobs = %w[ldap_test]

  def sidekiq_redis_pool
    Gitlab::Redis::Queues.sidekiq_redis
  end

  def job(name)
    Sidekiq::Client.via(sidekiq_redis_pool) do
      Sidekiq::Cron::Job.find(name)
    end
  end

  def init_cron_job(job_name, class_name, status: 'enabled')
    Sidekiq::Client.via(sidekiq_redis_pool) do
      Sidekiq::Cron::Job.new(
        name: job_name,
        cron: '0 * * * *',
        class: class_name,
        status: status
      ).save # rubocop:disable Rails/SaveBang -- No ActiveRecord
    end
  end

  subject(:manager) { described_class.new }

  it 'lists every geo_ job from ee/config/schedule.yml in one of its job constants' do
    known_geo_jobs = described_class::COMMON_GEO_JOBS + described_class::COMMON_GEO_AND_NON_GEO_JOBS +
      described_class::PRIMARY_GEO_JOBS + described_class::SECONDARY_GEO_JOBS

    scheduled_geo_jobs = YAML.safe_load_file(Rails.root.join('ee/config/schedule.yml')).keys
      .select { |name| name.start_with?('geo_') }

    unmanaged_jobs = scheduled_geo_jobs - known_geo_jobs

    expect(unmanaged_jobs).to be_empty,
      "#{unmanaged_jobs.join(', ')} #{unmanaged_jobs.size == 1 ? 'is' : 'are'} scheduled in " \
        "ee/config/schedule.yml but missing from Gitlab::Geo::CronManager's job lists, so " \
        "configure_non_geo_site would never disable it on a non-Geo site"
  end

  describe '#execute' do
    let_it_be(:current_node_name, freeze: true) { Gitlab.config.geo.node_name }
    let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary, name: current_node_name) }

    let(:common_geo_jobs) { [job('geo_metrics_update_worker'), job('geo_verification_cron_worker')] }
    let(:ldap_test_job) { job('ldap_test') }
    let(:primary_jobs) do
      [
        job('geo_ci_job_artifact_verification_summary_calculator_worker'),
        job('geo_prune_event_log_worker')
      ]
    end

    let(:repository_check_job) { job('repository_check_worker') }
    let(:secondary_jobs) do
      [
        job('geo_checksum_mismatch_reporting_worker'),
        job('geo_registry_sync_worker'),
        job('geo_repository_registry_sync_worker'),
        job('geo_secondary_usage_data_cron_worker'),
        job('geo_sync_timeout_cron_worker')
      ]
    end

    before_all do
      geo_jobs.each { |name| init_cron_job(name, name.camelize) }
      non_geo_jobs.each { |name| init_cron_job(name, name.camelize, status: 'disabled') }
    end

    after(:all) do
      (geo_jobs + non_geo_jobs).each { |name| job(name)&.destroy } # rubocop: disable Rails/SaveBang -- No ActiveRecord
    end

    def count_enabled(jobs)
      jobs.count { |job_name| job(job_name).enabled? }
    end

    context 'on a Geo primary' do
      before do
        manager.execute
      end

      it 'disables secondary-only jobs' do
        secondary_jobs.each { |job| expect(job).not_to be_enabled }
      end

      it 'enables common Geo jobs' do
        expect(common_geo_jobs).to all(be_enabled)
      end

      it 'enables primary-only jobs' do
        expect(primary_jobs).to all(be_enabled)
      end

      it 'enables repository check job' do
        expect(repository_check_job).to be_enabled
      end

      it 'does not enable non-geo jobs' do
        expect(ldap_test_job).not_to be_enabled
      end

      context 'No connection' do
        it 'does not change current job configuration' do
          allow(Geo).to receive(:connected?).and_return(false)

          expect { manager.execute }.not_to change { count_enabled(geo_jobs + non_geo_jobs) }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        # Without stubbing we would receive the following validation error:
        # `Validation failed: Current node must be the primary node or you will be locking yourself out`
        allow(GeoNode).to receive(:current_node).and_return create(:geo_node)

        manager.execute
      end

      it 'enables secondary-only jobs' do
        expect(secondary_jobs).to all(be_enabled)
      end

      it 'enables common Geo jobs' do
        expect(common_geo_jobs).to all(be_enabled)
      end

      it 'enables repository check job' do
        expect(repository_check_job).to be_enabled
      end

      it 'disables primary-only jobs' do
        primary_jobs.each { |job| expect(job).not_to be_enabled }
      end

      it 'disables non-geo jobs' do
        expect(ldap_test_job).not_to be_enabled
      end
    end

    context 'on a non-Geo node' do
      before do
        allow(GeoNode).to receive(:current_node).and_return nil

        manager.execute
      end

      it 'disables primary-only jobs' do
        primary_jobs.each { |job| expect(job).not_to be_enabled }
      end

      it 'disables secondary-only jobs' do
        secondary_jobs.each { |job| expect(job).not_to be_enabled }
      end

      it 'disables common Geo jobs' do
        common_geo_jobs.each { |job| expect(job).not_to be_enabled }
      end

      it 'enables repository check job' do
        expect(repository_check_job).to be_enabled
      end

      it 'does not enable non-geo jobs' do
        expect(ldap_test_job).not_to be_enabled
      end
    end

    context 'on an org migration target' do
      before do
        stub_org_migration_target_cell

        manager.execute
      end

      it 'enables secondary-only jobs' do
        expect(secondary_jobs).to all(be_enabled)
      end

      it 'enables common Geo jobs' do
        expect(common_geo_jobs).to all(be_enabled)
      end

      it 'enables repository check job' do
        expect(repository_check_job).to be_enabled
      end

      it 'disables primary-only jobs' do
        primary_jobs.each { |job| expect(job).not_to be_enabled }
      end

      it 'does not disable non-geo jobs' do
        # The target cell is writable, so unlike a secondary, it must not
        # disable non-Geo application jobs.
        Sidekiq::Client.via(sidekiq_redis_pool) { ldap_test_job.enable! }

        fresh_manager = described_class.new
        stub_org_migration_target_cell

        fresh_manager.execute

        expect(ldap_test_job).to be_enabled
      end
    end
  end

  describe '#create_watcher!' do
    it 'creates a Geo::SidekiqCronConfigWorker sidekiq-cron job' do
      manager.create_watcher!

      created = job('geo_sidekiq_cron_config_worker')

      expect(created).not_to be_nil
      expect(created.klass).to eq('Geo::SidekiqCronConfigWorker')
      expect(created.cron).to eq('*/1 * * * *')
      expect(created.name).to eq('geo_sidekiq_cron_config_worker')
    end
  end

  describe '#enable_all_jobs!' do
    name = "job"

    before do
      init_cron_job(name, name.camelize, status: 'disabled')
    end

    after(:all) do
      job(name).destroy # rubocop: disable Rails/SaveBang -- No ActiveRecord
    end

    it 'enables all jobs' do
      manager.enable_all_jobs!

      expect(job(name)).to be_enabled
    end
  end
end
