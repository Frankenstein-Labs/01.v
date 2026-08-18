# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::InfoService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger, options: options) }
  let(:settings) { instance_double(ApplicationSetting) }
  let(:current_time) { Time.current.change(usec: 0) }
  let(:version_info) { Gitlab::VersionInfo.new(15, 0, 0) }
  let(:online_relation) { instance_double(ActiveRecord::Relation, count: 0, to_a: []) }
  let(:options) { {} }

  before do
    allow(logger).to receive(:info)
    allow(ApplicationSetting).to receive(:current).and_return(settings)
    allow(settings).to receive_messages(
      zoekt_indexing_enabled: true,
      zoekt_search_enabled: true,
      zoekt_indexing_paused: false,
      zoekt_cache_response: true,
      zoekt_auto_index_root_namespace: true,
      zoekt_cpu_to_tasks_ratio: 1.5,
      zoekt_force_reindexing_percentage: 0.25,
      zoekt_indexing_parallelism: 1,
      zoekt_maximum_files: 500_000,
      zoekt_rollout_batch_size: 32,
      zoekt_indexing_timeout: '30m',
      zoekt_indexed_file_size_limit: '1KB',
      zoekt_trigram_max: 20000,
      zoekt_rollout_retry_interval: '1d',
      zoekt_lost_node_threshold: '24h',
      zoekt_default_number_of_replicas: 1,
      zoekt_max_projects_for_legacy_search: 1000,
      zoekt_max_restarts_15m: 1
    )
    allow(Gitlab).to receive(:version_info).and_return(version_info)
    allow(Feature).to receive_messages(
      current_request: nil,
      enabled?: false,
      persisted_name?: false
    )
    allow(Search::Zoekt::Index).to receive(:sum).and_return(0)
  end

  describe '#execute' do
    context 'when extended_mode is false' do
      let(:options) { { extended_mode: false } }

      it 'does not display nodes section' do
        service.execute

        expect(logger).to have_received(:info).with(/GitLab version/)
        expect(logger).not_to have_received(:info).with("\n#{Rainbow('Node Details').bright.yellow.underline}")
      end
    end

    context 'when extended_mode is true' do
      let(:options) { { extended_mode: true } }

      it 'displays nodes section' do
        service.execute

        expect(logger).to have_received(:info).with(/GitLab version/)
        expect(logger).to have_received(:info).with("\n#{Rainbow('Nodes').bright.yellow.underline}")
      end
    end

    context 'when displaying settings section' do
      it 'displays settings information' do
        service.execute

        expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Exact Code Search').bright.yellow.underline}")
        expect(logger).to have_received(:info).with(/GitLab version:.+/)
        expect(logger).to have_received(:info).with(/Enable indexing:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(/Enable searching:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(/Pause indexing:.+no/)
        expect(logger).to have_received(:info).with(/Index root namespaces automatically:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(
          /Offline nodes automatically deleted after:.+24h/
        )
        expect(logger).to have_received(:info).with(/Indexing CPU to tasks multiplier:.+1.5/)
      end
    end

    context 'when displaying nodes section with no nodes' do
      let(:options) { { extended_mode: true } }

      it 'displays empty node watermark levels' do
        # No nodes created, so counts should be zero
        service.execute

        expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Nodes').bright.yellow.underline}")
        expect(logger).to have_received(:info).with(
          /Node count:.+0 \(online: #{Rainbow('0').green}, offline: #{Rainbow('0').red}\)/
        )
        expect(logger).to have_received(:info).with(/Online node watermark levels:.+#{Rainbow('\(none\)').yellow}/)
      end
    end

    context 'when displaying nodes section with online nodes' do
      let(:options) { { extended_mode: true } }

      before do
        allow(Search::Zoekt::Index).to receive(:sum).with(:reserved_storage_bytes).and_return(8 * 1024 * 1024) # 8MB
      end

      it 'displays node information', :freeze_time do
        # Create nodes with different watermark levels using traits
        create(:zoekt_node, :for_search, :watermark_critical,
          metadata: { "name" => "node1" },
          schema_version: 1)
        create(:zoekt_node, :for_search, :watermark_high,
          metadata: { "name" => "node2" },
          schema_version: 2)
        create(:zoekt_node, :for_search, :watermark_low,
          metadata: { "name" => "node3" },
          schema_version: 1)
        create(:zoekt_node, :for_search, :watermark_normal,
          metadata: { "name" => "node4" },
          schema_version: 2)
        create(:zoekt_node, :for_search, :offline)

        service.execute

        expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Nodes').bright.yellow.underline}")
        # With the with_service(:zoekt) filter, the counts reflect only zoekt service nodes
        expect(logger).to have_received(:info).with(
          /Node count:.+5 \(online: #{Rainbow('4').green}, offline: #{Rainbow('1').red}\)/
        )
        # Test the new node watermark levels section
        expect(logger).to have_received(:info).with(/Online node watermark levels:.+4/)
        # Check for the individual watermark counts
        expect(logger).to have_received(:info).with(/  - critical: 1/)
        expect(logger).to have_received(:info).with(/  - high: 1/)
        expect(logger).to have_received(:info).with(/  - low: 1/)
        expect(logger).to have_received(:info).with(/  - normal: 1/)

        expect(logger).to have_received(:info).with(/Last seen at:.+#{current_time.utc}/).at_least(:once)
      end
    end

    context 'when displaying node details' do
      let(:options) { { extended_mode: true } }

      before do
        stub_const("Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD", 1.minute)

        # Mock number_to_human_size to return predictable output for testing
        allow(service).to receive(:number_to_human_size) do |bytes|
          if bytes >= 1_000_000_000_000 # 1 TB
            "#{(bytes.to_f / 1_000_000_000_000).round(2)} TB"
          elsif bytes >= 1_000_000_000 # 1 GB
            "#{(bytes.to_f / 1_000_000_000).round(1)} GB"
          elsif bytes >= 1_000_000 # 1 MB
            "#{(bytes.to_f / 1_000_000).round(1)} MB"
          elsif bytes >= 1_000 # 1 KB
            "#{(bytes.to_f / 1_000).round(1)} KB"
          else
            "#{bytes} Bytes"
          end
        end
      end

      it 'displays detailed information for each node' do
        travel_to(current_time) do
          # Create nodes with different watermark levels using traits
          node1 = create(:zoekt_node, :for_search, :watermark_critical,
            metadata: { 'name' => 'zoekt-node-01', 'version' => 'v1.2.1' },
            last_seen_at: current_time - 30.seconds,
            usable_storage_bytes: 75_000_000_000, # 75 GB
            indexed_bytes: 22_000_000_000, # 22 GB
            schema_version: 0)

          node2 = create(:zoekt_node, :for_search, :watermark_high,
            metadata: { 'name' => 'zoekt-node-02', 'version' => 'v1.2.2' },
            last_seen_at: current_time - 31.seconds,
            usable_storage_bytes: 81_000_000_000, # 81 GB
            indexed_bytes: 19_000_000_000, # 19 GB
            schema_version: 2401)

          node3 = create(:zoekt_node, :for_search, :watermark_low,
            metadata: { 'name' => 'zoekt-node-03', 'version' => 'v1.2.3' },
            last_seen_at: current_time - 32.seconds,
            usable_storage_bytes: 55_000_000_000, # 55 GB
            indexed_bytes: 45_000_000_000, # 45 GB
            schema_version: 2413)

          # This node is offline (last seen > 1 minute ago)
          node4 = create(:zoekt_node, :for_search, :watermark_normal,
            metadata: { 'name' => 'zoekt-node-04', 'version' => 'v1.2.5' },
            last_seen_at: current_time - 2.minutes,
            usable_storage_bytes: 30_000_000_000, # 30 GB
            indexed_bytes: 70_000_000_000, # 70 GB
            schema_version: 2450)

          service.execute

          # Verify Node Details header is displayed
          expect(logger).to have_received(:info).with("\n#{Rainbow('Node Details').bright.yellow.underline}")

          # Node 1 - Critical watermark, Online
          expect(logger).to have_received(:info).with(/Node #{node1.id} - zoekt-node-01/).at_least(:once)
          expect(logger).to have_received(:info).with(/  Status:.+#{Rainbow('Online').green}/).at_least(:once)
          expect(logger).to have_received(:info).with(/  Last seen at:.+#{(current_time - 30.seconds).utc}/)
          expect(logger).to have_received(:info).with(/  Disk utilization:.+/).at_least(:once)
          expect(logger).to have_received(:info).with(/  Zoekt version:.+v1.2.1/)
          expect(logger).to have_received(:info).with(/  Schema version:\s*0$/)

          # Node 2 - High watermark, Online
          expect(logger).to have_received(:info).with(/Node #{node2.id} - zoekt-node-02/).at_least(:once)
          expect(logger).to have_received(:info).with(/  Zoekt version:.+v1.2.2/)
          expect(logger).to have_received(:info).with(/  Schema version:\s*2401$/)

          # Node 3 - Low watermark, Online
          expect(logger).to have_received(:info).with(/Node #{node3.id} - zoekt-node-03/).at_least(:once)
          expect(logger).to have_received(:info).with(/  Zoekt version:.+v1.2.3/)
          expect(logger).to have_received(:info).with(/  Schema version:\s*2413$/)

          # Node 4 - Normal watermark, Offline
          expect(logger).to have_received(:info).with(/Node #{node4.id} - zoekt-node-04/).at_least(:once)
          expect(logger).to have_received(:info).with(/  Status:.+#{Rainbow('Offline').red}/)
          expect(logger).to have_received(:info).with(/  Last seen at:.+#{(current_time - 2.minutes).utc}/)
          expect(logger).to have_received(:info).with(/  Zoekt version:.+v1.2.5/)
          expect(logger).to have_received(:info).with(/  Schema version:\s*2450$/)
        end
      end
    end

    context 'when displaying process health section' do
      let(:options) { { extended_mode: true } }

      context 'when a node has no process health data (older indexer)' do
        it 'displays N/A for process health' do
          node = create(:zoekt_node, :for_search, metadata: { 'name' => 'node-1' })

          service.execute

          expect(logger).to have_received(:info).with("\n#{Rainbow('Process Health').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(%r{Node #{node.id} - node-1:.+N/A})
        end
      end

      context 'when a node has healthy process health data' do
        let(:process_health) do
          {
            'indexer' => {
              'mmap_current' => 1000,
              'mmap_max' => 65530,
              'restarts_1m' => 0,
              'restarts_5m' => 0,
              'restarts_15m' => 0,
              'rss_bytes' => 268435456,
              'uptime_seconds' => 3600
            },
            'webserver' => {
              'mmap_current' => 2000,
              'mmap_max' => 65530,
              'restarts_1m' => 0,
              'restarts_5m' => 0,
              'restarts_15m' => 0,
              'rss_bytes' => 536870912,
              'uptime_seconds' => 7200,
              'shards_loaded' => 10
            }
          }
        end

        it 'displays process health metrics for indexer and webserver', :freeze_time do
          node = create(:zoekt_node, :for_search,
            metadata: { 'name' => 'node-1', 'process_health' => process_health },
            webserver_last_seen_at: Time.zone.now)

          service.execute

          expect(logger).to have_received(:info).with("\n#{Rainbow('Process Health').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(/Node #{node.id} - node-1/).at_least(:once)
          expect(logger).to have_received(:info).with(/Indexer uptime/)
          expect(logger).to have_received(:info).with(/Indexer RSS memory/)
          expect(logger).to have_received(:info).with(/Indexer mmap/)
          expect(logger).to have_received(:info).with(/Indexer restarts/)
          expect(logger).to have_received(:info).with(/Webserver uptime/)
          expect(logger).to have_received(:info).with(/Webserver RSS memory/)
          expect(logger).to have_received(:info).with(/Webserver mmap/)
          expect(logger).to have_received(:info).with(/Webserver restarts/)
          expect(logger).to have_received(:info).with(/Webserver loaded shards/)
          expect(logger).to have_received(:info).with(/Webserver last reported/)
        end

        it 'formats uptime correctly' do
          create(:zoekt_node, :for_search,
            metadata: { 'name' => 'node-1', 'process_health' => process_health },
            webserver_last_seen_at: Time.zone.now)

          service.execute

          # 3600 seconds = 1h
          expect(logger).to have_received(:info).with(/Indexer uptime.+1h/)
          # 7200 seconds = 2h
          expect(logger).to have_received(:info).with(/Webserver uptime.+2h/)
        end
      end

      context 'when webserver process health is missing shards_loaded (older indexer)' do
        let(:webserver_metrics_without_shards) do
          {
            'mmap_current' => 2000,
            'mmap_max' => 65530,
            'restarts_1m' => 0,
            'restarts_5m' => 0,
            'restarts_15m' => 0,
            'rss_bytes' => 536870912,
            'uptime_seconds' => 7200
          }
        end

        it 'defaults the loaded shards row to N/A' do
          create(:zoekt_node, :for_search,
            metadata: {
              'name' => 'node-1',
              'process_health' => { 'webserver' => webserver_metrics_without_shards }
            },
            webserver_last_seen_at: Time.zone.now)

          service.execute

          expect(logger).to have_received(:info)
            .with(/Webserver loaded shards:\s+#{Regexp.escape(Rainbow('N/A').yellow)}\s*$/)
        end
      end

      context 'when formatting uptime values' do
        using RSpec::Parameterized::TableSyntax

        where(:uptime_seconds, :expected_uptime) do
          nil    | lazy { Rainbow('N/A').yellow }
          0      | '0m'
          59     | '0m'
          60     | '1m'
          3600   | '1h'
          3661   | '1h 1m'
          86400  | '1d'
          90061  | '1d 1h 1m'
          172800 | '2d'
        end

        with_them do
          it 'renders the indexer uptime through the process health output' do
            indexer_metrics = {
              'mmap_current' => 0,
              'mmap_max' => 0,
              'restarts_1m' => 0,
              'restarts_5m' => 0,
              'restarts_15m' => 0,
              'rss_bytes' => 0
            }
            # The JSON schema for node metadata rejects nil values, so omit the
            # key entirely to exercise the nil branch of format_uptime.
            indexer_metrics['uptime_seconds'] = uptime_seconds unless uptime_seconds.nil?

            create(:zoekt_node, :for_search,
              metadata: {
                'name' => 'node-1',
                'process_health' => { 'indexer' => indexer_metrics }
              })

            service.execute

            expect(logger).to have_received(:info).with(/Indexer uptime:\s+#{Regexp.escape(expected_uptime)}\s*$/)
          end
        end
      end

      context 'when formatting mmap values' do
        let(:base_indexer_metrics) do
          {
            'uptime_seconds' => 0,
            'restarts_1m' => 0,
            'restarts_5m' => 0,
            'restarts_15m' => 0,
            'rss_bytes' => 0
          }
        end

        def create_node_with_indexer_mmap(mmap_current, mmap_max)
          # The JSON schema for node metadata rejects nil values, so omit any
          # nil key entirely to exercise the nil branches of format_mmap.
          indexer_metrics = base_indexer_metrics.dup
          indexer_metrics['mmap_current'] = mmap_current unless mmap_current.nil?
          indexer_metrics['mmap_max'] = mmap_max unless mmap_max.nil?

          create(:zoekt_node, :for_search,
            metadata: {
              'name' => 'node-1',
              'process_health' => { 'indexer' => indexer_metrics }
            })
        end

        context 'when mmap_current is nil' do
          it 'renders N/A for the indexer mmap row' do
            create_node_with_indexer_mmap(nil, 65530)

            service.execute

            expect(logger).to have_received(:info)
              .with(%r{Indexer mmap \(current/max, %\):\s+#{Rainbow('N/A').yellow}})
          end
        end

        context 'when mmap_max is nil' do
          it 'renders N/A for the indexer mmap row' do
            create_node_with_indexer_mmap(1000, nil)

            service.execute

            expect(logger).to have_received(:info)
              .with(%r{Indexer mmap \(current/max, %\):\s+#{Rainbow('N/A').yellow}})
          end
        end

        context 'when mmap_max is 0' do
          it 'renders 0/0 with 0.0% usage and [OK] label' do
            create_node_with_indexer_mmap(0, 0)

            service.execute

            expect(logger).to have_received(:info)
              .with(%r{Indexer mmap \(current/max, %\):\s+0/0 \(.*0\.0%.*\) \[OK\]})
          end
        end

        context 'when mmap usage is below the warning threshold' do
          it 'renders the percentage in green with [OK] label' do
            create_node_with_indexer_mmap(1000, 65530)

            service.execute

            expect(logger).to have_received(:info)
              .with(%r{Indexer mmap.+1000/65530 \(#{Regexp.escape(Rainbow('1.5%').green)}\) \[OK\]})
          end
        end

        context 'when mmap usage is at the warning threshold' do
          it 'renders the percentage in yellow with [WARNING] label' do
            create_node_with_indexer_mmap(52424, 65530)

            service.execute

            expect(logger).to have_received(:info)
              .with(%r{Indexer mmap.+52424/65530 \(#{Regexp.escape(Rainbow('80.0%').yellow)}\) \[WARNING\]})
          end
        end

        context 'when mmap usage is at the critical threshold' do
          it 'renders the percentage in bright red with [CRITICAL] label' do
            create_node_with_indexer_mmap(62254, 65530)

            service.execute

            expect(logger).to have_received(:info)
              .with(%r{Indexer mmap.+62254/65530 \(#{Regexp.escape(Rainbow('95.0%').red.bright)}\) \[CRITICAL\]})
          end
        end
      end

      context 'when process health is not displayed in non-extended mode' do
        let(:options) { { extended_mode: false } }

        it 'does not display process health section' do
          create(:zoekt_node, :for_search, metadata: { 'name' => 'node-1' })

          service.execute

          expect(logger).not_to have_received(:info).with("\n#{Rainbow('Process Health').bright.yellow.underline}")
        end
      end
    end

    context 'when displaying indexing status' do
      before do
        allow(Group).to receive_message_chain(:top_level, :count).and_return(10)

        # Stub the direct counts that the info service accesses
        allow(Search::Zoekt::EnabledNamespace).to receive(:count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:with_missing_indices, :count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:search_disabled, :count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:with_missing_indices, :with_rollout_blocked,
          :count).and_return(0)
      end

      context 'with no data' do
        before do
          replica_group_relation = instance_double(ActiveRecord::Relation, count: {})
          index_group_relation = instance_double(ActiveRecord::Relation, count: {})
          index_watermark_group = instance_double(ActiveRecord::Relation, count: {})
          repository_group_relation = instance_double(ActiveRecord::Relation, count: {})
          task_group_relation = instance_double(ActiveRecord::Relation, count: {})
          task_type_group_relation = instance_double(ActiveRecord::Relation, count: {})
          pending_tasks_relation = instance_double(ActiveRecord::Relation)

          allow(Search::Zoekt::Replica).to receive(:group).with(:state).and_return(replica_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:state).and_return(index_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:watermark_level)
                                     .and_return(index_watermark_group)
          allow(Search::Zoekt::Repository).to receive(:group).with(:state).and_return(repository_group_relation)
          allow(Search::Zoekt::Task).to receive(:group).with(:state).and_return(task_group_relation)
          allow(Search::Zoekt::Task).to receive(:pending_or_processing).and_return(pending_tasks_relation)
          allow(pending_tasks_relation).to receive(:group).with(:task_type).and_return(task_type_group_relation)
        end

        it 'displays zero counts with (none)' do
          service.execute

          expect(logger).to have_received(:info).ordered.with("\n#{Rainbow('Indexing status').bright.yellow.underline}")

          # Verify the new Group count information is displayed
          expect(logger).to have_received(:info).with(/Group count:.+10/)

          namespace_msg = /EnabledNamespace count:.+0 \(without indices: #{Rainbow('0').red}, /
          namespace_msg_part2 = /rollout blocked: #{Rainbow('0').red}, with search disabled: #{Rainbow('0').yellow}\)/
          expect(logger).to have_received(:info).with(namespace_msg)
          expect(logger).to have_received(:info).with(namespace_msg_part2)

          expect(logger).to have_received(:info).with(/Replicas count:.+\(none\)/)
          expect(logger).to have_received(:info).with(/Indices count:.+\(none\)/)
          expect(logger).to have_received(:info).with(/Repositories count:.+\(none\)/)
        end
      end

      context 'with data' do
        before do
          # Create stubs for all the necessary group/count combinations
          replica_group_relation = instance_double(ActiveRecord::Relation, count: { 'ready' => 2, 'pending' => 1 })
          index_group_relation = instance_double(ActiveRecord::Relation, count: { 'ready' => 2, 'pending' => 1 })
          index_watermark_group = instance_double(ActiveRecord::Relation, count: { 'ok' => 2, 'warning' => 1 })
          repository_group_relation = instance_double(ActiveRecord::Relation, count: { 'ready' => 2, 'orphaned' => 1 })
          task_group_relation = instance_double(ActiveRecord::Relation,
            count: { 'done' => 2, 'failed' => 1, 'pending' => 1 })
          task_type_relation = instance_double(ActiveRecord::Relation,
            count: { 'update_repository' => 1, 'delete_repository' => 1 })
          pending_tasks_relation = instance_double(ActiveRecord::Relation)

          # Override the default stubs with ones that show actual data
          allow(Search::Zoekt::EnabledNamespace).to receive(:count).and_return(10)
          allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:with_missing_indices, :count).and_return(5)
          allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:search_disabled, :count).and_return(2)
          allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:with_missing_indices, :with_rollout_blocked,
            :count).and_return(3)

          allow(Search::Zoekt::Replica).to receive(:group).with(:state).and_return(replica_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:state).and_return(index_group_relation)
          allow(Search::Zoekt::Index).to receive(:group).with(:watermark_level)
                                     .and_return(index_watermark_group)
          allow(Search::Zoekt::Repository).to receive(:group).with(:state).and_return(repository_group_relation)
          allow(Search::Zoekt::Task).to receive(:group).with(:state).and_return(task_group_relation)
          allow(Search::Zoekt::Task).to receive(:pending_or_processing).and_return(pending_tasks_relation)
          allow(pending_tasks_relation).to receive(:group).with(:task_type).and_return(task_type_relation)
        end

        it 'displays counts with state breakdowns' do
          service.execute

          expect(logger).to have_received(:info).with("\n#{Rainbow('Indexing status').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(/Group count:.+10/)

          # Test that the EnabledNamespace count shows rollout blocked namespaces
          namespace_msg = /EnabledNamespace count:.+10 \(without indices: #{Rainbow('5').red}, /
          namespace_msg_part2 = /rollout blocked: #{Rainbow('3').red}, with search disabled: #{Rainbow('2').yellow}\)/
          expect(logger).to have_received(:info).with(namespace_msg)
          expect(logger).to have_received(:info).with(namespace_msg_part2)

          expect(logger).to have_received(:info).with(/Replicas count:.+3/)
        end
      end
    end

    context 'when displaying the storage buffer factor' do
      before do
        allow(Group).to receive_message_chain(:top_level, :count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace).to receive(:count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:with_missing_indices, :count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace).to receive_message_chain(:search_disabled, :count).and_return(0)
        allow(Search::Zoekt::EnabledNamespace)
          .to receive_message_chain(:with_missing_indices, :with_rollout_blocked, :count).and_return(0)
        allow(Search::Zoekt::Replica).to receive(:group).with(:state)
          .and_return(instance_double(ActiveRecord::Relation, count: {}))
        allow(Search::Zoekt::Index).to receive(:group).with(:state)
          .and_return(instance_double(ActiveRecord::Relation, count: {}))
        allow(Search::Zoekt::Index).to receive(:group).with(:watermark_level)
          .and_return(instance_double(ActiveRecord::Relation, count: {}))
        allow(Search::Zoekt::Repository).to receive(:group).with(:state)
          .and_return(instance_double(ActiveRecord::Relation, count: {}))
        pending_tasks = instance_double(ActiveRecord::Relation)
        allow(Search::Zoekt::Task).to receive(:group).with(:state)
          .and_return(instance_double(ActiveRecord::Relation, count: {}))
        allow(Search::Zoekt::Task).to receive(:pending_or_processing).and_return(pending_tasks)
        allow(pending_tasks).to receive(:group).with(:task_type)
          .and_return(instance_double(ActiveRecord::Relation, count: {}))
      end

      context 'when the dynamic factor is below default' do
        before do
          allow(Search::Zoekt::Index).to receive(:global_buffer_factor).and_return(0.6)
        end

        it 'shows the dynamic factor in green' do
          service.execute

          expect(logger).to have_received(:info)
            .with(/Storage buffer factor:\s+#{Rainbow('0.6×').green}\s+\[dynamic \(observed\)\]/)
        end
      end

      context 'when the dynamic factor equals the default' do
        before do
          allow(Search::Zoekt::Index).to receive(:global_buffer_factor)
            .and_return(Search::Zoekt::Index::DEFAULT_BUFFER_FACTOR)
        end

        it 'shows the dynamic factor in yellow' do
          service.execute

          expect(logger).to have_received(:info)
            .with(/Storage buffer factor:\s+#{Rainbow('3.0×').yellow}\s+\[dynamic \(observed\)\]/)
        end
      end

      context 'when the dynamic factor is above the default' do
        before do
          allow(Search::Zoekt::Index).to receive(:global_buffer_factor).and_return(9.0)
        end

        it 'shows the dynamic factor in yellow' do
          service.execute

          expect(logger).to have_received(:info)
            .with(/Storage buffer factor:\s+#{Rainbow('9.0×').yellow}\s+\[dynamic \(observed\)\]/)
        end
      end
    end

    context 'when displaying feature flags section' do
      before do
        allow(Feature).to receive(:persisted_names).and_return(['zoekt_custom_flag'])

        zoekt_flag = instance_double(Feature::Definition, to_s: 'zoekt_default_flag')

        # Combine all Feature::Definition stubs
        allow(Feature::Definition).to receive_messages(
          definitions: { 'zoekt_default_flag' => zoekt_flag },
          has_definition?: false
        )

        # Set up specific has_definition? calls that override the default
        allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_custom_flag).and_return(true)
        allow(Feature::Definition).to receive(:has_definition?).with('zoekt_custom_flag').and_return(true)
        allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_default_flag).and_return(true)
        allow(Feature::Definition).to receive(:has_definition?).with('zoekt_default_flag').and_return(true)

        allow(Feature).to receive(:persisted_name?).with('zoekt_default_flag').and_return(false)
        allow(Feature).to receive(:enabled?).with('zoekt_custom_flag', nil).and_return(true)
        allow(Feature).to receive(:enabled?).with('zoekt_default_flag', nil).and_return(false)
      end

      it 'displays custom feature flags section' do
        service.execute

        header_text = "\n#{Rainbow('Feature Flags (Non-Default Values)').bright.yellow.underline}"
        expect(logger).to have_received(:info).with(header_text)
      end

      it 'displays default feature flags section' do
        service.execute

        header_text = "\n#{Rainbow('Feature Flags (Default Values)').bright.yellow.underline}"
        expect(logger).to have_received(:info).with(header_text)
      end

      context 'with no feature flags' do
        before do
          allow(Feature).to receive_messages(
            persisted_names: [],
            persisted_name?: false,
            enabled?: false
          )
          allow(Feature::Definition).to receive_messages(
            definitions: {},
            has_definition?: false
          )
        end

        it 'displays empty feature flags sections' do
          service.execute

          # Expect header for non-default values section
          non_default_header = "\n#{Rainbow('Feature Flags (Non-Default Values)').bright.yellow.underline}"
          expect(logger).to have_received(:info).with(non_default_header)

          # Expect header for default values section
          default_header = "\n#{Rainbow('Feature Flags (Default Values)').bright.yellow.underline}"
          expect(logger).to have_received(:info).with(default_header)

          # Check for the 'none' message without specifying exactly how many times
          expect(logger).to have_received(:info).with(/Feature flags:.+#{Rainbow('none').yellow}/).at_least(:once)
        end
      end

      context 'with feature flags without YAML definitions' do
        before do
          allow(Feature).to receive(:persisted_names).and_return(%w[zoekt_custom_flag zoekt_undefined_flag])

          # Set up has_definition? to return appropriate values for both string and symbol keys
          allow(Feature::Definition).to receive(:has_definition?).and_return(false)
          allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_custom_flag).and_return(true)
          allow(Feature::Definition).to receive(:has_definition?).with('zoekt_custom_flag').and_return(true)
          allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_undefined_flag).and_return(false)
          allow(Feature::Definition).to receive(:has_definition?).with('zoekt_undefined_flag').and_return(false)
          allow(Feature::Definition).to receive(:has_definition?).with(:zoekt_default_flag).and_return(true)
          allow(Feature::Definition).to receive(:has_definition?).with('zoekt_default_flag').and_return(true)

          # We should never call enabled? on the undefined flag
          allow(Feature).to receive(:enabled?).with('zoekt_undefined_flag', nil)
            .and_raise('This should not be called')
        end

        it 'displays flags without definitions as "no definition"' do
          service.execute

          # The flag with no definition should show up in the output
          expect(logger).to have_received(:info).with(/- zoekt_undefined_flag:.+#{Rainbow('no definition').yellow}/)

          # The regular flag should still work
          expect(logger).to have_received(:info).with(/- zoekt_custom_flag:.+#{Rainbow('enabled').green}/)
        end
      end
    end
  end
end
