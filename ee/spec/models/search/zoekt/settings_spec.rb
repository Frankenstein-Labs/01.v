# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Settings, feature_category: :global_search do
  describe 'SETTINGS' do
    it 'defines expected settings' do
      expect(described_class::SETTINGS.keys).to include(
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_cache_response,
        :zoekt_cpu_to_tasks_ratio,
        :zoekt_indexing_parallelism,
        :zoekt_rollout_batch_size,
        :zoekt_lost_node_threshold,
        :zoekt_indexing_timeout,
        :zoekt_maximum_files,
        :zoekt_trigram_max,
        :zoekt_indexed_file_size_limit,
        :zoekt_rollout_retry_interval,
        :zoekt_default_number_of_replicas,
        :zoekt_force_reindexing_percentage,
        :zoekt_max_projects_for_legacy_search
      )
    end

    it 'has proper structure for each setting' do
      described_class::SETTINGS.each_value do |config|
        expect(config).to have_key(:type)
        expect(config).to have_key(:default)
        expect(config).to have_key(:label)
        expect(config[:label]).to be_a(Proc)
      end
    end

    # This spec ensures labels don't break the gitlab:zoekt:info output formatting
    # Long labels can break the output
    it 'has labels with reasonable length to prevent breaking info output' do
      max_label_length = 80 # Maximum reasonable length for display formatting

      described_class::SETTINGS.each do |setting_name, config|
        label = config[:label].call
        expect(label.length).to be <= max_label_length,
          "Label for '#{setting_name}' is too long (#{label.length} chars). " \
            "Maximum allowed is #{max_label_length} chars to prevent breaking gitlab:zoekt:info output formatting. " \
            "Label: #{label}"
      end
    end

    it 'has boolean settings with correct type' do
      boolean_settings = [
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_cache_response
      ]

      boolean_settings.each do |setting|
        expect(described_class::SETTINGS[setting][:type]).to eq(:boolean)
      end
    end

    it 'has numeric settings with correct type' do
      %i[zoekt_cpu_to_tasks_ratio zoekt_force_reindexing_percentage].each do |setting|
        expect(described_class::SETTINGS[setting][:type]).to eq(:float)
      end
      %i[
        zoekt_default_number_of_replicas
        zoekt_indexing_parallelism
        zoekt_max_restarts_15m
        zoekt_maximum_files
        zoekt_trigram_max
        zoekt_rollout_batch_size
        zoekt_max_projects_for_legacy_search
      ].each do |setting|
        expect(described_class::SETTINGS[setting][:type]).to eq(:integer)
      end
    end

    it 'has text settings with correct type' do
      %i[
        zoekt_lost_node_threshold
        zoekt_indexing_timeout
        zoekt_indexed_file_size_limit
        zoekt_rollout_retry_interval
      ].each do |setting|
        expect(described_class::SETTINGS[setting][:input_type]).to eq(:text_field)
      end
    end

    it 'defines input options' do
      expect(described_class::SETTINGS[:zoekt_cpu_to_tasks_ratio][:input_options]).to include(step: 0.1)
      expect(described_class::SETTINGS[:zoekt_force_reindexing_percentage][:input_options]).to include(
        step: 0.05, min: 0, max: 100
      )
      expect(described_class::SETTINGS[:zoekt_lost_node_threshold][:input_options]).to include(
        placeholder: format(
          N_("Must be in the following format: `30m`, `2h`, or `1d`. Set to `%{val}` to disable."),
          val: described_class::DISABLED_VALUE
        )
      )
      expect(described_class::SETTINGS[:zoekt_indexing_timeout][:input_options]).to include(
        placeholder: format(N_('Must be in the following format: `30m`, `2h`, or `1d`.'))
      )
      expect(described_class::SETTINGS[:zoekt_indexed_file_size_limit][:input_options]).to include(
        placeholder: format(
          N_('Must be in the following format: `5B`, `5b`, `1KB`, `1kb`, `2MB`, `2mb`, `1GB`, or `1gb`')
        )
      )
      expect(described_class::SETTINGS[:zoekt_rollout_retry_interval][:input_options]).to include(
        placeholder: format(
          N_("Must be in the following format: `30m`, `2h`, or `1d`. Set to `%{val}` for no retries."),
          val: described_class::DISABLED_VALUE
        )
      )
      expect(described_class::SETTINGS[:zoekt_max_restarts_15m][:input_options]).to include(min: 0)
    end

    it 'defines label' do
      all_settings = %i[
        zoekt_indexing_enabled
        zoekt_search_enabled
        zoekt_indexing_paused
        zoekt_auto_index_root_namespace
        zoekt_cache_response
        zoekt_cpu_to_tasks_ratio
        zoekt_indexing_parallelism
        zoekt_rollout_batch_size
        zoekt_trigram_max
        zoekt_lost_node_threshold
        zoekt_indexing_timeout
        zoekt_maximum_files
        zoekt_indexed_file_size_limit
        zoekt_rollout_retry_interval
        zoekt_default_number_of_replicas
        zoekt_force_reindexing_percentage
        zoekt_max_projects_for_legacy_search
        zoekt_max_restarts_15m
      ]
      all_labels = all_settings.map do |setting|
        described_class::SETTINGS[setting][:label].call
      end

      expect(all_labels).to eq(
        [
          _('Enable indexing'),
          _('Enable searching'),
          _('Pause indexing'),
          _('Index root namespaces automatically'),
          format(_("Cache search results for %{label}"), { label: ::Search::Zoekt::Cache.humanize_expires_in }),
          _('Indexing CPU to tasks multiplier'),
          _('Number of parallel processes per indexing task'),
          _('Number of namespaces per indexing rollout'),
          _('Maximum trigrams per file'),
          _('Offline nodes automatically deleted after'),
          _('Indexing timeout per project'),
          _('Maximum number of files per project to be indexed'),
          _('Maximum file size for indexing'),
          _('Retry interval for failed namespaces'),
          _('Number of replicas per namespace'),
          _('Probability of random force reindexing (percentage)'),
          _('Maximum number of projects for legacy search'),
          _('Maximum number of process restarts within 15 minutes for nodes')
        ]
      )
    end
  end

  describe 'FILTER_ADMIN_UI' do
    it 'is a callable lambda' do
      expect(described_class::FILTER_ADMIN_UI).to be_a(Proc)
    end

    it 'filters out settings with admin_ui set to false' do
      settings = {
        visible_setting: { admin_ui: true, type: :boolean },
        hidden_setting: { admin_ui: false, type: :boolean },
        default_setting: { type: :boolean }
      }

      filtered = described_class::FILTER_ADMIN_UI.call(settings)

      expect(filtered.keys).to contain_exactly(:visible_setting, :default_setting)
    end

    it 'filters out settings where admin_ui lambda returns false' do
      settings = {
        lambda_hidden: { admin_ui: -> { false }, type: :boolean },
        lambda_visible: { admin_ui: -> { true }, type: :boolean }
      }

      filtered = described_class::FILTER_ADMIN_UI.call(settings)

      expect(filtered.keys).to contain_exactly(:lambda_visible)
    end

    it 'keeps settings without admin_ui key' do
      settings = {
        setting_without_key: { type: :boolean },
        setting_with_true: { admin_ui: true, type: :boolean }
      }

      filtered = described_class::FILTER_ADMIN_UI.call(settings)

      expect(filtered.keys).to contain_exactly(:setting_without_key, :setting_with_true)
    end
  end

  describe '.all_settings' do
    it 'returns all settings' do
      expect(described_class.all_settings).to eq(described_class::SETTINGS)
    end

    it 'returns a frozen hash' do
      expect(described_class.all_settings).to be_frozen
    end
  end

  describe '.boolean_settings_ui' do
    it 'returns only boolean settings visible in the UI' do
      boolean_ui_settings = described_class.boolean_settings_ui

      expect(boolean_ui_settings.keys).to contain_exactly(
        :zoekt_indexing_enabled,
        :zoekt_search_enabled,
        :zoekt_indexing_paused,
        :zoekt_auto_index_root_namespace,
        :zoekt_cache_response
      )

      boolean_ui_settings.each_value do |config|
        expect(config[:type]).to eq(:boolean)
        expect(config[:admin_ui]).not_to be(false)
      end
    end
  end

  describe '.input_settings_ui' do
    it 'returns only input settings visible in the UI' do
      input_ui_settings = described_class.input_settings_ui

      expected_list = %i[
        zoekt_cpu_to_tasks_ratio
        zoekt_default_number_of_replicas
        zoekt_force_reindexing_percentage
        zoekt_indexed_file_size_limit
        zoekt_indexing_parallelism
        zoekt_indexing_timeout
        zoekt_lost_node_threshold
        zoekt_max_projects_for_legacy_search
        zoekt_max_restarts_15m
        zoekt_maximum_files
        zoekt_rollout_batch_size
        zoekt_rollout_retry_interval
        zoekt_trigram_max
      ]

      expect(input_ui_settings.keys).to match_array(expected_list)

      input_ui_settings.each_value do |config|
        expect(config[:type]).to be_in(%i[float integer text])
        value = config[:admin_ui]
        value = value.call if value.respond_to?(:call)
        expect(value).not_to be(false)
      end
    end

    context 'when ProcessHealth is not active' do
      before do
        allow(::Search::Zoekt::ProcessHealth).to receive(:active?).and_return(false)
      end

      it 'excludes zoekt_max_restarts_15m' do
        expect(described_class.input_settings_ui.keys).not_to include(:zoekt_max_restarts_15m)
      end
    end
  end

  describe '.indexing_timeout' do
    let_it_be(:_) { create(:application_setting) }

    context 'with various intervals' do
      before do
        stub_ee_application_setting(zoekt_indexing_timeout: interval)
      end

      using RSpec::Parameterized::TableSyntax

      where(:interval, :duration_interval) do
        '0'   | 30.minutes # default for invalid interval
        '1x'  | 30.minutes # default for invalid interval
        '5m'  | 5.minutes
        '2h'  | 2.hours
        '3d'  | 3.days
      end

      with_them do
        it 'returns the correct duration_interval' do
          expect(described_class.indexing_timeout).to eq(duration_interval)
        end
      end
    end
  end

  describe '.file_size_limit' do
    subject(:file_size_limit) { described_class.file_size_limit }

    context 'with different combinations of set value' do
      let_it_be(:_) { create(:application_setting) }

      before do
        stub_ee_application_setting(zoekt_indexed_file_size_limit: set_size_limit)
      end

      using RSpec::Parameterized::TableSyntax

      where(:set_size_limit, :result) do
        '1xy' | 1.megabyte # Invalid value is set, return the default
        '5B'  | 5.bytes
        '5KB' | 5.kilobytes
        '2kb' | 2.kilobytes
        '1MB' | 1.megabyte
        '2mb' | 2.megabytes
        '5GB' | 5.gigabytes
        '2gb' | 2.gigabytes
      end

      with_them do
        it 'returns the correct size in bytes' do
          expect(file_size_limit).to eq(result)
        end
      end
    end

    context 'when ApplicationSetting is not present' do
      it 'returns default value' do
        expect(file_size_limit).to eq(1.megabyte)
      end
    end
  end

  describe '.rollout_retry_interval' do
    context 'with various intervals' do
      let_it_be(:_) { create(:application_setting) }

      before do
        stub_ee_application_setting(zoekt_rollout_retry_interval: interval)
      end

      using RSpec::Parameterized::TableSyntax

      where(:interval, :duration_interval) do
        '0'   | nil # nil for 0 means retry is disabled
        '1x'  | 1.day # default for invalid interval
        '5m'  | 5.minutes
        '2h'  | 2.hours
        '3d'  | 3.days
      end

      with_them do
        it 'returns the correct duration_interval' do
          expect(described_class.rollout_retry_interval).to eq(duration_interval)
        end
      end
    end

    context 'when ApplicationSetting is not present' do
      it 'returns nil' do
        expect(described_class.rollout_retry_interval).to be_nil
      end
    end
  end

  describe '.lost_node_threshold' do
    context 'with various intervals' do
      let_it_be(:_) { create(:application_setting) }

      before do
        stub_ee_application_setting(zoekt_lost_node_threshold: interval)
      end

      using RSpec::Parameterized::TableSyntax

      where(:interval, :duration_interval) do
        '0'   | nil # nil for 0 means disabled
        '1x'  | 12.hours # default for invalid interval
        '5m'  | 5.minutes
        '2h'  | 2.hours
        '3d'  | 3.days
      end

      with_them do
        it 'returns the correct duration_interval' do
          expect(described_class.lost_node_threshold).to eq(duration_interval)
        end
      end
    end

    context 'when ApplicationSetting is not present' do
      it 'returns nil' do
        expect(described_class.lost_node_threshold).to be_nil
      end
    end
  end

  describe '.default_number_of_replicas' do
    subject(:default_number_of_replicas) { described_class.default_number_of_replicas }

    context 'with different combinations of set value' do
      let_it_be(:_) { create(:application_setting) }

      before do
        stub_ee_application_setting(zoekt_default_number_of_replicas: set_number)
      end

      using RSpec::Parameterized::TableSyntax
      where(:set_number, :return_value) do
        0 | 0
        1 | 1
        2 | 2
      end
      with_them do
        it 'returns the set number of replicas' do
          expect(default_number_of_replicas).to eq(return_value)
        end
      end
    end

    context 'when ApplicationSetting is not present' do
      it 'returns default value' do
        expect(default_number_of_replicas).to eq(1)
      end
    end
  end

  describe '.force_reindexing_percentage' do
    subject { described_class.force_reindexing_percentage }

    context 'with different combinations of set value' do
      let_it_be(:_) { create(:application_setting) }

      before do
        stub_ee_application_setting(zoekt_force_reindexing_percentage: set_percentage)
      end

      using RSpec::Parameterized::TableSyntax
      where(:set_percentage, :return_value) do
        0.0   | 0.0
        0.25  | 0.25
        0.5   | 0.5
        1.0   | 1.0
        50.0  | 50.0
        100.0 | 100.0
      end
      with_them do
        it { is_expected.to eq(return_value) }
      end
    end
  end

  describe '.max_projects_for_legacy_search' do
    subject(:max_projects_for_legacy_search) { described_class.max_projects_for_legacy_search }

    context 'with different combinations of set value' do
      let_it_be(:_) { create(:application_setting) }

      before do
        stub_ee_application_setting(zoekt_max_projects_for_legacy_search: set_value)
      end

      using RSpec::Parameterized::TableSyntax
      where(:set_value, :return_value) do
        100   | 100
        1_000 | 1_000
        5_000 | 5_000
      end
      with_them do
        it 'returns the set value' do
          expect(max_projects_for_legacy_search).to eq(return_value)
        end
      end
    end

    context 'when ApplicationSetting is not present' do
      it 'returns default value' do
        expect(max_projects_for_legacy_search).to eq(1_000)
      end
    end
  end
end
