# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Helper, :request_store, feature_category: :global_search do
  subject(:helper) { described_class.default }

  shared_context 'with a legacy index' do
    let(:the_index_name) { helper.target_name }

    before do
      helper.create_empty_index(with_alias: false, options: { index_name: the_index_name })
    end

    after do
      helper.delete_index(index_name: the_index_name)
    end
  end

  shared_context 'with an existing index and alias' do
    before do
      helper.create_empty_index(with_alias: true)
    end

    after do
      helper.delete_index(index_name: helper.target_index_name)
    end
  end

  describe '.new' do
    it 'has the proper default values' do
      expect(helper).to have_attributes(
        version: ::Elastic::MultiVersionUtil::TARGET_VERSION,
        target_name: ::Elastic::Latest::Config.index_name)
    end

    context 'with a custom `index_name`' do
      let(:index_name) { 'custom-index-name' }

      subject(:helper) { described_class.new(target_name: index_name) }

      it 'has the proper `index_name`' do
        expect(helper).to have_attributes(target_name: index_name)
      end
    end
  end

  describe '.default' do
    it 'does not cache the value' do
      expect(described_class.default.object_id).not_to eq(described_class.default.object_id)
    end
  end

  describe '.connection_settings' do
    it 'returns a hash compatible with elasticsearch-transport client settings' do
      settings = described_class.connection_settings(uri: "http://localhost:9200")

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        path: "",
        port: 9200
      })
    end

    it 'works when given a URI' do
      settings = described_class.connection_settings(uri: Addressable::URI.parse("http://localhost:9200"))

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        path: "",
        port: 9200
      })
    end

    it 'parses credentials out of the uri' do
      settings = described_class.connection_settings(uri: "http://elastic:myp%40ssword@localhost:9200")

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        user: "elastic",
        password: "myp@ssword",
        path: "",
        port: 9200
      })
    end

    it 'prioritizes creds in arguments over those in url' do
      settings = described_class
        .connection_settings(uri: "http://elastic:password@localhost:9200", user: "myuser", password: "p@ssword")

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        user: "myuser",
        password: "p@ssword",
        path: "",
        port: 9200
      })
    end

    it 'sets password to empty string when only username is provided' do
      settings = described_class.connection_settings(uri: "http://localhost:9200", user: "myuser", password: nil)

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        user: "myuser",
        password: "",
        path: "",
        port: 9200
      })
    end
  end

  describe '.`url_string`' do
    it 'returns a percent encoded url string' do
      settings = {
        scheme: "http",
        host: "localhost",
        user: "myuser",
        password: "p@ssword",
        path: "/foo",
        port: 9200
      }

      expect(described_class.url_string(settings)).to eq("http://myuser:p%40ssword@localhost:9200/foo")
    end
  end

  describe '#default_mappings' do
    it 'returns only mappings of the main index' do
      expected = Elastic::Latest::Config.mappings.to_hash[:properties].keys

      expect(helper.default_mappings[:properties].keys).to match_array(expected)
    end

    context 'with custom analyzers' do
      let(:custom_analyzers_mappings) do
        { properties: { title: { fields: { custom: true } } } }
      end

      before do
        allow(::Elastic::Latest::CustomLanguageAnalyzers).to receive(:custom_analyzers_mappings)
          .and_return(custom_analyzers_mappings)
      end

      it 'merges custom language analyzers mappings' do
        expect(helper.default_mappings[:properties][:title]).to include(custom_analyzers_mappings[:properties][:title])
      end
    end
  end

  describe '#index_name_with_timestamp', time_travel_to: '2022-01-02 10:30:45 -0700' do
    subject { helper.index_name_with_timestamp('gitlab-production') }

    it 'returns correct index name' do
      is_expected.to eq('gitlab-production-20220102-1730')
    end

    it 'supports name_suffix' do
      expect(helper.index_name_with_timestamp('gitlab-production', suffix: '-reindex')).to eq(
        'gitlab-production-20220102-1730-reindex'
      )
    end
  end

  describe '#create_migrations_index' do
    before do
      helper.delete_migrations_index
    end

    after do
      helper.delete_migrations_index
    end

    it 'creates the index with alias pattern', :aggregate_failures do
      expect { helper.create_migrations_index }
        .to change { helper.migrations_index_exists? }
              .from(false).to(true)

      # Verify alias exists
      expect(helper.alias_exists?(name: helper.migrations_index_name)).to be true

      # Verify physical index exists behind the alias
      alias_info = helper.get_alias_info(helper.migrations_index_name)
      expect(alias_info).not_to be_empty
      physical_index = alias_info.each_key.first
      expect(physical_index).to match(/#{helper.migrations_index_name}-\d{8}-\d{4}/)
    end

    context 'when migrations index already exists with alias' do
      before do
        helper.create_migrations_index
      end

      it 'raises an error when trying to recreate' do
        expect(helper.migrations_index_exists?).to be true

        alias_info_before = helper.get_alias_info(helper.migrations_index_name)
        physical_index_before = alias_info_before.each_key.first

        expect { helper.create_migrations_index }.to raise_error(RuntimeError, /Index under.*already exists/)

        expect(helper.migrations_index_exists?).to be true
        alias_info_after = helper.get_alias_info(helper.migrations_index_name)
        physical_index_after = alias_info_after.each_key.first
        expect(physical_index_after).to eq(physical_index_before)
      end
    end
  end

  describe '#create_standalone_indices' do
    it 'creates standalone indices' do
      delete_all_standalone_indices

      aggregate_changes = helper.standalone_indices_proxies.map do |proxy|
        change { helper.index_exists?(index_name: proxy.index_name) }.from(false).to(true)
      end

      expect(::Search::ClusterHealthCheck::IndexValidationService).to receive(:execute)
        .with(target_classes: nil).and_call_original

      expect { helper.create_standalone_indices }.to aggregate_changes.reduce(&:and)

      delete_all_standalone_indices
    end

    context 'when target_classes are provided' do
      it 'creates standalone indices' do
        delete_all_standalone_indices

        proxy = helper.standalone_indices_proxies.first

        expect(::Search::ClusterHealthCheck::IndexValidationService)
          .to receive(:execute).with(target_classes: [proxy.target])

        expect { helper.create_standalone_indices(target_classes: [proxy.target]) }
          .to change { helper.index_exists?(index_name: proxy.index_name) }.from(false).to(true)

        delete_all_standalone_indices
      end
    end

    context 'when indices already exist' do
      before do
        allow(helper).to receive(:index_exists?).and_return(true)
      end

      it 'raises an exception when there is an existing alias' do
        expect { helper.create_standalone_indices }.to raise_error(/already exists/)
      end

      it 'does not raise an exception with skip_if_exists option' do
        expect { helper.create_standalone_indices(options: { skip_if_exists: true }) }.not_to raise_error
      end

      it 'raises an exception when there is an existing index' do
        expect { helper.create_standalone_indices(with_alias: false) }.to raise_error(/already exists/)
      end
    end
  end

  describe '#delete_standalone_indices' do
    before_all do
      delete_all_standalone_indices

      described_class.default.create_standalone_indices
    end

    it 'removes all standalone indices' do
      aggregate_changes = helper.standalone_indices_proxies.map do |proxy|
        change { helper.index_exists?(index_name: proxy.index_name) }.from(true).to(false)
      end

      expect { helper.delete_standalone_indices }.to aggregate_changes.reduce(&:and)
    end
  end

  describe '#delete_migrations_index' do
    before do
      # avoid flakiness
      helper.create_migrations_index unless helper.migrations_index_exists?
    end

    it 'deletes the migrations index' do
      expect { helper.delete_migrations_index }
        .to change { helper.migrations_index_exists? }
              .from(true).to(false)
    end
  end

  describe '#create_empty_index' do
    context 'with an empty cluster' do
      it 'calls the index validation service' do
        helper.delete_index(index_name: helper.target_name) if helper.index_exists?(index_name: helper.target_name)

        expect(::Search::ClusterHealthCheck::IndexValidationService).to receive(:execute)
          .with(target_classes: [Repository]).once.and_call_original

        helper.create_empty_index(with_alias: true)

        helper.delete_index(index_name: helper.target_name)
      end

      context 'with alias and index' do
        include_context 'with an existing index and alias'

        it 'creates index and alias' do
          expect(helper.index_exists?).to be(true)
          expect(helper.alias_exists?).to be(true)
        end
      end

      context 'when there is a legacy index' do
        include_context 'with a legacy index'

        it 'creates the index only' do
          expect(helper.index_exists?).to be(true)
          expect(helper.alias_exists?).to be(false)
        end
      end

      context 'with a custom index name' do
        let(:index_name) { 'test-custom-index-name' }

        it 'creates an index with a custom name' do
          # prevent flakiness
          helper.delete_index(index_name: index_name) if helper.index_exists?(index_name: index_name)
          helper.create_empty_index(with_alias: false, options: { index_name: index_name })

          expect(helper.index_exists?(index_name: index_name)).to be(true)
          expect(helper.index_exists?).to be(false)

          helper.delete_index(index_name: index_name)
        end
      end

      context 'with non-default number of shards' do
        include_context 'with an existing index and alias'

        let_it_be(:number_of_shards) { 7 }

        before_all do
          Elastic::IndexSetting.default.update!(number_of_shards: number_of_shards)
        end

        it 'creates an index with correct number of shards' do
          settings = helper.get_settings(index_name: helper.target_name)
          expect(settings['number_of_shards'].to_i).to eq(number_of_shards)
        end
      end
    end

    context 'when the index exists' do
      before do
        allow(helper).to receive(:index_exists?).with(index_name: 'test-name').and_return(true)
      end

      it 'raises an error' do
        options = { index_name: 'test-name' }
        expect { helper.create_empty_index(options: options) }.to raise_error(/Index under '.+' already exists/)
      end

      it 'does not raise error with skip_if_exists option' do
        options = { index_name: 'test-name', skip_if_exists: true }
        expect { helper.create_empty_index(options: options) }.not_to raise_error
      end
    end

    context 'when the index does not exist, but the alias exists' do
      before do
        allow(helper).to receive(:index_exists?).and_return(false)
        allow(helper).to receive(:index_exists?).with(index_name: helper.target_name).and_return(true)
      end

      it 'raises an error' do
        expect { helper.create_empty_index }.to raise_error(/Index or alias under '.+' already exists/)
      end

      it 'does not raise error with skip_if_exists option' do
        options = { index_name: 'test-name', skip_if_exists: true }
        expect { helper.create_empty_index(options: options) }.not_to raise_error
      end
    end
  end

  describe '#delete_index' do
    subject { helper.delete_index }

    context 'without an existing index' do
      it 'fails gracefully' do
        is_expected.to be_falsy
      end
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_truthy }
    end
  end

  describe '#index_exists?' do
    subject { helper.index_exists? }

    context 'without an existing index' do
      it { is_expected.to be_falsy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_truthy }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end
  end

  describe '#migrations_index_exists?', :elastic do
    before do
      helper.delete_migrations_index
    end

    subject { helper.migrations_index_exists? }

    context 'without an existing migrations index' do
      it { is_expected.to be_falsy }
    end

    context 'when it exists' do
      before do
        helper.create_migrations_index
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#alias_exists?' do
    subject { helper.alias_exists? }

    context 'without an existing index' do
      it { is_expected.to be_falsy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_falsy }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end
  end

  describe '#alias_missing?' do
    it 'is the opposite of #alias_exists?' do
      expect(helper.alias_missing?).to eq(!helper.alias_exists?)
    end
  end

  describe '#cluster_free_size_bytes' do
    it 'returns valid cluster size' do
      expect(helper.cluster_free_size_bytes).to be_positive
    end
  end

  describe '#nodes_settings' do
    let(:node_response) do
      {
        'nodes' => {
          'node1' => { 'settings' => { 'cluster.remote_store.index.restrict.async-durability' => 'true' } }
        }
      }
    end

    before do
      allow(helper.client.nodes).to receive(:info)
        .with(metric: 'settings', flat_settings: true)
        .and_return(node_response)
    end

    it 'returns a hash of nodes keyed by node id' do
      result = helper.nodes_settings
      expect(result).to be_a(Hash)
      expect(result).not_to be_empty
      expect(result.each_value.first).to include('settings')
    end

    it 'returns flat settings' do
      result = helper.nodes_settings
      node_settings = result.each_value.first['settings']
      expect(node_settings).to be_a(Hash)
      expect(node_settings.keys).to all(be_a(String))
    end

    it 'returns an empty hash when a transport error occurs' do
      allow(helper.client.nodes).to receive(:info)
        .and_raise(Elasticsearch::Transport::Transport::Errors::Forbidden)
      expect(helper.nodes_settings).to eq({})
    end
  end

  describe '#switch_alias' do
    include_context 'with an existing index and alias'

    let(:new_index_name) { 'test-switch-alias' }

    it 'switches the alias' do
      old_index_name = helper.target_index_name
      helper.create_empty_index(with_alias: false, options: { index_name: new_index_name })

      expect { helper.switch_alias(to: new_index_name) }
        .to change { helper.target_index_name }.to(new_index_name)

      helper.delete_index(index_name: new_index_name)
      helper.delete_index(index_name: old_index_name) # cleanup to not pollute tests
    end

    context 'when creating a new alias without removing from an existing index' do
      let(:new_alias_name) { 'test-new-alias' }
      let(:new_index_name) { 'test-new-index' }

      before do
        helper.create_empty_index(with_alias: false, options: { index_name: new_index_name })
      end

      after do
        helper.delete_index(index_name: new_index_name)
      end

      it 'creates the alias when from is nil' do
        expect(helper.alias_exists?(name: new_alias_name)).to be false

        helper.switch_alias(from: nil, to: new_index_name, alias_name: new_alias_name)

        expect(helper.alias_exists?(name: new_alias_name)).to be true
        alias_info = helper.get_alias_info(new_alias_name)
        expect(alias_info.keys).to include(new_index_name)
      end
    end
  end

  describe '#index_size' do
    subject { helper.index_size }

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to have_key("docs") }
      it { is_expected.to have_key("store") }
    end

    context 'when there is an alias', :aggregate_failures do
      include_context 'with an existing index and alias'

      it { is_expected.to have_key("docs") }
      it { is_expected.to have_key("store") }

      it 'supports providing the alias name' do
        alias_name = helper.target_name

        expect(helper.index_size(index_name: alias_name)).to have_key("docs")
        expect(helper.index_size(index_name: alias_name)).to have_key("store")
      end
    end
  end

  describe '#documents_count' do
    context 'when refresh is unset' do
      subject { helper.documents_count }

      context 'when there is a legacy index' do
        include_context 'with a legacy index'

        it { is_expected.to eq(0) }
      end

      context 'when there is an alias' do
        include_context 'with an existing index and alias'

        it { is_expected.to eq(0) }

        it 'supports providing the alias name' do
          alias_name = helper.target_name

          expect(helper.documents_count(index_name: alias_name)).to eq(0)
        end
      end
    end

    context 'when refresh is set' do
      subject(:count) { helper.documents_count(refresh: true) }

      it 'refreshes the index' do
        expect(helper).to receive(:refresh_index)

        count
      end
    end
  end

  describe '#delete_migration_record', :elastic do
    let(:migration) { ::Elastic::DataMigrationService.migrations.last }

    subject { helper.delete_migration_record(migration) }

    context 'when record exists' do
      it { is_expected.to be_truthy }
    end

    context 'when record does not exist' do
      before do
        allow(migration).to receive(:version).and_return(1)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#standalone_indices_proxies' do
    subject(:standalone_indices_proxies) do
      helper.standalone_indices_proxies(target_classes: target_classes, exclude_classes: exclude_classes)
    end

    let(:target_classes) { nil }
    let(:exclude_classes) { nil }

    context 'when target_classes and exclude_classes are not provided' do
      it 'creates proxies for each separate class' do
        expect(standalone_indices_proxies.count).to eq(described_class::ES_SEPARATE_CLASSES.count)
      end
    end

    context 'when exclude_classes is provided' do
      let(:exclude_classes) { [Epic, Wiki, Vulnerability, Vulnerabilities::Read, Sbom::OccurrenceRef] }

      it 'creates proxies for each separate classes except exclude_classes' do
        expected = described_class::ES_SEPARATE_CLASSES - exclude_classes
        expect(standalone_indices_proxies.map(&:target)).to match_array(expected)
      end
    end

    context 'when target_classes is provided' do
      let(:target_classes) { [WorkItem] }

      it 'creates proxies for only the target classes' do
        expect(standalone_indices_proxies.count).to eq(1)
      end
    end

    context 'when a proxy has ready? method' do
      # rubocop:disable RSpec/VerifiedDoubles -- testing dynamic ready? method added at runtime to some proxies
      let(:ready_proxy) { double('ReadyProxy', ready?: true, target: 'ReadyTarget') }
      let(:not_ready_proxy) { double('NotReadyProxy', ready?: false, target: 'NotReadyTarget') }
      let(:no_ready_method_proxy) { double('NoReadyProxy', target: 'NoReadyTarget') }
      # rubocop:enable RSpec/VerifiedDoubles

      before do
        stub_const("#{described_class}::ES_SEPARATE_CLASSES", %w[ReadyClass NotReadyClass NoReadyClass])

        # Mock type_class to return our test proxies
        allow(described_class).to receive(:type_class) do |class_name|
          case class_name
          when 'ReadyClass'
            ready_proxy
          when 'NotReadyClass'
            not_ready_proxy
          when 'NoReadyClass'
            no_ready_method_proxy
          end
        end
      end

      it 'filters out proxies where ready? returns false' do
        proxies = helper.standalone_indices_proxies

        expect(proxies).to include(ready_proxy)
        expect(proxies).not_to include(not_ready_proxy)
        expect(proxies).to include(no_ready_method_proxy)
      end
    end

    context 'with foreign keys mappings', :aggregate_failures do
      let(:ignore_columns) do
        {
          id: [Issue, Commit, Epic],
          project_id: [Issue],
          author_id: [Issue, Epic],
          assignee_id: [Issue],
          hashed_root_namespace_id: :all,
          work_item_type_id: [Issue],
          cluster_agent_id: [Vulnerability, Vulnerabilities::Read],
          scanner_external_id: [Vulnerability, Vulnerabilities::Read]
        }.with_indifferent_access
      end

      # document mapping type must match database column type
      # see https://docs.gitlab.com/ee/development/advanced_search.html#create-the-index
      it 'has correct foreign key types' do
        standalone_indices_proxies.each do |proxy|
          mappings = proxy.mappings.to_hash.with_indifferent_access

          mappings['properties'].select { |k, _| k =~ /(^id$)|(_id$)/ }.each do |key, value|
            index_target = if proxy.respond_to?(:target)
                             proxy.target
                           else
                             proxy.name.delete_prefix('Search::Elastic::Types::').constantize
                           end

            next if ignore_columns[key] == :all || ignore_columns[key]&.include?(index_target)

            expect([:long, 'long']).to include(value[:type]), "#{index_target}.#{key} is not a long"
          end
        end
      end
    end
  end

  describe '#ping?' do
    it 'does not raise any exception' do
      allow(described_class.default.client).to receive(:ping).and_raise(StandardError)

      expect(helper.ping?).to be_falsey
      expect { helper.ping? }.not_to raise_exception
    end
  end

  describe '#get_meta', :elastic do
    subject { helper.get_meta }

    it 'returns version in meta field' do
      is_expected.to include('created_by' => Gitlab::VERSION)
    end
  end

  describe '#server_info' do
    context 'with cached information' do
      it 'uses the correct cache key' do
        expected_key = [
          described_class.name,
          :server_info,
          OpenSSL::Digest::SHA256.hexdigest(::Gitlab::CurrentSettings.elasticsearch_url.join(','))
        ]
        expect(Rails.cache).to receive(:fetch).with(expected_key,
          expires_in: described_class::SERVER_INFO_EXPIRES_IN).and_call_original
        helper.server_info
      end
    end

    context 'without cached information' do
      subject { helper.server_info(skip_cache: true) }

      context 'when server is accessible' do
        before do
          allow(described_class.default.client).to receive(:info).and_return(info)
        end

        context 'when using elasticsearch' do
          let(:info) do
            {
              'version' => {
                'number' => '7.9.3',
                'build_type' => 'docker',
                'lucene_version' => '8.11.4'
              }
            }
          end

          it 'returns server info' do
            is_expected.to include(distribution: 'elasticsearch', version: '7.9.3',
              build_flavor: nil, build_type: 'docker', lucene_version: '8.11.4')
          end
        end

        context 'when using elasticsearch serverless' do
          let(:info) do
            {
              'version' => {
                'number' => '8.11.0',
                'build_flavor' => 'serverless',
                'build_type' => 'docker',
                'lucene_version' => '9.7.0'
              }
            }
          end

          it 'returns server info with build_flavor' do
            is_expected.to include(distribution: 'elasticsearch', version: '8.11.0',
              build_flavor: 'serverless', build_type: 'docker', lucene_version: '9.7.0')
          end
        end

        context 'when using opensearch' do
          let(:info) do
            {
              'version' => {
                'distribution' => 'opensearch',
                'number' => '1.0.0',
                'build_type' => 'tar',
                'lucene_version' => '8.10.1'
              }
            }
          end

          it 'returns server info' do
            is_expected.to include(distribution: 'opensearch', version: '1.0.0',
              build_flavor: nil, build_type: 'tar', lucene_version: '8.10.1')
          end
        end
      end

      context 'when server is inaccessible' do
        before do
          allow(described_class.default.client).to receive(:info).and_raise(StandardError)
        end

        it 'returns empty hash' do
          is_expected.to eq({})
        end
      end
    end
  end

  describe '#serverless?' do
    subject { helper.serverless? }

    context 'when using elasticsearch serverless' do
      before do
        allow(helper).to receive(:server_info).and_return(
          { distribution: 'elasticsearch', build_flavor: 'serverless' }
        )
      end

      it { is_expected.to be true }
    end

    context 'when using elasticsearch' do
      before do
        allow(helper).to receive(:server_info).and_return(
          { distribution: 'elasticsearch', build_flavor: nil }
        )
      end

      it { is_expected.to be false }
    end

    context 'when using opensearch' do
      before do
        allow(helper).to receive(:server_info).and_return(
          { distribution: 'opensearch', build_flavor: nil }
        )
      end

      it { is_expected.to be false }
    end
  end

  describe '#get_mapping' do
    let(:index_name) { Issue.__elasticsearch__.index_name }

    subject { helper.get_mapping(index_name: index_name) }

    it 'reads mappings from client', :elastic do
      is_expected.not_to be_nil
    end
  end

  describe '#supported_version?' do
    subject { helper.supported_version? }

    context 'when Elasticsearch is not enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it { is_expected.to be_truthy }
    end

    context 'when Elasticsearch is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        allow(described_class.default.client).to receive(:ping).and_return(true)
      end

      context 'when version is compatible' do
        before do
          allow_next_instance_of(::SystemCheck::App::SearchCheck) do |instance|
            allow(instance).to receive(:check?).and_return(true)
          end
        end

        it { is_expected.to be_truthy }
      end

      context 'when version is incompatible' do
        before do
          allow_next_instance_of(::SystemCheck::App::SearchCheck) do |instance|
            allow(instance).to receive(:check?).and_return(false)
          end
        end

        it { is_expected.to be_falsey }
      end

      context 'when Elasticsearch is unreachable' do
        before do
          allow(described_class.default.client).to receive(:ping).and_raise(StandardError)
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#unsupported_version?' do
    using RSpec::Parameterized::TableSyntax

    subject { helper.unsupported_version? }

    where(:distribution, :version, :result) do
      'elasticsearch' | '6.8.23' | true
      'elasticsearch' | '7.17.0' | false
      'elasticsearch' | '8.0.0'  | false
      'opensearch'    | '1.3.3'  | false
      'opensearch'    | '2.1.0'  | false
    end

    before do
      allow(helper).to receive(:server_info).and_return(distribution: distribution, version: version)
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#vectors_supported?' do
    using RSpec::Parameterized::TableSyntax

    subject { helper.vectors_supported?(distribution.to_sym) }

    where(:distribution, :version, :result) do
      'elasticsearch' | '6.8.23' | false
      'elasticsearch' | '7.17.0' | false
      'elasticsearch' | '8.0.0'  | true
      'opensearch'    | '1.3.3'  | true
      'opensearch'    | '2.1.0'  | true
    end

    before do
      allow(helper).to receive(:server_info).and_return(distribution: distribution, version: version)
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#matching_distribution?' do
    let(:server_info) { {} }

    before do
      allow(helper).to receive(:server_info).and_return(server_info)
    end

    context 'when server_info is empty' do
      it 'returns false' do
        expect(helper.matching_distribution?(:elasticsearch)).to be false
      end
    end

    context 'when distribution does not match' do
      let(:server_info) { { distribution: 'opensearch', version: '1.0.0' } }

      it 'returns false' do
        expect(helper.matching_distribution?(:elasticsearch)).to be false
      end
    end

    context 'when distribution matches' do
      let(:server_info) { { distribution: 'elasticsearch', version: '7.10.0' } }

      context 'and no minimum version is specified' do
        it 'returns true' do
          expect(helper.matching_distribution?(:elasticsearch)).to be true
        end
      end

      context 'and minimum version is specified' do
        it 'returns true when version meets minimum' do
          expect(helper.matching_distribution?(:elasticsearch, min_version: '7.9.0')).to be true
        end

        it 'returns false when version does not meet minimum' do
          expect(helper.matching_distribution?(:elasticsearch, min_version: '7.11.0')).to be false
        end

        it 'returns true when version exactly matches minimum' do
          expect(helper.matching_distribution?(:elasticsearch, min_version: '7.10.0')).to be true
        end
      end
    end

    context 'when checking OpenSearch distribution' do
      let(:server_info) { { distribution: 'opensearch', version: '1.2.3' } }

      it 'returns true for matching distribution' do
        expect(helper.matching_distribution?(:opensearch)).to be true
      end

      it 'returns true when version meets minimum' do
        expect(helper.matching_distribution?(:opensearch, min_version: '1.0.0')).to be true
      end

      it 'returns false when version does not meet minimum' do
        expect(helper.matching_distribution?(:opensearch, min_version: '2.0.0')).to be false
      end
    end
  end

  describe '#klass_to_alias_name' do
    it 'returns results for every listed class' do
      scoped_classes = [Vulnerabilities::Read, Sbom::OccurrenceRef]
      (described_class::ES_SEPARATE_CLASSES - scoped_classes).each do |klass|
        expect(helper.klass_to_alias_name(klass: klass)).to eq(
          [Rails.application.class.module_parent_name.downcase, Rails.env, klass.name.underscore.pluralize].join('-')
        )
      end
    end

    it 'returns results for repository' do
      expect(helper.klass_to_alias_name(klass: Repository)).to eq(Repository.__elasticsearch__.index_name)
    end

    it 'returns results for Vulnerabilities::Read' do
      expect(helper.klass_to_alias_name(klass: Vulnerabilities::Read)).to eq(
        [Rails.application.class.module_parent_name.downcase, Rails.env, "vulnerability_reads"].join('-')
      )
    end

    it 'returns results for Sbom::OccurrenceRef' do
      expect(helper.klass_to_alias_name(klass: Sbom::OccurrenceRef)).to eq(
        [Rails.application.class.module_parent_name.downcase, Rails.env, "sbom_occurrence_refs"].join('-')
      )
    end
  end

  describe '#pending_migrations?' do
    it 'returns true when there are pending migrations' do
      allow(::Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(true)
      expect(helper).to be_pending_migrations
    end

    it 'returns false when there are no pending migrations' do
      allow(::Elastic::DataMigrationService).to receive(:pending_migrations?).and_return(false)
      expect(helper).not_to be_pending_migrations
    end
  end

  describe '#indexing_paused?' do
    it 'delegates to Gitlab::CurrentSettings.advanced_search_indexing_paused?' do
      allow(::Gitlab::CurrentSettings)
        .to receive(:advanced_search_indexing_paused?)
        .and_return(:stubbed_value)

      expect(helper.indexing_paused?).to eq(::Gitlab::CurrentSettings.advanced_search_indexing_paused?)
    end
  end

  describe '#refresh_index', :elastic do
    subject(:refresh_index) { helper.refresh_index(index_name: index_name) }

    context 'when index_name is not provided' do
      let(:index_name) { nil }

      it 'refreshes all indexes' do
        expected_count = helper.standalone_indices_proxies.count + 1 # add the main index
        expect(helper.client.indices).to receive(:refresh).exactly(expected_count).times

        refresh_index
      end
    end

    context 'when index_name is provided' do
      let(:index_name) { 'gitlab-test-work_items' }

      it 'refreshes a single index' do
        expect(helper.client.indices).to receive(:refresh).with(index: index_name)

        refresh_index
      end
    end

    context 'when an index does not exist' do
      let(:index_name) { 'non-existing-index' }

      it 'does not refresh the index' do
        expect(helper.client.indices).not_to receive(:refresh)

        refresh_index
      end
    end
  end

  describe '#reindex' do
    let(:from) { :from }
    let(:slice) { :slice }
    let(:max_slice) { :max_slice }
    let(:to) { :to }
    let(:wait_for_completion) { :wait_for_completion }
    let(:scroll) { '3h' }
    let(:result) { { 'task' => '8675-309' } }

    it 'passes correct arguments to Search::ReindexingService' do
      expect(::Search::ReindexingService).to receive(:execute).with(
        from: from, to: to, slice: slice, max_slices: max_slice,
        wait_for_completion: wait_for_completion, scroll: scroll
      ).and_return(result)

      expect(helper.reindex(from: from, to: to, slice: slice, max_slice: max_slice,
        wait_for_completion: wait_for_completion, scroll: scroll)).to eq(result['task'])
    end
  end

  describe '.build_es_id' do
    it 'returns a calculated es_id' do
      expect(described_class.build_es_id(es_type: 'project', target_id: 123)).to eq('project_123')
    end
  end

  describe '#remove_wikis_from_the_standalone_index' do
    include ElasticsearchHelpers

    context 'when container_type is other than Group or Project' do
      it 'not calls delete_by_query' do
        expect(helper.client).not_to receive(:delete_by_query)
        helper.remove_wikis_from_the_standalone_index(1, 'Random')
      end
    end

    context 'when container_type is either Project or Group' do
      let(:body) do
        { query: { bool: { filter: { term: { rid: rid } } } } }
      end

      let(:index) { Elastic::Latest::WikiConfig.index_name }

      context 'when namespace_routing_id is passed' do
        let(:container_id) { 1 }
        let(:container_type) { 'Group' }
        let(:namespace_routing_id) { 0 }
        let(:rid) { "wiki_#{container_type.downcase}_#{container_id}" }

        it 'calls delete_by_query with passed namespace_routing_id as routing' do
          expect(helper.client).to receive(:delete_by_query)
            .with({ body: body, index: index, conflicts: 'proceed', routing: "n_#{namespace_routing_id}" })
          helper.remove_wikis_from_the_standalone_index(container_id, container_type, namespace_routing_id)
        end
      end

      context 'when namespace_routing_id is not passed' do
        let(:container_id) { 1 }
        let(:container_type) { 'Project' }
        let(:rid) { "wiki_#{container_type.downcase}_#{container_id}" }

        it 'calls delete_by_query without routing' do
          expect(helper.client).to receive(:delete_by_query).with({ body: body, index: index, conflicts: 'proceed' })
          helper.remove_wikis_from_the_standalone_index(container_id, container_type)
        end
      end
    end
  end

  describe '#target_index_names' do
    let(:target_index) { nil }

    subject(:target_index_names) { helper.target_index_names(target: target_index) }

    context 'when alias exists' do
      before do
        allow(helper).to receive(:alias_exists?).and_return(true)
        allow(helper.client.indices).to receive(:get_alias).and_return(aliases)
      end

      context 'when a nil target is provided' do
        let(:aliases) do
          {
            "gitlab-test-20231129-200242-0002" => { "aliases" => { "gitlab-test" => { "is_write_index" => true } } },
            "gitlab-test-20231129-200242" => { "aliases" => { "gitlab-test" => { "is_write_index" => false } } }
          }
        end

        let(:index_regex) { /\Agitlab-test-[\d-]+\z/ }

        it 'uses the default target from target_name' do
          expect(target_index_names.keys).to contain_exactly(index_regex, index_regex)
          expect(target_index_names.values).to contain_exactly(true, false)
        end
      end

      context 'when a target is provided' do
        let(:aliases) do
          {
            "gitlab-test-projects-20231129-0002" =>
              { "aliases" => { "gitlab-test-projects" => { "is_write_index" => true } } },
            "gitlab-test-projects-20231129" =>
              { "aliases" => { "gitlab-test-projects" => { "is_write_index" => false } } }
          }
        end

        let(:target_index) { "gitlab-test-projects" }
        let(:index_regex) { /\Agitlab-test-projects-[\d-]+\z/ }

        it 'uses the target index' do
          expect(target_index_names.keys).to contain_exactly(index_regex, index_regex)
          expect(target_index_names.values).to contain_exactly(true, false)
        end
      end

      context 'when write index is not set' do
        let(:aliases) do
          {
            "gitlab-test-20231129-200242" => { "aliases" => { "gitlab-test" => {} } }
          }
        end

        let(:index_regex) { /\Agitlab-test-[\d-]+\z/ }

        it 'returns the write index as true' do
          expect(target_index_names.keys).to contain_exactly(index_regex)
          expect(target_index_names.values).to contain_exactly(true)
        end
      end
    end

    context 'when alias does not exist' do
      before do
        allow(helper).to receive(:alias_exists?).and_return(false)
      end

      it 'returns a hash with a single key value pair' do
        expect(helper.target_index_names(target: nil)).to match({ 'gitlab-test' => true })
      end
    end
  end

  private

  def delete_all_standalone_indices
    hlpr = described_class.default

    hlpr.standalone_indices_proxies.each do |proxy|
      hlpr.client.cat.indices(index: "#{proxy.index_name}*", format: 'json').each do |index|
        hlpr.client.indices.delete(index: index['index'])
      end
    end
  end
end
