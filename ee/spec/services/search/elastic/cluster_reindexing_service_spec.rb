# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::ClusterReindexingService, :elastic, :clean_gitlab_redis_shared_state,
  feature_category: :global_search do
  subject(:cluster_reindexing_service) { described_class.new }

  let(:helper) { Search::Elastic::Helper.default }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true)
    allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
  end

  context 'for state: initial' do
    let(:task) { create(:elastic_reindexing_task, state: :initial) }

    context 'when elasticsearch_indexing is false' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'aborts and returns an error' do
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('failure')
          .and not_change { Gitlab::CurrentSettings.elasticsearch_advanced_search_pause_indexing }

        expect(task.reload.error_message).to match(/Elasticsearch indexing is disabled/)
      end
    end

    it 'aborts if the main index does not use aliases' do
      allow(Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(false)
      allow(helper).to receive(:alias_exists?).and_return(false)

      expect { cluster_reindexing_service.execute }
        .to change { task.reload.state }.from('initial').to('failure')
        .and not_change { Gitlab::CurrentSettings.elasticsearch_advanced_search_pause_indexing }

      expect(task.reload.error_message).to match(/use aliases/)
    end

    it 'aborts if there are pending ES migrations' do
      allow(Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(true)

      expect { cluster_reindexing_service.execute }
        .to change { task.reload.state }.from('initial').to('failure')
        .and not_change { Gitlab::CurrentSettings.elasticsearch_advanced_search_pause_indexing }

      expect(task.reload.error_message).to match(/unapplied advanced search migrations/)
    end

    it 'does not fail if there are pending ES migrations and skip_pending_migrations_check set' do
      task.update!(options: { skip_pending_migrations_check: true })

      allow(Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(true)

      expect { cluster_reindexing_service.execute }
        .to change { task.reload.state }.from('initial').to('indexing_paused')
    end

    it 'errors when there is not enough space' do
      allow(helper).to receive_messages(index_size_bytes: 100.megabytes, cluster_free_size_bytes: 30.megabytes)

      expect { cluster_reindexing_service.execute }
        .to change { task.reload.state }.from('initial').to('failure')
        .and not_change { Gitlab::CurrentSettings.elasticsearch_advanced_search_pause_indexing }

      expect(task.reload.error_message).to match(/storage available/)
    end

    it 'pauses advanced search indexing' do
      expect { cluster_reindexing_service.execute }
        .to change { task.reload.state }.from('initial').to('indexing_paused')
        .and change { Gitlab::CurrentSettings.elasticsearch_advanced_search_pause_indexing? }.from(false).to(true)
    end

    context 'when full reindex includes migrations index' do
      let!(:task) { create(:elastic_reindexing_task, state: :initial) }

      before do
        allow(helper).to receive(:index_size_bytes).and_call_original
      end

      it 'includes migrations index size in storage calculation' do
        allow(helper).to receive_messages(cluster_free_size_bytes: 8.megabytes, index_size_bytes: 0)
        allow(helper).to receive(:index_size_bytes)
          .with(index_name: helper.migrations_index_name)
          .and_return(5.megabytes)

        # 5MB * 2 = 10MB required, 8MB available -> fail
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('failure')
        expect(task.reload.error_message).to match(/at least 10485760 bytes/)
      end

      it 'aborts reindexing when connection error occurs during size calculation' do
        allow(helper).to receive(:index_size_bytes)
          .with(index_name: helper.migrations_index_name)
          .and_raise(Gitlab::Search::Client::ConnectionError.new('Search is currently unavailable'))

        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('failure')
        expect(task.reload.error_message).to match(/Failed to calculate index size/)
      end
    end

    context 'when MigrationsIndexConfig explicitly requested but migration not ready' do
      let(:task) do
        create(:elastic_reindexing_task, state: :initial, targets: ['Search::Elastic::MigrationsIndexConfig'],
          options: { skip_pending_migrations_check: true })
      end

      before do
        set_elasticsearch_migration_to(:delete_legacy_migrations_index, including: false)
      end

      it 'aborts reindexing with clear error message' do
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('failure')

        expect(task.reload.error_message).to match(/MigrationsIndexConfig was explicitly requested/)
        expect(task.reload.error_message).to match(/delete_legacy_migrations_index migration has not finished/)
      end
    end

    context 'when no targets supplied and migration not finished' do
      let!(:task) do
        create(:elastic_reindexing_task, state: :initial, targets: nil,
          options: { skip_pending_migrations_check: true })
      end

      before do
        set_elasticsearch_migration_to(:delete_legacy_migrations_index, including: false)
      end

      it 'excludes migrations index from reindex' do
        allow(helper).to receive_messages(
          index_size_bytes: 10.megabytes,
          cluster_free_size_bytes: 300.megabytes
        )

        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('indexing_paused')

        # Migrations index should not be in target_classes when migration not finished
        expect(cluster_reindexing_service.send(:target_classes))
          .not_to include(Search::Elastic::MigrationsIndexConfig)
      end
    end

    context 'when partial reindexing' do
      let(:task) { create(:elastic_reindexing_task, state: :initial, targets: %w[Project User]) }

      it 'errors when there is not enough space' do
        allow(helper).to receive(:index_size_bytes).twice.and_return(10.megabytes)
        allow(helper).to receive(:cluster_free_size_bytes).and_return(30.megabytes)

        expect { cluster_reindexing_service.execute }.to change { task.reload.state }.from('initial').to('failure')
        expect(task.reload.error_message).to match(/storage available/)
      end
    end

    context 'when MigrationsIndexConfig.ready? returns false' do
      let_it_be(:task) do
        create(:elastic_reindexing_task, targets: nil, options: { skip_pending_migrations_check: true })
      end

      before do
        allow(Search::Elastic::MigrationsIndexConfig).to receive(:ready?).and_return(false)
        allow(helper).to receive_messages(index_size_bytes: 10.megabytes, cluster_free_size_bytes: 300.megabytes)
      end

      it 'excludes migrations index from target_classes' do
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('indexing_paused')

        expect(cluster_reindexing_service.send(:target_classes))
          .not_to include(Search::Elastic::MigrationsIndexConfig)
      end
    end

    context 'when MigrationsIndexConfig.ready? returns true' do
      let_it_be(:task) do
        create(:elastic_reindexing_task, targets: nil, options: { skip_pending_migrations_check: true })
      end

      before do
        allow(Search::Elastic::MigrationsIndexConfig).to receive(:ready?).and_return(true)
        allow(helper).to receive_messages(index_size_bytes: 10.megabytes, cluster_free_size_bytes: 300.megabytes)
      end

      it 'includes migrations index in target_classes' do
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('indexing_paused')

        expect(cluster_reindexing_service.send(:target_classes))
          .to include(Search::Elastic::MigrationsIndexConfig)
      end
    end

    context 'when elasticsearch_migrations_type_class feature flag is disabled' do
      before do
        stub_feature_flags(elasticsearch_migrations_type_class: false)
        allow(helper).to receive_messages(
          index_size_bytes: 10.megabytes,
          cluster_free_size_bytes: 300.megabytes
        )
      end

      context 'with blank targets and migrations index not ready' do
        let!(:task) do
          create(:elastic_reindexing_task, state: :initial, targets: nil,
            options: { skip_pending_migrations_check: true })
        end

        before do
          allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:delete_legacy_migrations_index)
            .and_return(false)
        end

        it 'excludes migrations index from target_classes' do
          expect { cluster_reindexing_service.execute }
            .to change { task.reload.state }.from('initial').to('indexing_paused')

          expect(cluster_reindexing_service.send(:target_classes))
            .not_to include(Search::Elastic::MigrationsIndexConfig)
        end
      end

      context 'with blank targets and migrations index ready' do
        let!(:task) do
          create(:elastic_reindexing_task, state: :initial, targets: nil,
            options: { skip_pending_migrations_check: true })
        end

        before do
          allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:delete_legacy_migrations_index)
            .and_return(true)
        end

        it 'includes migrations index in target_classes' do
          expect { cluster_reindexing_service.execute }
            .to change { task.reload.state }.from('initial').to('indexing_paused')

          expect(cluster_reindexing_service.send(:target_classes))
            .to include(Search::Elastic::MigrationsIndexConfig)
        end
      end

      context 'with explicit MigrationsIndexConfig target that is not ready' do
        let(:task) do
          create(:elastic_reindexing_task, state: :initial,
            targets: ['Search::Elastic::MigrationsIndexConfig'],
            options: { skip_pending_migrations_check: true })
        end

        before do
          allow(Elastic::DataMigrationService).to receive(:migration_has_finished?)
            .with(:delete_legacy_migrations_index)
            .and_return(false)
        end

        it 'aborts reindexing with error message' do
          expect { cluster_reindexing_service.execute }
            .to change { task.reload.state }.from('initial').to('failure')

          expect(task.reload.error_message).to include('MigrationsIndexConfig was explicitly requested')
          expect(task.reload.error_message).to include('delete_legacy_migrations_index migration has not finished')
        end
      end
    end

    context 'when target class with ready? method is not ready' do
      let_it_be(:task) do
        create(:elastic_reindexing_task, targets: ['Search::Elastic::MigrationsIndexConfig'],
          options: { skip_pending_migrations_check: true })
      end

      before do
        allow(Search::Elastic::MigrationsIndexConfig).to receive(:ready?).and_return(false)
      end

      it 'aborts reindexing with backward-compatible error message for MigrationsIndexConfig' do
        expect { cluster_reindexing_service.execute }.to change { task.reload.state }.from('initial').to('failure')
        expect(task.reload.error_message).to match(/MigrationsIndexConfig was explicitly requested/)
        expect(task.reload.error_message).to match(/delete_legacy_migrations_index migration has not finished/)
      end
    end

    context 'when generic target class with ready? method is not ready' do
      let(:mock_index_config) do
        Class.new do
          def self.name
            'Search::Elastic::CustomIndexConfig'
          end

          def self.ready?
            false
          end
        end
      end

      let_it_be(:task) do
        create(:elastic_reindexing_task,
          targets: ['Search::Elastic::CustomIndexConfig'],
          options: { skip_pending_migrations_check: true })
      end

      before do
        stub_const('Search::Elastic::CustomIndexConfig', mock_index_config)
        allow(task).to receive(:target_classes).and_return([mock_index_config])
      end

      it 'aborts reindexing with generic error message' do
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('initial').to('failure')

        expect(task.reload.error_message)
          .to match(/Search::Elastic::CustomIndexConfig was explicitly requested but is not ready/)
        expect(task.reload.error_message).to match(/Please wait for required migrations to complete/)
      end
    end
  end

  context 'for state: indexing_paused' do
    let(:notes_alias) { Note.__elasticsearch__.index_name }
    let(:notes_old_index_name) { "#{notes_alias}-1" }
    let(:notes_new_index_name) { "#{notes_alias}-reindex" }

    let(:main_alias) { Repository.__elasticsearch__.index_name }
    let(:main_old_index_name) { "#{main_alias}-1" }
    let(:main_new_index_name) { "#{main_alias}-reindex" }

    context 'when targets are empty' do
      let!(:task) { create(:elastic_reindexing_task, state: :indexing_paused, targets: nil) }

      before do
        allow(helper).to receive(:target_index_names) { |options| { "#{options[:target]}-1" => true } }
        allow(helper).to receive_messages(
          create_standalone_indices: { notes_new_index_name => notes_alias },
          create_empty_index: { main_new_index_name => main_alias }
        )
        allow(helper).to receive(:reindex) { |options| "#{options[:to]}_task_id" }
        allow(helper).to receive(:get_settings) do |options|
          number_of_shards = case options[:index_name]
                             when main_old_index_name then 10
                             when notes_old_index_name then 1
                             else
                               1
                             end
          { 'number_of_shards' => number_of_shards.to_s }
        end
      end

      it 'creates subtasks and slices' do
        expect { cluster_reindexing_service.execute }
          .to change { task.reload.state }.from('indexing_paused').to('reindexing')

        subtasks = task.subtasks
        # +1 for main index, +1 for migrations index (full reindex includes migrations)
        expect(subtasks.count).to eq(helper.standalone_indices_proxies.count + 2)

        subtask_1 = subtasks.find { |subtask| subtask.alias_name == main_alias }
        slice_1 = subtask_1.slices.first
        expect(subtask_1.index_name_to).to eq(main_new_index_name)
        expect(subtask_1.slices.count).to eq(20)
        expect(slice_1.elastic_max_slice).to eq(20)
        expect(slice_1.elastic_task).to eq("#{main_new_index_name}_task_id")
        expect(slice_1.elastic_slice).to eq(0)

        subtask_2 = subtasks.find { |subtask| subtask.alias_name == notes_alias }
        slice_2 = subtask_2.slices.last
        expect(subtask_2.index_name_to).to eq(notes_new_index_name)
        expect(subtask_2.slices.count).to eq(2)
        expect(slice_2.elastic_max_slice).to eq(2)
        expect(slice_2.elastic_task).to eq("#{notes_new_index_name}_task_id")
        expect(slice_2.elastic_slice).to eq(1)
      end
    end

    context 'when targets are provided' do
      let!(:task) { create(:elastic_reindexing_task, state: :indexing_paused, targets: targets) }

      before do
        allow(helper).to receive(:target_index_names) { |options| { "#{options[:target]}-1" => true } }
      end

      context 'when targets set to note and repository' do
        let(:targets) { %w[Note Repository] }

        it 'creates multiple indices' do
          expect(helper).to receive(:create_empty_index).once.and_return(main_new_index_name => main_alias)

          is_expected.to receive(:launch_subtasks).once.with(
            array_including(
              {
                alias_name: notes_alias,
                index_name_from: notes_old_index_name,
                index_name_to: anything
              },
              {
                alias_name: main_alias,
                index_name_from: main_old_index_name,
                index_name_to: anything
              }
            )
          )

          cluster_reindexing_service.execute
        end
      end

      context 'when targets do not include repository' do
        let(:targets) { %w[Note] }

        it 'does not create the main index' do
          expect(helper).not_to receive(:create_empty_index)
          is_expected.to receive(:launch_subtasks).with(
            array_including(
              hash_including(
                alias_name: notes_alias,
                index_name_from: notes_old_index_name,
                index_name_to: anything
              )
            ))

          cluster_reindexing_service.execute
        end
      end
    end

    context 'when partial reindex without migrations specified' do
      let!(:task) { create(:elastic_reindexing_task, state: :indexing_paused, targets: %w[Note]) }
      let(:notes_alias) { Note.__elasticsearch__.index_name }
      let(:notes_new_index_name) { "#{notes_alias}-reindex" }

      before do
        set_elasticsearch_migration_to(:delete_legacy_migrations_index, including: true)

        allow(helper).to receive(:target_index_names) { |options| { "#{options[:target]}-1" => true } }
        allow(helper).to receive_messages(
          create_standalone_indices: { notes_new_index_name => notes_alias },
          get_settings: { 'number_of_shards' => '2' },
          reindex: 'task_id'
        )
      end

      it 'does not create migrations subtask' do
        cluster_reindexing_service.execute

        subtasks = task.reload.subtasks
        expect(subtasks.map(&:alias_name)).not_to include(helper.migrations_index_name)
      end
    end

    context 'when migrations index explicitly targeted' do
      let!(:task) do
        create(
          :elastic_reindexing_task,
          state: :indexing_paused,
          targets: ['Note', 'Search::Elastic::MigrationsIndexConfig']
        )
      end

      let(:migrations_alias) { helper.migrations_index_name }
      let(:migrations_old_index) { "#{migrations_alias}-20240101-1200" }
      let(:notes_alias) { Note.__elasticsearch__.index_name }
      let(:notes_new_index_name) { "#{notes_alias}-reindex" }

      before do
        allow(helper).to receive(:target_index_names) do |options|
          case options[:target]
          when migrations_alias
            { migrations_old_index => true }
          else
            { "#{options[:target]}-1" => true }
          end
        end

        allow(helper).to receive_messages(
          create_standalone_indices: { notes_new_index_name => notes_alias },
          create_index: nil,
          get_settings: { 'number_of_shards' => '1' },
          reindex: 'task_id'
        )
      end

      it 'creates migrations subtask', :aggregate_failures do
        cluster_reindexing_service.execute

        subtasks = task.reload.subtasks
        migrations_subtasks = subtasks.select { |st| st.alias_name == migrations_alias }

        expect(migrations_subtasks.count).to eq(1)
        expect(migrations_subtasks.first).to be_present
        expect(migrations_subtasks.first.index_name_from).to eq(migrations_old_index)
        expect(migrations_subtasks.first.slices.count).to eq(task.slice_multiplier)
      end

      it 'creates migrations index with correct settings' do
        expect(helper).to receive(:create_index).once.with(
          hash_including(
            alias_name: migrations_alias,
            with_alias: false,
            settings: hash_including(number_of_shards: 1),
            mappings: ::Search::Elastic::MigrationsIndexConfig.mappings
          )
        )

        cluster_reindexing_service.execute
      end
    end

    describe 'index creation' do
      let_it_be_with_reload(:task) { create(:elastic_reindexing_task, state: :indexing_paused, targets: %w[Note]) }

      before do
        allow(helper).to receive(:target_index_names) { |options| { "#{options[:target]}-1" => true } }
      end

      context 'when using AWS OpenSearch Service' do
        before do
          stub_ee_application_setting(elasticsearch_aws: true)
          allow(helper).to receive(:matching_distribution?).with(:opensearch).and_return(true)
        end

        it 'creates indices without async translog durability' do
          expect(helper).to receive(:create_standalone_indices).with(
            with_alias: false,
            options: { settings: { refresh_interval: '10s', number_of_replicas: 0 }, name_suffix: anything },
            target_classes: [Note]
          ).and_return(notes_new_index_name => notes_alias)

          is_expected.to receive(:launch_subtasks)

          cluster_reindexing_service.execute
        end
      end

      context 'when using AWS Elasticsearch (not OpenSearch)' do
        before do
          stub_ee_application_setting(elasticsearch_aws: true)
          allow(helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
          allow(helper).to receive_messages(serverless?: false, nodes_settings: {})
        end

        it 'creates indices with async translog durability' do
          expect(helper).to receive(:create_standalone_indices).with(
            with_alias: false,
            options: {
              settings: { refresh_interval: '10s', number_of_replicas: 0, translog: { durability: 'async' } },
              name_suffix: anything
            },
            target_classes: [Note]
          ).and_return(notes_new_index_name => notes_alias)

          is_expected.to receive(:launch_subtasks)

          cluster_reindexing_service.execute
        end
      end

      context 'when using self-managed OpenSearch' do
        before do
          stub_ee_application_setting(elasticsearch_aws: false)
          allow(helper).to receive(:serverless?).and_return(false)
          allow(helper).to receive(:matching_distribution?).with(:opensearch).and_return(true)
        end

        context 'when async-durability is restricted on a node' do
          before do
            allow(helper).to receive(:nodes_settings).and_return(
              'node1' => { 'settings' => { 'cluster.remote_store.index.restrict.async-durability' => 'true' } }
            )
          end

          it 'creates indices without async translog durability' do
            expect(helper).to receive(:create_standalone_indices).with(
              with_alias: false,
              options: { settings: { refresh_interval: '10s', number_of_replicas: 0 }, name_suffix: anything },
              target_classes: [Note]
            ).and_return(notes_new_index_name => notes_alias)

            is_expected.to receive(:launch_subtasks)

            cluster_reindexing_service.execute
          end
        end

        context 'when async-durability is not restricted' do
          before do
            allow(helper).to receive(:nodes_settings).and_return(
              'node1' => { 'settings' => {} }
            )
          end

          it 'creates indices with async translog durability' do
            expect(helper).to receive(:create_standalone_indices).with(
              with_alias: false,
              options: {
                settings: { refresh_interval: '10s', number_of_replicas: 0, translog: { durability: 'async' } },
                name_suffix: anything
              },
              target_classes: [Note]
            ).and_return(notes_new_index_name => notes_alias)

            is_expected.to receive(:launch_subtasks)

            cluster_reindexing_service.execute
          end
        end

        context 'when nodes_settings returns no nodes' do
          before do
            allow(helper).to receive(:nodes_settings).and_return({})
          end

          it 'treats as not restricted and creates indices with async translog durability' do
            expect(helper).to receive(:create_standalone_indices).with(
              with_alias: false,
              options: {
                settings: { refresh_interval: '10s', number_of_replicas: 0, translog: { durability: 'async' } },
                name_suffix: anything
              },
              target_classes: [Note]
            ).and_return(notes_new_index_name => notes_alias)

            is_expected.to receive(:launch_subtasks)

            cluster_reindexing_service.execute
          end
        end
      end

      context 'when using Elasticsearch Serverless' do
        before do
          stub_ee_application_setting(elasticsearch_aws: false)
          allow(helper).to receive(:serverless?).and_return(true)
        end

        it 'creates indices without async translog durability' do
          expect(helper).to receive(:create_standalone_indices).with(
            with_alias: false,
            options: { settings: { refresh_interval: '10s', number_of_replicas: 0 }, name_suffix: anything },
            target_classes: [Note]
          ).and_return(notes_new_index_name => notes_alias)

          is_expected.to receive(:launch_subtasks)

          cluster_reindexing_service.execute
        end
      end

      context 'when using Elasticsearch' do
        before do
          stub_ee_application_setting(elasticsearch_aws: false)
          allow(helper).to receive(:serverless?).and_return(false)
          allow(helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
        end

        it 'creates indices with async translog durability' do
          expect(helper).to receive(:create_standalone_indices).with(
            with_alias: false,
            options: {
              settings: { refresh_interval: '10s', number_of_replicas: 0, translog: { durability: 'async' } },
              name_suffix: anything
            },
            target_classes: [Note]
          ).and_return(notes_new_index_name => notes_alias)

          is_expected.to receive(:launch_subtasks)

          cluster_reindexing_service.execute
        end
      end

      context 'when index creation raises BadRequest' do
        before do
          stub_ee_application_setting(elasticsearch_aws: false)
          allow(helper).to receive(:serverless?).and_return(false)
          allow(helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
          allow(helper).to receive(:create_standalone_indices)
                             .and_raise(Elasticsearch::Transport::Transport::Errors::BadRequest)
        end

        it 'aborts reindexing and unpauses advanced search indexing' do
          expect(Gitlab::CurrentSettings).to receive(:update!).with(elasticsearch_advanced_search_pause_indexing: false)

          expect { cluster_reindexing_service.execute }
            .to change { task.reload.state }.from('indexing_paused').to('failure')

          expect(task.reload.error_message).to match(/Failed to create reindex target indices/)
        end
      end
    end
  end

  context 'for state: reindexing' do
    let!(:task) { create(:elastic_reindexing_task, state: :reindexing, max_slices_running: 1) }
    let!(:subtask) { create(:elastic_reindexing_subtask, elastic_reindexing_task: task, documents_count: 10) }
    let!(:slices) { [slice_1, slice_2, slice_3] }
    let(:refresh_interval) { nil }
    let(:slice_1) do
      create(:elastic_reindexing_slice, elastic_reindexing_subtask: subtask, elastic_max_slice: 3, elastic_slice: 0)
    end

    let(:slice_2) do
      create(:elastic_reindexing_slice, elastic_reindexing_subtask: subtask, elastic_max_slice: 3, elastic_slice: 1)
    end

    let(:slice_3) do
      create(:elastic_reindexing_slice, elastic_reindexing_subtask: subtask, elastic_max_slice: 3, elastic_slice: 2)
    end

    let(:expected_default_settings) do
      {
        refresh_interval: refresh_interval,
        number_of_replicas: Elastic::IndexSetting[subtask.alias_name].number_of_replicas,
        translog: { durability: 'request' }
      }
    end

    before do
      allow(helper).to receive_messages(
        task_status: {
          'completed' => true,
          'response' => { 'total' => 20, 'created' => 20, 'updated' => 0, 'deleted' => 0 }
        },
        refresh_index: true
      )
      allow(helper).to receive(:reindex).and_return('task_1', 'task_2', 'task_3', 'task_4', 'task_5', 'task_6')
    end

    context 'when errors are raised' do
      context 'when documents count does not match' do
        before do
          allow(helper).to receive(:documents_count).with(index_name: subtask.index_name_from, refresh: anything)
            .and_return(subtask.reload.documents_count)
          allow(helper).to receive(:documents_count).with(index_name: subtask.index_name_to, refresh: anything)
            .and_return(subtask.reload.documents_count * 2)
          allow(helper).to receive(:get_settings).with(index_name: subtask.index_name_from)
        end

        it 'changes task state to failure' do
          # kick off reindexing for each slice
          slices.count.times do
            cluster_reindexing_service.execute
          end

          expect { cluster_reindexing_service.execute }.to change { task.reload.state }.from('reindexing').to('failure')
          expect(task.reload.error_message).to match(/count is different/)
        end
      end

      context 'when reindexing slice failed' do
        let(:failure_response) { { 'completed' => true, 'error' => { 'type' => 'search_phase_execution_exception' } } }

        before do
          cluster_reindexing_service.execute # run once to kick off reindexing for slices

          allow(helper).to receive(:task_status).and_return(failure_response)
        end

        context 'when retry limit is reached on a slice' do
          it 'errors and changes task state from reindexing to failed' do
            stub_const("#{described_class}::REINDEX_MAX_RETRY_LIMIT", 0)

            expect { cluster_reindexing_service.execute }.to change { task.reload.state }
              .from('reindexing').to('failure')
            expect(task.reload.error_message).to match(/Task failed. Retry limit reached. Aborting reindexing/)
          end
        end

        context 'when the retry limit has not been reached' do
          it 'increases retry_attempt and tries the slice again' do
            expect { cluster_reindexing_service.execute }
              .to change { slices.first.reload.retry_attempt }.by(1).and change { slices.first.reload.elastic_task }
            expect(task.reload.state).to eq('reindexing')
            expect(helper).to have_received(:reindex).with(from: subtask.index_name_from, to: subtask.index_name_to,
              max_slice: 3, slice: 0, scroll: described_class::REINDEX_SCROLL).twice
          end
        end

        context 'when failures reported in response' do
          let(:failure_response) do
            {
              completed: true,
              response: {
                failures: [
                  {
                    index: 'gitlab-test-users',
                    id: 'user_1',
                    cause: {
                      type: 'strict_dynamic_mapping_exception',
                      reason: 'mapping set to strict, dynamic introduction of [new_field] within [_doc] is not allowed'
                    },
                    status: 400
                  },
                  {
                    index: 'gitlab-test-users',
                    id: "user_2",
                    cause: {
                      type: 'strict_dynamic_mapping_exception',
                      reason: 'mapping set to strict, dynamic introduction of [new_field] within [_doc] is not allowed'
                    },
                    status: 400
                  }
                ]
              }
            }.with_indifferent_access
          end

          context 'when retry limit is reached on a slice' do
            it 'errors and changes task state from reindexing to failed' do
              stub_const("#{described_class}::REINDEX_MAX_RETRY_LIMIT", 0)

              expect { cluster_reindexing_service.execute }
                .to change { task.reload.state }.from('reindexing').to('failure')
              expect(task.reload.error_message).to match(/Task failed. Retry limit reached. Aborting reindexing/)
            end
          end

          context 'when retry limit has not been reached' do
            it 'increases retry_attempt and tries the slice again' do
              expect { cluster_reindexing_service.execute }
                .to change { slices.first.reload.retry_attempt }.by(1).and change { slices.first.reload.elastic_task }
              expect(task.reload.state).to eq('reindexing')
              expect(helper).to have_received(:reindex).with(from: subtask.index_name_from, to: subtask.index_name_to,
                max_slice: 3, slice: 0, scroll: described_class::REINDEX_SCROLL).twice
            end
          end
        end
      end

      context 'when slice totals do not match' do
        before do
          cluster_reindexing_service.execute # run once to kick off reindexing for slices

          allow(helper).to receive(:task_status).and_return(
            {
              'completed' => true,
              'response' => { 'total' => 20, 'created' => 10, 'updated' => 0, 'deleted' => 0 }
            }
          )
        end

        context 'when retry limit is reached on a slice' do
          it 'errors and changes task state from reindexing to failed' do
            stub_const("#{described_class}::REINDEX_MAX_RETRY_LIMIT", 0)

            expect { cluster_reindexing_service.execute }
              .to change { task.reload.state }.from('reindexing').to('failure')
            expect(task.reload.error_message)
              .to match(/Task totals not equal. Retry limit reached. Aborting reindexing/)
          end
        end

        context 'when retry limit has not been reached' do
          it 'increases retry_attempt and reindexes the slice again' do
            expect { cluster_reindexing_service.execute }
              .to change { slices.first.reload.retry_attempt }.by(1).and change { slices.first.reload.elastic_task }
            expect(task.reload.state).to eq('reindexing')
            # once for initial reindex, once for retry
            expect(helper)
              .to have_received(:reindex)
              .with(from: subtask.index_name_from, to: subtask.index_name_to, max_slice: 3, slice: 0,
                scroll: described_class::REINDEX_SCROLL).twice
          end
        end
      end

      it 'errors if task is not found' do
        cluster_reindexing_service.execute # run once to kick off reindexing for slices
        allow(helper).to receive(:task_status).and_raise(Gitlab::Search::Client::ConnectionError.new('Task not found'))

        expect { cluster_reindexing_service.execute }.to change { task.reload.state }.from('reindexing').to('failure')
        expect(task.reload.error_message).to match(/couldn't load task status/i)
      end

      it 'errors if ConnectionError is raised' do
        cluster_reindexing_service.execute # run once to kick off reindexing for slices
        allow(helper).to receive(:task_status).and_raise(Gitlab::Search::Client::ConnectionError.new('Connection lost'))

        expect { cluster_reindexing_service.execute }.to change { task.reload.state }.from('reindexing').to('failure')
        expect(task.reload.error_message).to match(/couldn't load task status/i)
      end
    end

    it 'enqueues another job' do
      expect { cluster_reindexing_service.execute }
        .to change { Search::Elastic::ClusterReindexingCronWorker.jobs.size }.by(1)
    end

    context 'for slice batching' do
      it 'kicks off the next set of slices if the current slice is finished', :aggregate_failures do
        expect { cluster_reindexing_service.execute }.to change { slice_1.reload.elastic_task }
        expect(helper).to have_received(:reindex).with(from: subtask.index_name_from, to: subtask.index_name_to,
          max_slice: 3, slice: 0, scroll: described_class::REINDEX_SCROLL)

        expect { cluster_reindexing_service.execute }.to change { slice_2.reload.elastic_task }
        expect(helper).to have_received(:reindex).with(from: subtask.index_name_from, to: subtask.index_name_to,
          max_slice: 3, slice: 1, scroll: described_class::REINDEX_SCROLL)

        expect { cluster_reindexing_service.execute }.to change { slice_3.reload.elastic_task }
        expect(helper).to have_received(:reindex).with(from: subtask.index_name_from, to: subtask.index_name_to,
          max_slice: 3, slice: 2, scroll: described_class::REINDEX_SCROLL)
      end
    end

    context 'when applying settings to migrations index' do
      let(:migrations_alias) { helper.migrations_index_name }
      let(:subtask) do
        create(
          :elastic_reindexing_subtask,
          elastic_reindexing_task: task,
          alias_name: migrations_alias,
          index_name_from: 'old-migrations',
          index_name_to: 'new-migrations',
          documents_count: 10,
          documents_count_target: 10
        )
      end

      before do
        allow(helper).to receive(:get_settings).with(index_name: 'old-migrations')
          .and_return({ 'refresh_interval' => '1s', 'number_of_replicas' => '1' })
        allow(helper).to receive(:update_settings)
        allow(helper).to receive(:documents_count).and_return(10)
        allow(helper).to receive(:multi_switch_alias)
      end

      it 'retrieves replicas from old index settings, not IndexSetting table' do
        slices.count.times do
          cluster_reindexing_service.execute
        end

        expect(helper).to receive(:update_settings).with(
          index_name: 'new-migrations',
          settings: hash_including(number_of_replicas: 1)
        )

        cluster_reindexing_service.execute
      end
    end

    context 'when task finishes successfully' do
      using RSpec::Parameterized::TableSyntax

      where(:refresh_interval, :current_settings) do
        nil | {}
        '60s' | { refresh_interval: '60s' }
      end

      with_them do
        before do
          allow(helper).to receive(:documents_count).with(index_name: subtask.index_name_from, refresh: anything)
            .and_return(subtask.reload.documents_count)
          allow(helper).to receive(:documents_count).with(index_name: subtask.index_name_to, refresh: anything)
            .and_return(subtask.reload.documents_count)
          allow(helper).to receive(:get_settings).with(index_name: subtask.index_name_from)
            .and_return(current_settings.with_indifferent_access)
        end

        it 'launches all state steps' do
          expect(helper).to receive(:update_settings)
            .with(index_name: subtask.index_name_to, settings: expected_default_settings)
          actions = [
            { remove: { index: subtask.index_name_from, alias: subtask.alias_name } },
            { add: { index: subtask.index_name_to, alias: subtask.alias_name, is_write_index: true } }
          ]
          expect(helper).to receive(:multi_switch_alias).with(actions: actions)
          expect(Gitlab::CurrentSettings).to receive(:update!).with(elasticsearch_advanced_search_pause_indexing: false)

          # kick off reindexing for each slice
          slices.count.times do
            cluster_reindexing_service.execute
          end

          expect { cluster_reindexing_service.execute }
            .to change { task.reload.state }.from('reindexing').to('success')
          expect(task.reload.delete_original_index_at)
            .to be_within(1.minute).of(described_class::DELETE_ORIGINAL_INDEX_AFTER.from_now)
        end
      end
    end
  end
end
