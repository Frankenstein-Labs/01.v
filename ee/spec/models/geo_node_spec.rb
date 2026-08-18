# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GeoNode, :request_store, :geo, type: :model, feature_category: :geo_replication do
  using RSpec::Parameterized::TableSyntax
  include ::EE::GeoHelpers

  let(:dummy_url) { 'https://localhost:3000/gitlab' }
  let(:new_node_attrs) { { url: dummy_url } }
  let(:new_node) { build(:geo_node, new_node_attrs) }
  let(:new_primary_node) { build(:geo_node, :primary, new_node_attrs) }
  let(:empty_node) { described_class.new }
  let(:primary_node) { create(:geo_node, :primary) }
  let(:node) { create(:geo_node) }

  let(:url_helpers) { Gitlab::Routing.url_helpers }
  let(:api_version) { API::API.version }

  context 'associations' do
    it { is_expected.to belong_to(:oauth_application).class_name('Authn::OauthApplication').dependent(:destroy).autosave(true) }

    it { is_expected.to have_many(:geo_node_namespace_links) }
    it { is_expected.to have_many(:namespaces).through(:geo_node_namespace_links) }
    it { is_expected.to have_many(:geo_node_organization_links) }
    it { is_expected.to have_many(:organizations).through(:geo_node_organization_links).class_name('Organizations::Organization') }
  end

  it_behaves_like 'encrypted attribute', :secret_access_key, :db_key_base_32 do
    let(:record) { node }
  end

  context 'validations' do
    subject { build(:geo_node) }

    it { is_expected.to validate_inclusion_of(:selective_sync_type).in_array(GeoNode::SELECTIVE_SYNC_TYPES).allow_nil }
    it { is_expected.to validate_numericality_of(:repos_max_capacity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:files_max_capacity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:verification_max_capacity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:container_repositories_max_capacity).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:minimum_reverification_interval).is_greater_than_or_equal_to(1) }
    it { is_expected.to validate_numericality_of(:blob_download_timeout).is_greater_than_or_equal_to(1).is_less_than_or_equal_to(86400) }
    it { is_expected.to validate_numericality_of(:checksum_mismatch_report_threshold).is_greater_than_or_equal_to(1) }
    it { is_expected.to validate_numericality_of(:checksum_mismatch_self_heal_cooldown_minutes).is_greater_than_or_equal_to(1) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }

    context 'when checking SELECTIVE_SYNC_TYPES constant' do
      it 'has expected sync types' do
        expect(GeoNode::SELECTIVE_SYNC_TYPES).to match_array(%w[namespaces shards organizations])
      end
    end

    context 'when validating primary node' do
      it 'cannot be disabled' do
        primary_node.enabled = false

        expect(primary_node).not_to be_valid
        expect(primary_node.errors).to include(:enabled)
      end
    end

    context 'when validating url' do
      subject { build(:geo_node, url: url) }

      context 'when url is http' do
        let(:url) { 'http://foo' }

        it { is_expected.to be_valid }
      end

      context 'when url is https' do
        let(:url) { 'https://foo' }

        it { is_expected.to be_valid }
      end

      context 'when url is not http or https' do
        let(:url) { 'nothttp://foo' }

        it { is_expected.not_to be_valid }
      end

      context 'when an existing GeoNode has the same url but different name' do
        let(:new_node) { create(:geo_node, new_node_attrs) }
        let!(:existing) { new_node }
        let(:url) { new_node.url }

        it { is_expected.to be_valid }
      end
    end

    context 'when validating internal_url' do
      subject { build(:geo_node, internal_url: internal_url) }

      context 'when internal_url is http' do
        let(:internal_url) { 'http://foo' }

        it { is_expected.to be_valid }
      end

      context 'when internal_url is https' do
        let(:internal_url) { 'https://foo' }

        it { is_expected.to be_valid }
      end

      context 'when internal_url is not http or https' do
        let(:internal_url) { 'nothttp://foo' }

        it { is_expected.not_to be_valid }
      end
    end

    context 'when validating requirement for hashed storage' do
      subject { build(:geo_node) }

      context 'when hashed storage is enabled' do
        it { is_expected.to be_valid }
      end

      context 'when hashed_storage is disabled' do
        before do
          stub_application_setting(hashed_storage_enabled: false)
        end

        it { is_expected.to be_invalid }
      end
    end

    context 'when outbound request filtering is enabled' do
      before do
        stub_application_setting(deny_all_requests_except_allowed: true)
        stub_application_setting(allow_local_requests_from_web_hooks_and_services: false)
      end

      context 'with external url' do
        subject { build(:geo_node, url: 'https://geo-secondary.example.com') }

        it { is_expected.to be_valid }
      end

      context 'with localhost url' do
        subject { build(:geo_node, url: 'http://127.0.0.1:3001') }

        it { is_expected.to be_valid }
      end

      context 'with internal_url' do
        subject { build(:geo_node, url: 'https://geo.example.com', internal_url: 'https://geo-internal.example.com') }

        it { is_expected.to be_valid }
      end

      context 'with localhost internal_url' do
        subject { build(:geo_node, url: 'http://localhost:3000', internal_url: 'http://127.0.0.1:3001') }

        it { is_expected.to be_valid }
      end

      context 'with invalid scheme' do
        subject { build(:geo_node, url: 'ftp://geo-secondary.example.com') }

        it { is_expected.not_to be_valid }
      end

      context 'with invalid scheme on internal_url' do
        subject { build(:geo_node, url: 'https://geo.example.com', internal_url: 'ftp://geo-internal.example.com') }

        it { is_expected.not_to be_valid }
      end
    end
  end

  context 'default values' do
    where(:attribute, :value) do
      :repos_max_capacity                  | 10
      :files_max_capacity                  | 10
      :container_repositories_max_capacity | 2
      :sync_object_storage                 | false
    end

    with_them do
      it { expect(empty_node[attribute]).to eq(value) }
    end
  end

  context 'prevent locking yourself out' do
    it 'does not accept adding a non primary node with same details as current_node' do
      stub_geo_setting(node_name: 'foo')
      node = build(:geo_node, primary: false, name: 'foo')

      expect(node).not_to be_valid
      expect(node.errors.full_messages.count).to eq(1)
      expect(node.errors[:base].first).to match('locking yourself out')
    end
  end

  context 'dependent models and attributes for GeoNode' do
    context 'when validating' do
      context 'when it is a secondary node' do
        before do
          node
        end

        context 'when the oauth_application is missing' do
          before do
            node.oauth_application.destroy!
            node.oauth_application = nil
          end

          it 'builds an oauth_application' do
            expect(node).to be_valid

            expect(node.oauth_application).to be_present
            expect(node.oauth_application).to have_attributes(
              confidential: true,
              trusted: true,
              redirect_uri: node.oauth_callback_url
            )
            expect(node.oauth_application.organization_id).to be_present
          end
        end

        it 'overwrites name, and redirect_uri attributes' do
          node.oauth_application.name = 'Fake App'
          node.oauth_application.confidential = false
          node.oauth_application.trusted = false
          node.oauth_application.redirect_uri = 'http://wrong-callback-url'
          node.oauth_application.save!

          expect(node).to be_valid
          expect(node.oauth_application).to have_attributes(
            name: "Geo node: #{node.url}",
            confidential: false,
            trusted: false,
            redirect_uri: node.oauth_callback_url
          )
        end
      end

      context 'when it is a primary node' do
        before do
          primary_node
        end

        context 'when it does not have an oauth_application' do
          it 'does not create an oauth_application' do
            primary_node.oauth_application = nil

            expect(primary_node).to be_valid

            expect(primary_node.oauth_application).to be_nil
          end
        end

        context 'when it has an oauth_application' do
          it 'destroys the oauth_application' do
            primary_node.oauth_application = create(:oauth_application)

            expect do
              expect(primary_node).to be_valid
            end.to change { Authn::OauthApplication.count }.by(-1)

            expect(primary_node.oauth_application).to be_nil
          end
        end

        context 'when clone_url_prefix is nil' do
          it 'sets current clone_url_prefix' do
            primary_node.clone_url_prefix = nil

            expect(primary_node).to be_valid

            expect(primary_node.clone_url_prefix).to eq(Gitlab.config.gitlab_shell.ssh_path_prefix)
          end
        end

        context 'when clone_url_prefix has changed' do
          it 'sets current clone_url_prefix' do
            primary_node.clone_url_prefix = 'foo'

            expect(primary_node).to be_valid

            expect(primary_node.clone_url_prefix).to eq(Gitlab.config.gitlab_shell.ssh_path_prefix)
          end
        end
      end
    end

    context 'when saving' do
      let(:oauth_application) { node.oauth_application }

      context 'when url is changed' do
        it "updates the associated OAuth application's redirect_uri" do
          node.update!(url: 'http://modified-url')

          expect(oauth_application.reload.redirect_uri).to eq('http://modified-url/oauth/geo/callback')
        end
      end
    end
  end

  context 'cache invalidation' do
    context 'when a transaction commits successfully' do
      it 'invalidates the cache after create', :aggregate_failures do
        expect(Gitlab::Geo.primary_node_url).to be_nil

        new_primary = create(:geo_node, :primary)

        expect(Gitlab::Geo.primary_node_url).to eq(new_primary.url)
      end

      it 'invalidates the cache after update', :aggregate_failures do
        primary = create(:geo_node, :primary)
        original_url = primary.url

        expect(Gitlab::Geo.primary_node_url).to eq(original_url)

        primary.update!(url: 'http://updated-primary.example.com/gitlab')

        expect(Gitlab::Geo.primary_node_url).to eq(primary.url)
      end

      it 'invalidates the cache after destroy', :aggregate_failures do
        primary = create(:geo_node, :primary)

        expect(Gitlab::Geo.primary_node_url).to eq(primary.url)

        primary.destroy!

        expect(Gitlab::Geo.primary_node_url).to be_nil
      end
    end

    context 'when a transaction is rolled back' do
      it 'does not invalidate the cache so the original attribute value is returned after rollback', :aggregate_failures do
        primary = create(:geo_node, :primary)
        original_url = primary.url

        expect(Gitlab::Geo.primary_node_url).to eq(original_url)

        described_class.transaction do
          primary.update!(url: 'http://rolled-back.example.com/gitlab')
          expect(Gitlab::Geo.primary_node_url).to eq(original_url)
          raise ActiveRecord::Rollback
        end

        expect(Gitlab::Geo.primary_node_url).to eq(original_url)
      end
    end
  end

  describe '.primary_node' do
    before do
      create(:geo_node)
    end

    it 'returns the primary' do
      primary = create(:geo_node, :primary)

      expect(described_class.primary_node).to eq(primary)
    end

    it 'returns nil if there is no primary' do
      expect(described_class.primary_node).to be_nil
    end
  end

  describe '.secondary_nodes' do
    before do
      create(:geo_node, :primary)
    end

    it 'returns all secondary nodes' do
      secondaries = create_list(:geo_node, 2)

      expect(described_class.secondary_nodes).to match_array(secondaries)
    end

    it 'returns empty array if there are not any secondary nodes' do
      expect(described_class.secondary_nodes).to be_empty
    end
  end

  describe '.unhealthy_nodes' do
    before do
      create(:geo_node_status, :healthy)
    end

    subject(:unhealthy_nodes) { described_class.unhealthy_nodes }

    it 'returns a node without status' do
      geo_node = create(:geo_node)

      expect(unhealthy_nodes).to contain_exactly(geo_node)
    end

    it 'returns a node not having a cursor last event id' do
      geo_node_status = create(:geo_node_status, :healthy, cursor_last_event_id: nil)

      expect(unhealthy_nodes).to contain_exactly(geo_node_status.geo_node)
    end

    it 'returns a node with missing status check timestamp' do
      geo_node_status = create(:geo_node_status, :healthy, last_successful_status_check_at: nil)

      expect(unhealthy_nodes).to contain_exactly(geo_node_status.geo_node)
    end

    it 'returns a node with an old status check timestamp' do
      geo_node_status = create(:geo_node_status, :healthy, last_successful_status_check_at: 61.minutes.ago)

      expect(unhealthy_nodes).to contain_exactly(geo_node_status.geo_node)
    end
  end

  describe '.min_cursor_last_event_id' do
    it 'returns the minimum of cursor_last_event_id across all nodes' do
      create(:geo_node_status, cursor_last_event_id: 10)
      create(:geo_node_status, cursor_last_event_id: 8)

      expect(described_class.min_cursor_last_event_id).to eq(8)
    end
  end

  describe '.find_by_oauth_application_id' do
    context 'when the Geo node exists' do
      it 'returns the Geo node' do
        found = described_class.find_by_oauth_application_id(node.oauth_application_id)

        expect(found).to eq(node)
      end
    end

    context 'when the Geo node does not exist' do
      it 'returns nil' do
        found = described_class.find_by_oauth_application_id(-1)

        expect(found).to be_nil
      end
    end
  end

  describe '#repair' do
    it 'creates an oauth application for a Geo secondary node' do
      stub_current_geo_node(node)
      node.update_attribute(:oauth_application, nil)

      node.repair

      expect(node.oauth_application).to be_present
    end

    it 'creates an oauth application with organization_id set' do
      stub_current_geo_node(node)
      node.update_attribute(:oauth_application, nil)

      node.repair

      expect(node.oauth_application.organization_id).to be_present
    end
  end

  describe '#update_oauth_application!' do
    context 'for secondary nodes' do
      it 'sets organization_id when creating oauth application' do
        secondary_node = build(:geo_node, :secondary)
        secondary_node.save!

        expect(secondary_node.oauth_application.organization_id).to be_present
      end

      it 'always sets organization_id to the default organization ID because the application is instance level' do
        secondary_node = create(:geo_node, :secondary)
        original_organization_id = secondary_node.oauth_application.organization_id

        secondary_node.oauth_application.destroy!

        expect(secondary_node.oauth_application.organization_id).to eq(original_organization_id)
      end
    end

    context 'for primary nodes' do
      it 'does not create an oauth application' do
        primary = create(:geo_node, :primary)

        expect(primary.oauth_application).to be_nil
      end
    end
  end

  describe '.current?' do
    it 'returns true when node is the current node' do
      node = described_class.new(name: described_class.current_node_name)

      expect(described_class.current?(node)).to be_truthy
    end

    it 'returns false when node is not the current node' do
      node = described_class.new(name: 'some other node')

      expect(described_class.current?(node)).to be_falsy
    end

    it 'returns true when node.name has an extra a slash and matches URL' do
      allow(described_class).to receive(:current_node_name).and_return('http://example.com')
      node = described_class.new(name: 'http://example.com/', url: 'http://example.com/')

      expect(described_class.current?(node)).to be_truthy
    end

    it 'returns true when node.name is missing a slash and matches URL' do
      allow(described_class).to receive(:current_node_name).and_return('http://example.com/')
      node = described_class.new(name: 'http://example.com', url: 'http://example.com/')

      expect(described_class.current?(node)).to be_truthy
    end

    it 'returns false when node.name is not a url even if missing a slash' do
      allow(described_class).to receive(:current_node_name).and_return('blip/')
      node = described_class.new(name: 'blip')

      expect(described_class.current?(node)).to be_falsy
    end
  end

  describe '.current_node' do
    context 'when table does not have name column' do
      before do
        allow(described_class).to receive(:column_names).and_return([])
      end

      it 'returns nil' do
        expect(described_class.current_node).to be_nil
      end
    end

    context 'when node with exact name exists' do
      it 'returns the node' do
        allow(described_class).to receive(:current_node_name).and_return(primary_node.name)

        expect(described_class.current_node).to eq(primary_node)
      end

      it 'returns the node with exact matching name even if one with a similar name exists' do
        node = create(:geo_node, name: 'http://example.com')
        create(:geo_node, name: 'http://example.com/')

        allow(described_class).to receive_messages(current_node_name: 'http://example.com', current_node_url: 'http://example.com/')

        expect(described_class.current_node).to eq(node)
      end
    end

    context "when node with exact name does not exists" do
      let(:name_no_slash) { 'http://example.com' }
      let(:name_with_slash) { 'http://example.com/' }

      before do
        allow(described_class).to receive_messages(current_node_name:, current_node_url:)
      end

      where(current_node_url: %w[http://example.com http://example.com/])

      with_them do
        context "when a record missing a slash exists" do
          let(:current_node_name) { name_with_slash }

          it 'returns the expected node' do
            expected_node = create(:geo_node, name: name_no_slash)

            expect(described_class.current_node).to eq expected_node
          end
        end

        context "when a record with an extra a slash exists" do
          let(:current_node_name) { name_no_slash }

          it 'returns the expected node' do
            expected_node = create(:geo_node, name: name_with_slash)

            expect(described_class.current_node).to eq expected_node
          end
        end

        context "when no record exists" do
          let(:current_node_name) { 'fantasy name' }

          it 'returns nil' do
            expect(described_class.current_node).to be_nil
          end
        end
      end
    end
  end

  describe '#uri' do
    context 'when url is set' do
      it 'returns an URI object' do
        expect(new_node.uri).to be_a URI
      end

      it 'includes schema, host, port and relative_url_root with a terminating /' do
        expected_uri = URI.parse(dummy_url)
        expected_uri.path += '/'
        expect(new_node.uri).to eq(expected_uri)
      end
    end

    context 'when url is not yet set' do
      it 'returns nil' do
        expect(empty_node.uri).to be_nil
      end
    end
  end

  describe '#url' do
    it 'returns a string' do
      expect(new_node.url).to be_a String
    end

    it 'includes schema home port and relative_url with a terminating /' do
      expected_url = 'https://localhost:3000/gitlab/'
      expect(new_node.url).to eq(expected_url)
    end
  end

  describe '#url=' do
    subject { new_node }

    it 'sets schema field based on url' do
      expect(subject.uri.scheme).to eq('https')
    end

    it 'sets host field based on url' do
      expect(subject.uri.host).to eq('localhost')
    end

    it 'sets port field based on specified by url' do
      expect(subject.uri.port).to eq(3000)
    end

    context 'when using unspecified ports' do
      let(:dummy_http) { 'http://example.com/' }
      let(:dummy_https) { 'https://example.com/' }

      context 'when schema is http' do
        it 'sets port 80' do
          subject.url = dummy_http

          expect(subject.uri.port).to eq(80)
        end
      end

      context 'when schema is https' do
        it 'sets port 443' do
          subject.url = dummy_https

          expect(subject.uri.port).to eq(443)
        end
      end
    end
  end

  describe '#internal_url' do
    let(:internal_url) { 'https://foo:3003/bar' }
    let(:node) { build(:geo_node, url: dummy_url, internal_url: internal_url) }

    it 'returns a string' do
      expect(node.internal_url).to be_a String
    end

    it 'includes schema home port and relative_url with a terminating /' do
      expect(node.internal_url).to eq("#{internal_url}/")
    end

    it 'falls back to url' do
      empty_node.url = dummy_url
      empty_node.internal_url = nil

      expect(empty_node.internal_url).to eq "#{dummy_url}/"
    end

    it 'resets internal_url if it matches #url' do
      empty_node.url = dummy_url
      empty_node.internal_url = dummy_url

      expect(empty_node.attributes[:internal_url]).to be_nil
    end
  end

  describe '#internal_url=' do
    subject { described_class.new(internal_url: 'https://foo:3003/bar') }

    it 'sets schema field based on url' do
      expect(subject.internal_uri.scheme).to eq('https')
    end

    it 'sets host field based on url' do
      expect(subject.internal_uri.host).to eq('foo')
    end

    it 'sets port field based on specified by url' do
      expect(subject.internal_uri.port).to eq(3003)
    end

    context 'when using unspecified ports' do
      let(:dummy_http) { 'http://example.com/' }
      let(:dummy_https) { 'https://example.com/' }

      context 'when schema is http' do
        it 'sets port 80' do
          subject.internal_url = dummy_http

          expect(subject.internal_uri.port).to eq(80)
        end
      end

      context 'when schema is https' do
        it 'sets port 443' do
          subject.internal_url = dummy_https

          expect(subject.internal_uri.port).to eq(443)
        end
      end
    end
  end

  describe '#omniauth_host_url' do
    it 'returns a string' do
      expect(new_node.omniauth_host_url).to be_a String
    end

    it 'is the URL without the trailing slash' do
      expect("#{new_node.omniauth_host_url}/").to eq(new_node.url)
    end

    it 'includes schema home port and relative_url without a terminating /' do
      expected_url = 'https://localhost:3000/gitlab'
      expect(new_node.omniauth_host_url).to eq(expected_url)
    end
  end

  describe '#geo_retrieve_url' do
    let(:retrieve_url) { "https://localhost:3000/gitlab/api/#{api_version}/geo/retrieve/package_file/1" }

    it 'returns api url based on node uri' do
      expect(new_node.geo_retrieve_url(replicable_name: :package_file, replicable_id: 1)).to eq(retrieve_url)
    end
  end

  describe '#geo_status_url' do
    let(:status_url) { "https://localhost:3000/gitlab/api/#{api_version}/geo/status" }

    it 'returns api url based on node uri' do
      expect(new_node.status_url).to eq(status_url)
    end
  end

  describe '#node_api_url' do
    let(:new_node) { create(:geo_node, new_node_attrs) }

    it 'returns an api url based on the node uri and provided node id' do
      expect(new_primary_node.node_api_url(new_node)).to eq("https://localhost:3000/gitlab/api/#{api_version}/geo_nodes/#{new_node.id}")
    end
  end

  describe '#graphql_url' do
    it 'returns an api url to the graphql endpoint' do
      expect(new_primary_node.graphql_url).to eq("https://localhost:3000/gitlab/api/#{api_version}/geo/graphql")
    end
  end

  describe '#snapshot_url' do
    let_it_be(:project) { create(:project) }
    let(:snapshot_url) { "https://localhost:3000/gitlab/api/#{api_version}/projects/#{project.id}/snapshot" }

    it 'returns snapshot URL based on node URI' do
      expect(new_node.snapshot_url(project.repository)).to eq(snapshot_url)
    end

    it 'adds ?wiki=1 to the snapshot URL when the repository is a wiki' do
      expect(new_node.snapshot_url(project.wiki.repository)).to eq(snapshot_url + "?wiki=1")
    end
  end

  describe '#find_or_build_status' do
    let(:new_node) { create(:geo_node, new_node_attrs) }

    it 'returns a new status' do
      status = new_node.find_or_build_status

      expect(status).to be_a(GeoNodeStatus)

      status.save!

      expect(new_node.find_or_build_status).to eq(status)
    end
  end

  describe '#oauth_callback_url' do
    let(:oauth_callback_url) { 'https://localhost:3000/gitlab/oauth/geo/callback' }

    it 'returns oauth callback url based on node uri' do
      expect(new_node.oauth_callback_url).to eq(oauth_callback_url)
    end

    it 'returns url that matches rails url_helpers generated one' do
      route = url_helpers.oauth_geo_callback_url(protocol: 'https:', host: 'localhost', port: 3000, script_name: '/gitlab')
      expect(new_node.oauth_callback_url).to eq(route)
    end
  end

  describe '#oauth_logout_url' do
    let(:fake_state) { CGI.escape('fakestate') }
    let(:oauth_logout_url) { "https://localhost:3000/gitlab/oauth/geo/logout?state=#{fake_state}" }

    it 'returns oauth logout url based on node uri' do
      expect(new_node.oauth_logout_url(fake_state)).to eq(oauth_logout_url)
    end

    it 'returns url that matches rails url_helpers generated one' do
      route = url_helpers.oauth_geo_logout_url(protocol: 'https:', host: 'localhost', port: 3000, script_name: '/gitlab', state: fake_state)
      expect(new_node.oauth_logout_url(fake_state)).to eq(route)
    end
  end

  describe '#geo_replication_details_url' do
    let(:new_node) { build_stubbed(:geo_node, new_node_attrs) }
    let(:primary_node) { build(:geo_node, :primary) }

    before do
      allow(Gitlab::Geo).to receive(:replication_enabled_replicator_classes).and_return(
        instance_double("Array", first: class_double("Gitlab::Geo::Replicator", replicable_name_plural: 'replicables'))
      )
    end

    it 'returns the Geo Replicables url for the specific node' do
      expected_url = "https://localhost:3000/gitlab/admin/geo/sites/#{new_node.id}/replication/replicables"

      expect(new_node.geo_replication_details_url).to eq(expected_url)
    end

    it 'returns nil when node is a primary one' do
      expect(primary_node.geo_replication_details_url).to be_nil
    end
  end

  describe '#missing_oauth_application?' do
    context 'on a primary node' do
      it 'returns false' do
        expect(primary_node).not_to be_missing_oauth_application
      end
    end

    it 'returns false when present' do
      expect(node).not_to be_missing_oauth_application
    end

    it 'returns true when it is not present' do
      node.oauth_application.destroy!
      node.reload
      expect(node).to be_missing_oauth_application
    end
  end

  describe '#selective_sync?' do
    subject(:selective_sync?) { node.selective_sync? }

    it 'returns true when selective sync is by namespaces' do
      node.update!(selective_sync_type: 'namespaces')

      is_expected.to be_truthy
    end

    it 'returns true when selective sync is by shards' do
      node.update!(selective_sync_type: 'shards')

      is_expected.to be_truthy
    end

    it 'returns true when selective sync is by organizations' do
      node.update!(selective_sync_type: 'organizations')

      is_expected.to be_truthy
    end

    it 'returns false when selective sync is disabled' do
      node.update!(
        selective_sync_type: '',
        namespaces: [create(:group)],
        selective_sync_shards: ['default']
      )

      is_expected.to be_falsy
    end

    it 'returns false when selective_sync_type is nil' do
      node.update!(selective_sync_type: nil)

      is_expected.to be_falsy
    end

    it 'raises when selective_sync_type is invalid' do
      node.selective_sync_type = 'invalid_type'

      expect { selective_sync? }.to raise_error(Geo::Errors::UnknownSelectiveSyncType, /Selective sync type is not known: invalid_type/)
    end

    it 'returns false when the feature flag is disabled for organizations' do
      stub_feature_flags(geo_selective_sync_by_organizations: false)
      node.update!(selective_sync_type: 'organizations')

      is_expected.to be_falsy
    end
  end

  describe '#selective_sync_by_organizations?' do
    subject(:selective_sync_by_organizations?) { node.selective_sync_by_organizations? }

    context 'when selective_sync_type is organizations' do
      before do
        node.update!(selective_sync_type: 'organizations')
      end

      it 'returns true' do
        is_expected.to be_truthy
      end
    end

    context 'when selective_sync_type is namespaces' do
      before do
        node.update!(selective_sync_type: 'namespaces')
      end

      it 'returns false' do
        is_expected.to be_falsy
      end
    end

    context 'when selective_sync_type is shards' do
      before do
        node.update!(selective_sync_type: 'shards')
      end

      it 'returns false' do
        is_expected.to be_falsy
      end
    end

    context 'when selective_sync_type is nil' do
      before do
        node.update!(selective_sync_type: nil)
      end

      it 'returns false' do
        is_expected.to be_falsy
      end
    end

    context 'when selective_sync_type is empty string' do
      before do
        node.update!(selective_sync_type: '')
      end

      it 'returns false' do
        is_expected.to be_falsy
      end
    end

    context 'when selective_sync_type is an invalid value' do
      before do
        node.update_column(:selective_sync_type, 'invalid')
      end

      it 'raises an error' do
        expect { selective_sync_by_organizations? }.to raise_error(Geo::Errors::UnknownSelectiveSyncType)
      end
    end

    context 'when selective_sync_type has mixed case' do
      before do
        node.update_column(:selective_sync_type, 'Organizations')
      end

      it 'raises an error' do
        expect { selective_sync_by_organizations? }.to raise_error(Geo::Errors::UnknownSelectiveSyncType)
      end
    end

    context 'when selective_sync_type has extra whitespace' do
      before do
        node.update_column(:selective_sync_type, ' organizations ')
      end

      it 'raises an error' do
        expect { selective_sync_by_organizations? }.to raise_error(Geo::Errors::UnknownSelectiveSyncType)
      end
    end
  end

  describe '#namespaces_for_group_owned_replicables' do
    subject(:namespace_ids_for_group_owned_replicables) { node.namespaces_for_group_owned_replicables.pluck(:id) }

    context 'when selective sync is disabled' do
      it 'raises an error' do
        expect { namespace_ids_for_group_owned_replicables }.to raise_error(::Geo::Errors::UnknownSelectiveSyncType)
      end
    end

    context 'when selective sync is by shards' do
      it 'returns namespaces for projects in selected shards' do
        project = create(:project)
        node.update!(selective_sync_type: 'shards', selective_sync_shards: [project.repository_storage])

        is_expected.to contain_exactly(project.namespace_id)
      end
    end

    context 'when selective sync is by namespace' do
      it 'returns the selected namespace and its descendants' do
        selected_namespace = create(:group)
        child_namespace = create(:group, parent: selected_namespace)

        node.update!(selective_sync_type: 'namespaces', namespaces: [selected_namespace])

        is_expected.to contain_exactly(selected_namespace.id, child_namespace.id)
      end
    end

    context 'when selective sync is by organization' do
      it 'returns none' do
        node.update!(selective_sync_type: 'organizations', organizations: [])

        is_expected.to be_empty
      end
    end
  end

  describe '#name=' do
    context 'before validation' do
      it 'strips leading and trailing whitespace' do
        node = build(:geo_node)
        node.name = " foo\n\n "
        node.valid?

        expect(node.name).to eq('foo')
      end
    end
  end
end
