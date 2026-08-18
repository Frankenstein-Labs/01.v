# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::RakeTaskExecutorService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:options) { { custom_option: 'value' } }
  let(:service) { described_class.new(logger: logger, options: options) }

  describe '#execute' do
    it 'raises an exception when unknown task is provided' do
      expect { service.execute(:foo) }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::Zoekt::RakeTaskExecutorService::TASKS', [:foo])

      expect { service.execute(:foo) }.to raise_error(NotImplementedError)
    end

    it 'delegates info task to InfoService with options' do
      info_service = instance_double(Search::Zoekt::InfoService, execute: true)
      expect(Search::Zoekt::InfoService).to receive(:new).with(logger: logger,
        options: options).and_return(info_service)

      service.execute(:info)
    end

    it 'delegates estimate_storage task to EstimateStorageService' do
      estimate_service = instance_double(Search::Zoekt::EstimateStorageService, execute: nil)
      expect(Search::Zoekt::EstimateStorageService).to receive(:new)
        .with(logger: logger).and_return(estimate_service)

      service.execute(:estimate_storage)
    end
  end

  describe '#execute(:index)' do
    let(:update_service) { instance_double(ApplicationSettings::UpdateService, execute: true) }

    before do
      allow(ApplicationSettings::UpdateService).to receive(:new).and_return(update_service)
      allow(logger).to receive(:info)
    end

    context 'when everything is already enabled' do
      before do
        stub_application_setting(
          zoekt_indexing_enabled: true,
          zoekt_search_enabled: true,
          zoekt_auto_index_root_namespace: true,
          zoekt_indexing_paused: false
        )
      end

      it 'logs that everything is already enabled' do
        expect(logger).to receive(:info).with(anything)
        expect(update_service).not_to receive(:execute)

        service.execute(:index)
      end
    end

    context 'when everything is disabled' do
      before do
        stub_application_setting(
          zoekt_indexing_enabled: false,
          zoekt_search_enabled: false,
          zoekt_auto_index_root_namespace: false,
          zoekt_indexing_paused: false
        )
      end

      it 'enables indexing, search, auto-indexing, and unpauses' do
        expect(ApplicationSettings::UpdateService).to receive(:new).with(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          {
            zoekt_indexing_enabled: true,
            zoekt_search_enabled: true,
            zoekt_auto_index_root_namespace: true,
            zoekt_indexing_paused: false
          }
        ).and_return(update_service)
        expect(update_service).to receive(:execute)
        expect(logger).to receive(:info).at_least(:once)

        service.execute(:index)
      end
    end

    context 'when indexing is enabled but search and auto-indexing are disabled' do
      before do
        stub_application_setting(
          zoekt_indexing_enabled: true,
          zoekt_search_enabled: false,
          zoekt_auto_index_root_namespace: false,
          zoekt_indexing_paused: false
        )
      end

      it 'enables search, auto-indexing, and unpauses' do
        expect(ApplicationSettings::UpdateService).to receive(:new).with(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          {
            zoekt_indexing_enabled: true,
            zoekt_search_enabled: true,
            zoekt_auto_index_root_namespace: true,
            zoekt_indexing_paused: false
          }
        ).and_return(update_service)
        expect(update_service).to receive(:execute)
        expect(logger).to receive(:info).at_least(:once)

        service.execute(:index)
      end
    end
  end

  describe '#execute(:disable)' do
    let(:update_service) { instance_double(ApplicationSettings::UpdateService, execute: true) }

    before do
      allow(ApplicationSettings::UpdateService).to receive(:new).and_return(update_service)
      allow(logger).to receive(:info)
    end

    context 'when indexing and search are already disabled' do
      before do
        stub_application_setting(zoekt_indexing_enabled: false, zoekt_search_enabled: false)
      end

      it 'logs that everything is already disabled' do
        expect(logger).to receive(:info).with(anything)
        expect(update_service).not_to receive(:execute)

        service.execute(:disable)
      end
    end

    context 'when indexing and search are enabled' do
      before do
        stub_application_setting(zoekt_indexing_enabled: true, zoekt_search_enabled: true)
      end

      it 'disables indexing and search and logs success' do
        expect(ApplicationSettings::UpdateService).to receive(:new).with(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { zoekt_indexing_enabled: false, zoekt_search_enabled: false }
        ).and_return(update_service)
        expect(update_service).to receive(:execute)
        expect(logger).to receive(:info).at_least(:once)

        service.execute(:disable)
      end
    end
  end

  describe '#execute(:pause_indexing)' do
    let(:update_service) { instance_double(ApplicationSettings::UpdateService, execute: true) }

    before do
      allow(ApplicationSettings::UpdateService).to receive(:new).and_return(update_service)
      allow(logger).to receive(:info)
    end

    context 'when indexing is already paused' do
      before do
        stub_application_setting(zoekt_indexing_paused: true)
      end

      it 'logs that indexing is already paused' do
        expect(logger).to receive(:info).with(anything)
        expect(update_service).not_to receive(:execute)

        service.execute(:pause_indexing)
      end
    end

    context 'when indexing is not paused' do
      before do
        stub_application_setting(zoekt_indexing_paused: false)
      end

      it 'pauses indexing and logs success' do
        expect(ApplicationSettings::UpdateService).to receive(:new).with(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { zoekt_indexing_paused: true }
        ).and_return(update_service)
        expect(update_service).to receive(:execute)
        expect(logger).to receive(:info).at_least(:once)

        service.execute(:pause_indexing)
      end
    end
  end

  describe '#execute(:resume_indexing)' do
    let(:update_service) { instance_double(ApplicationSettings::UpdateService, execute: true) }

    before do
      allow(ApplicationSettings::UpdateService).to receive(:new).and_return(update_service)
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)
    end

    context 'when indexing is not paused' do
      before do
        stub_application_setting(zoekt_indexing_paused: false)
      end

      it 'logs that indexing is already running' do
        expect(logger).to receive(:info).with(anything)
        expect(update_service).not_to receive(:execute)

        service.execute(:resume_indexing)
      end
    end

    context 'when indexing is paused but disabled' do
      before do
        stub_application_setting(zoekt_indexing_paused: true, zoekt_indexing_enabled: false)
      end

      it 'logs an error and does not resume' do
        expect(logger).to receive(:error).with(anything)
        expect(update_service).not_to receive(:execute)

        service.execute(:resume_indexing)
      end
    end

    context 'when indexing is paused and enabled' do
      before do
        stub_application_setting(zoekt_indexing_paused: true, zoekt_indexing_enabled: true)
      end

      it 'resumes indexing and logs success' do
        expect(ApplicationSettings::UpdateService).to receive(:new).with(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { zoekt_indexing_paused: false }
        ).and_return(update_service)
        expect(update_service).to receive(:execute)
        expect(logger).to receive(:info).at_least(:once)

        service.execute(:resume_indexing)
      end
    end
  end

  describe '#execute(:reindex_projects)' do
    it 'calls reindex_projects on an instance of IndexingSettingsService' do
      expect_next_instance_of(Search::Zoekt::IndexingSettingsService) do |instance|
        expect(instance).to receive(:reindex_projects)
      end
      service.execute(:reindex_projects)
    end
  end

  describe '#execute(:reindex_failed_projects)' do
    context 'when no project_ids option is provided' do
      it 'calls reindex_failed_projects with project_ids: nil' do
        expect_next_instance_of(Search::Zoekt::IndexingSettingsService) do |instance|
          expect(instance).to receive(:reindex_failed_projects).with(project_ids: nil)
        end

        service.execute(:reindex_failed_projects)
      end
    end

    context 'when project_ids option is provided' do
      let(:options) { { project_ids: [1, 2, 3] } }

      it 'calls reindex_failed_projects with the given project_ids' do
        expect_next_instance_of(Search::Zoekt::IndexingSettingsService) do |instance|
          expect(instance).to receive(:reindex_failed_projects).with(project_ids: [1, 2, 3])
        end

        service.execute(:reindex_failed_projects)
      end
    end
  end
end
