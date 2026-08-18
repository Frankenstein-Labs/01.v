# frozen_string_literal: true

module EE
  module GeoHelpers
    def stub_current_geo_node(node)
      allow(::Gitlab::Geo).to receive(:current_node).and_return(node)
      allow(GeoNode).to receive(:current_node).and_return(node)

      # GeoNode.current? returns true only when the node is passed
      # otherwise it returns false
      allow(GeoNode).to receive(:current?).and_return(false)
      allow(GeoNode).to receive(:current?).with(node).and_return(true)
    end

    def stub_current_node_name(name)
      allow(GeoNode).to receive(:current_node_name).and_return(name)
    end

    def stub_primary_site
      allow(::Gitlab::Geo).to receive(:primary?).and_return(true)
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(false)
      allow(::Gitlab::Geo).to receive(:secondary_or_org_migration_target?).and_return(false)
    end
    alias_method :stub_primary_node, :stub_primary_site

    def stub_secondary_site
      allow(::Gitlab::Geo).to receive(:primary?).and_return(false)
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(true)
      allow(::Gitlab::Geo).to receive(:secondary_or_org_migration_target?).and_return(true)
    end
    alias_method :stub_secondary_node, :stub_secondary_site

    def stub_org_migration_target_cell(node = create(:geo_node))
      stub_feature_flags(org_migration_target_cell: true)
      stub_current_geo_node(node)
      node
    end

    def stub_geo_nodes_exist_but_none_match_current_node
      allow(::Gitlab::Geo).to receive(:enabled?).and_return(true)
      allow(::Gitlab::Geo).to receive(:primary?).and_return(false)
      allow(::Gitlab::Geo).to receive(:secondary?).and_return(false)
      allow(::Gitlab::Geo).to receive(:current_node).and_return(nil)
    end

    def stub_proxied_request
      allow(::Gitlab::Geo).to receive(:proxied_request?).and_return(true)
    end

    def stub_proxied_site(node)
      stub_proxied_request

      allow(::Gitlab::Geo).to receive(:proxied_site).and_return(node)
    end

    def create_project_on_shard(shard_name)
      project = create(:project)

      # skipping validation which requires the shard name to exist in Gitlab.config.repositories.storages.keys
      project.update_column(:repository_storage, shard_name)

      project
    end

    def stub_batch_counter_transaction_open_check
      # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
      # is not allowed within a transaction but all RSpec tests run inside of a transaction.
      allow_next_instance_of(::Gitlab::Database::BatchCounter) do |batch_counter|
        allow(batch_counter).to receive(:transaction_open?).and_return(false)
      end
    end

    def factory_name(klass)
      klass_name = klass.name
      default_factory_name = klass_name.underscore.tr('/', '_').to_sym

      custom_mapping = {
        'Ci::JobArtifact' => :ee_ci_job_artifact,
        'MergeRequestDiff' => :external_merge_request_diff,
        'Packages::PackageFile' => :package_file,
        'Projects::WikiRepository' => :project_wiki_repository,
        'Packages::Debian::ProjectComponentFile' => :debian_project_component_file,
        'Packages::Nuget::Symbol' => :nuget_symbol,
        'Packages::Helm::MetadataCache' => :helm_metadata_cache
      }

      custom_mapping.fetch(klass_name, default_factory_name)
    end

    def model_class_factory_name(registry_class)
      factory_name(registry_class.model_class)
    end

    def registry_factory_name(registry_class)
      factory_name(registry_class)
    end

    def unstub_geo_database_configured
      # We need to unstub it or the DatabaseCleaner will have issues since it
      # will appear as though the tracking DB were not available
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_call_original
    end

    def with_geo_database_configured(enabled:, &block)
      allow(::Gitlab::Geo).to receive(:geo_database_configured?).and_return(enabled)

      yield

      unstub_geo_database_configured
    end

    def stub_dummy_replicator_class(model_class: 'DummyModel')
      stub_const('Geo::DummyReplicator', Class.new(::Gitlab::Geo::Replicator))

      ::Geo::DummyReplicator.class_eval do
        event :test
        event :another_test

        # rubocop:disable Gitlab/ModuleWithInstanceVariables -- we're in a stubbed class definition
        @model_class = model_class

        def self.model
          @model_class.constantize
        end
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        def self.replicable_title
          s_('Geo|Dummy')
        end

        def self.replicable_title_plural
          s_('Geo|Dummies')
        end

        def geo_handle_after_checksum_succeeded
          true
        end

        def geo_handle_after_destroy
          true
        end

        protected

        def consume_event_test(user:, other:)
          true
        end
      end
    end

    def stub_dummy_model_class
      stub_const('DummyModel', Class.new(ApplicationRecord))

      DummyModel.class_eval do
        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel
        include ::Geo::VerificationStateDefinition

        with_replicator Geo::DummyReplicator

        self.table_name = '_test_dummy_models'

        def self.replicables_for_current_secondary(primary_key_in)
          self.primary_key_in(primary_key_in)
        end

        def self.selective_sync_scope(node, **_params)
          all
        end

        def self.replicable_title
          s_('Geo|Dummy')
        end

        def self.replicable_title_plural
          s_('Geo|Dummies')
        end
      end

      DummyModel.reset_column_information
    end

    def stub_dummy_replication_feature_flag(replicator_class: 'Geo::DummyReplicator', enabled: true)
      replicator = Object.const_get(replicator_class, false)
      allow(replicator).to receive(:replication_enabled?).and_return(enabled)
    end

    def stub_dummy_verification_feature_flag(replicator_class: 'Geo::DummyReplicator', enabled: true)
      replicator = Object.const_get(replicator_class, false)
      allow(replicator).to receive(:verification_enabled?).and_return(enabled)
    end

    # Example:
    #
    # before(:all) do
    #   create_dummy_model_table
    # end
    #
    # after(:all) do
    #   drop_dummy_model_table
    # end
    def create_dummy_model_table
      ActiveRecord::Schema.define do
        create_table :_test_dummy_models, force: true do |t|
          t.binary :verification_checksum
          t.integer :verification_state
          t.datetime_with_timezone :verification_started_at
          t.datetime_with_timezone :verified_at
          t.datetime_with_timezone :verification_retry_at
          t.integer :verification_retry_count
          t.text :verification_failure
        end
      end
    end

    def drop_dummy_model_table
      ActiveRecord::Schema.define do
        drop_table :_test_dummy_models, force: true
      end
    end

    # Example:
    #
    # before(:all) do
    #   create_dummy_model_with_separate_state_table
    # end

    # after(:all) do
    #   drop_dummy_model_with_separate_state_table
    # end

    # before do
    #   stub_dummy_model_with_separate_state_class
    # end

    def create_dummy_model_with_separate_state_table
      ActiveRecord::Schema.define do
        create_table :_test_dummy_model_with_separate_states, force: true
      end

      ActiveRecord::Schema.define do
        create_table :_test_dummy_model_states, id: false, force: true do |t|
          t.bigint :_test_dummy_model_with_separate_state_id
          t.binary :verification_checksum
          t.integer :verification_state
          t.datetime_with_timezone :verification_started_at
          t.datetime_with_timezone :verified_at
          t.datetime_with_timezone :verification_retry_at
          t.integer :verification_retry_count
          t.text :verification_failure
        end
      end
    end

    def drop_dummy_model_with_separate_state_table
      ActiveRecord::Schema.define do
        drop_table :_test_dummy_model_with_separate_states, force: true
      end

      ActiveRecord::Schema.define do
        drop_table :_test_dummy_model_states, force: true
      end
    end

    def stub_dummy_model_with_separate_state_class
      stub_const('TestDummyModelWithSeparateState', Class.new(ApplicationRecord))

      TestDummyModelWithSeparateState.class_eval do
        self.table_name = '_test_dummy_model_with_separate_states'

        include ::Geo::ReplicableModel
        include ::Geo::VerifiableModel

        delegate(*::Geo::VerificationState::VERIFICATION_METHODS, to: :_test_dummy_model_state)

        with_replicator Geo::DummyReplicator

        has_one :_test_dummy_model_state,
          autosave: false,
          inverse_of: :_test_dummy_model_with_separate_state,
          foreign_key: :_test_dummy_model_with_separate_state_id

        scope :with_verification_state, ->(state) {
          available_verifiables
            .where(_test_dummy_model_states: { verification_state: verification_state_value(state) })
        }

        def verification_state_object
          _test_dummy_model_state
        end

        def self.selective_sync_scope(node, **_params)
          all
        end

        def self.replicable_title
          s_('Geo|Dummy')
        end

        def self.replicable_title_plural
          s_('Geo|Dummies')
        end

        def self.replicables_for_current_secondary(primary_key_in)
          self.primary_key_in(primary_key_in)
        end

        def self.verification_state_table_class
          TestDummyModelState
        end

        private

        def _test_dummy_model_state
          super || build__test_dummy_model_state
        end
      end

      TestDummyModelWithSeparateState.reset_column_information

      stub_const('TestDummyModelState', Class.new(ApplicationRecord))

      TestDummyModelState.class_eval do
        include ::Geo::VerificationStateDefinition

        self.table_name = '_test_dummy_model_states'
        self.primary_key = '_test_dummy_model_with_separate_state_id'

        belongs_to :_test_dummy_model_with_separate_state, inverse_of: :_test_dummy_model_state
      end

      TestDummyModelState.reset_column_information
    end

    def skip_if_verification_is_enabled
      return unless replicator_class.verification_enabled?

      skip "Skipping because verification is enabled for #{replicator_class.model}"
    end

    def skip_if_verification_is_not_enabled
      return if replicator_class.verification_enabled?

      skip "Skipping because verification is not enabled for #{replicator_class.model}"
    end

    def stub_dummy_console_action
      stub_const('DummyGeoConsoleAction', Class.new(Geo::Console::Action))

      DummyGeoConsoleAction.class_eval do
        def name
          "Dummy action"
        end

        def execute
          @output_stream.puts "Executing" # rubocop:disable Gitlab/ModuleWithInstanceVariables -- subclass of code under test
        end
      end
    end

    def stub_dummy_console_multiple_choice_menu
      stub_const('DummyGeoConsoleMultipleChoiceMenu', Class.new(Geo::Console::MultipleChoiceMenu))

      DummyGeoConsoleMultipleChoiceMenu.class_eval do
        def name
          "Dummy action"
        end

        def choices
          [Geo::Console::Exit.new]
        end
      end
    end
  end
end
