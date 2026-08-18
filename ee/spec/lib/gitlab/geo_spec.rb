# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo, :geo, :request_store, feature_category: :geo_replication do
  using RSpec::Parameterized::TableSyntax
  include ::EE::GeoHelpers

  # freeze: true catches accidental mutation causing state leakage across tests.
  # primary_node uses with_refind instead because tests below intentionally
  # mutate verification_max_capacity. See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
  let_it_be_with_refind(:primary_node) { create(:geo_node, :primary) }
  let_it_be(:secondary_node, freeze: true) { create(:geo_node) }

  shared_examples 'a Geo cached value' do |method, key, expected_l1_expiry: 1.minute, expected_l2_expiry: 2.minutes|
    it 'includes GitLab version and Rails.version in the cache key' do
      expanded_key = "geo:#{key}:#{Gitlab::VERSION}:#{Rails.version}"

      expect(Gitlab::ProcessMemoryCache.cache_backend).to receive(:write)
        .with(expanded_key, an_instance_of(String), { expires_in: expected_l1_expiry }).and_call_original
      expect(Rails.cache).to receive(:write)
        .with(expanded_key, an_instance_of(String), { expires_in: expected_l2_expiry })

      described_class.public_send(method)
    end
  end

  describe '.current_node' do
    before do
      described_class.clear_memoization(:current_node)
    end

    it 'returns a GeoNode instance' do
      expect(GeoNode).to receive(:current_node).and_return(primary_node)

      expect(described_class.current_node).to eq(primary_node)
    end
  end

  describe '.primary_node' do
    context 'when primary node exists' do
      before do
        allow(GeoNode).to receive(:primary_node).and_return(primary_node)
      end

      it 'returns a cached primary url' do
        expect(GeoNode).to receive(:primary_node).once
        expect(described_class.primary_node_url).to eq(primary_node.url)

        2.times { described_class.primary_node_url }
      end

      it 'returns a cached internal_url' do
        expect(GeoNode).to receive(:primary_node).once
        expect(described_class.primary_node_internal_url).to eq(primary_node.internal_url)

        2.times { described_class.primary_node_internal_url }
      end
    end

    context 'when primary node does not exist' do
      before do
        allow(GeoNode).to receive(:primary_node).and_return(nil)
      end

      it 'returns nil for primary_node_url' do
        expect(described_class.primary_node_url).to be_nil
      end

      it 'returns nil for primary_node_internal_url' do
        expect(described_class.primary_node_internal_url).to be_nil
      end
    end
  end

  describe '.secondary_nodes' do
    it 'returns a list of Geo secondary nodes' do
      expect(described_class.secondary_nodes).to match_array(secondary_node)
    end
  end

  describe '.secondary_node?' do
    let_it_be(:another_secondary_node, freeze: true) { create(:geo_node) }

    before do
      described_class.clear_memoization(:secondary_nodes)
    end

    context 'when node_id matches an existing secondary node' do
      it 'returns true for integer node_id' do
        expect(described_class.secondary_node?(secondary_node.id)).to be_truthy
      end

      it 'returns true for string node_id' do
        expect(described_class.secondary_node?(secondary_node.id.to_s)).to be_truthy
      end

      it 'returns true for another secondary node' do
        expect(described_class.secondary_node?(another_secondary_node.id)).to be_truthy
      end
    end

    context 'when node_id does not match any secondary node' do
      it 'returns false for non-existent node_id' do
        non_existent_id = secondary_node.id + another_secondary_node.id + 999
        expect(described_class.secondary_node?(non_existent_id)).to be_falsey
      end

      it 'returns false for primary node id' do
        expect(described_class.secondary_node?(primary_node.id)).to be_falsey
      end

      it 'returns false for nil node_id' do
        expect(described_class.secondary_node?(nil)).to be_falsey
      end

      it 'returns false for empty string node_id' do
        expect(described_class.secondary_node?('')).to be_falsey
      end
    end

    context 'when there are no secondary nodes' do
      before do
        allow(described_class).to receive(:secondary_nodes).and_return([])
      end

      it 'returns false' do
        expect(described_class.secondary_node?(secondary_node.id)).to be_falsey
      end
    end
  end

  describe '.proxy_extra_data' do
    before do
      expect(described_class).to receive(:uncached_proxy_extra_data).and_return('proxy extra data')
    end

    it 'caches the result of .uncached_proxy_extra_data' do
      expect(described_class.proxy_extra_data).to be('proxy extra data')
    end

    it_behaves_like 'a Geo cached value',
      :proxy_extra_data,
      :proxy_extra_data,
      expected_l2_expiry: ::Gitlab::Geo::PROXY_JWT_CACHE_EXPIRY
  end

  describe '.uncached_proxy_extra_data' do
    before do
      described_class.clear_memoization(:current_node)
    end

    subject(:extra_data) { described_class.uncached_proxy_extra_data }

    context 'without a geo node' do
      it { is_expected.to be_nil }
    end

    context 'with an existing Geo node' do
      let(:parsed_access_key) { extra_data.split(':').first }
      let(:jwt) { JWT.decode(extra_data.split(':').second, secondary_node.secret_access_key) }
      let(:decoded_extra_data) { Gitlab::Json.parse(jwt.first['data']) }

      before do
        stub_current_geo_node(secondary_node)
      end

      it 'generates a valid JWT' do
        expect(parsed_access_key).to eq(secondary_node.access_key)
        expect(decoded_extra_data).to eq({})
      end

      it 'sets the expected expiration time', :freeze_time do
        expect(jwt.first['exp']).to eq((Time.zone.now + Gitlab::Geo::PROXY_JWT_VALIDITY_PERIOD).to_i)
      end
    end

    context 'when signing the JWT token raises errors' do
      where(:error) { [Gitlab::Geo::GeoNodeNotFoundError, OpenSSL::Cipher::CipherError] }
      with_them do
        before do
          expect_next_instance_of(Gitlab::Geo::SignedData) do |instance|
            expect(instance).to receive(:sign_and_encode_data).and_raise(error)
          end
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.primary?' do
    context 'when current node is a primary node' do
      before do
        stub_current_geo_node(primary_node)
      end

      it 'returns true' do
        expect(described_class.primary?).to be_truthy
      end

      it 'returns false when GeoNode is disabled' do
        allow(described_class).to receive(:enabled?).and_return(false)

        expect(described_class.primary?).to be_falsey
      end
    end
  end

  describe '.primary_node_configured?' do
    context 'when current node is a primary node' do
      it 'returns true' do
        expect(described_class.primary_node_configured?).to be_truthy
      end

      it 'returns false when primary does not exist' do
        primary_node.destroy!

        expect(described_class.primary_node_configured?).to be_falsey
      end
    end
  end

  describe '.current_node_misconfigured?' do
    before do
      described_class.clear_memoization(:current_node)
    end

    it 'returns true when current node is not set' do
      expect(described_class.current_node_misconfigured?).to be_truthy
    end

    it 'returns false when primary' do
      stub_current_geo_node(primary_node)

      expect(described_class.current_node_misconfigured?).to be_falsey
    end

    it 'returns false when secondary' do
      stub_current_geo_node(secondary_node)

      expect(described_class.current_node_misconfigured?).to be_falsey
    end

    it 'returns false when Geo is disabled' do
      GeoNode.delete_all

      expect(described_class.current_node_misconfigured?).to be_falsey
    end
  end

  describe '.secondary?' do
    context 'when infer_without_database is not set' do
      subject { described_class.secondary? }

      context 'when Geo is enabled and current node is a secondary node' do
        before do
          stub_current_geo_node(secondary_node)
        end

        it { is_expected.to be_truthy }
      end

      context 'when Geo is disabled' do
        before do
          allow(described_class).to receive(:enabled?).and_return(false)
        end

        it { is_expected.to be_falsey }
      end

      context 'when current node is a primary node' do
        it { is_expected.to be_falsey }
      end

      context 'when current node is an org migration target' do
        before do
          stub_org_migration_target_cell
        end

        it { is_expected.to be_falsey }
      end

      context 'when current node is nil' do
        before do
          allow(described_class).to receive(:current_node).and_return(nil)
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when infer_without_database is true' do
      subject { described_class.secondary?(infer_without_database: true) }

      where(:is_secondary) { [true, false] }
      with_them do
        before do
          allow(described_class).to receive(:secondary_check_without_db_connection) { is_secondary }
        end

        it { is_expected.to be(is_secondary) }
      end
    end
  end

  describe '.org_migration_target?' do
    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
      end

      context 'when Geo is enabled and current node exists' do
        let(:org_migration_target_node) { create(:geo_node) }

        before do
          stub_current_geo_node(org_migration_target_node)
        end

        it 'returns true' do
          expect(described_class.org_migration_target?).to be_truthy
        end
      end

      context 'when Geo is disabled' do
        before do
          allow(described_class).to receive(:enabled?).and_return(false)
        end

        it 'returns false' do
          expect(described_class.org_migration_target?).to be_falsey
        end
      end

      context 'when current node is nil' do
        before do
          allow(described_class).to receive(:current_node).and_return(nil)
        end

        it 'returns false' do
          expect(described_class.org_migration_target?).to be_falsey
        end
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(org_migration_target_cell: false)
      end

      context 'when current node exists' do
        before do
          stub_current_geo_node(secondary_node)
        end

        it 'returns false' do
          expect(described_class.org_migration_target?).to be_falsey
        end
      end
    end
  end

  describe '.secondary_or_org_migration_target?' do
    context 'when Geo is enabled and current node is a secondary node' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.secondary_or_org_migration_target?).to be_truthy
      end
    end

    context 'when Geo is enabled and current node is an org migration target' do
      before do
        stub_org_migration_target_cell
      end

      it 'returns true' do
        expect(described_class.secondary_or_org_migration_target?).to be_truthy
      end
    end

    context 'when Geo is disabled' do
      before do
        allow(described_class).to receive(:enabled?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.secondary_or_org_migration_target?).to be_falsey
      end
    end

    context 'when current node is a primary node' do
      it 'returns false' do
        expect(described_class.secondary_or_org_migration_target?).to be_falsey
      end
    end

    context 'when current node is nil' do
      before do
        allow(described_class).to receive(:current_node).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.secondary_or_org_migration_target?).to be_falsey
      end
    end

    context 'when current node is misconfigured with org migration target flag enabled' do
      before do
        stub_feature_flags(org_migration_target_cell: true)
        allow(described_class).to receive(:current_node).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.secondary_or_org_migration_target?).to be_falsey
      end
    end
  end

  describe '.replica_org?' do
    let_it_be(:organization, freeze: true) { create(:organization) }

    context 'when Geo is disabled' do
      before do
        allow(described_class).to receive(:enabled?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.replica_org?(organization)).to be_falsey
      end
    end

    context 'when current node is a primary node' do
      before do
        stub_current_geo_node(primary_node)
      end

      it 'returns false' do
        expect(described_class.replica_org?(organization)).to be_falsey
      end
    end

    context 'when current node is a secondary node' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true for any organization' do
        expect(described_class.replica_org?(organization)).to be_truthy
      end
    end

    context 'when current node is an org migration target' do
      let(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
      end

      context 'when organization is nil' do
        it 'raises ArgumentError' do
          expect { described_class.replica_org?(nil) }.to raise_error(ArgumentError, /Organization cannot be nil/)
        end
      end

      context 'when selective sync by organizations is configured' do
        before do
          org_migration_target_node.update!(selective_sync_type: 'organizations')
        end

        context 'when organization is in selective sync' do
          before do
            org_migration_target_node.organizations << organization
          end

          it 'returns true' do
            expect(described_class.replica_org?(organization)).to be_truthy
          end
        end

        context 'when organization is not in selective sync' do
          it 'returns false' do
            expect(described_class.replica_org?(organization)).to be_falsey
          end
        end
      end

      context 'when selective sync by organizations is not configured' do
        it 'returns false' do
          expect(described_class.replica_org?(organization)).to be_falsey
        end
      end
    end

    context 'when current node is an org migration target without selective sync configured' do
      before do
        stub_org_migration_target_cell
      end

      it 'returns false' do
        expect(described_class.replica_org?(organization)).to be_falsey
      end
    end
  end

  describe '.replica_namespace?' do
    let_it_be(:organization, freeze: true) { create(:organization) }
    let_it_be(:namespace, freeze: true) { create(:namespace, organization: organization) }

    context 'when namespace is nil' do
      it 'raises ArgumentError' do
        expect { described_class.replica_namespace?(nil) }.to raise_error(ArgumentError, /Namespace cannot be nil/)
      end
    end

    context 'when current node is a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.replica_namespace?(namespace)).to be_truthy
      end
    end

    context 'when current node is an org migration target' do
      let(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        org_migration_target_node.update!(selective_sync_type: 'organizations')
        org_migration_target_node.organizations << organization
      end

      it 'returns true for namespace in synced organization' do
        expect(described_class.replica_namespace?(namespace)).to be_truthy
      end

      it 'returns false for namespace not in synced organization' do
        other_namespace = create(:namespace)

        expect(described_class.replica_namespace?(other_namespace)).to be_falsey
      end
    end
  end

  describe '.replica_project?' do
    let_it_be(:organization, freeze: true) { create(:organization) }
    let_it_be(:project, freeze: true) { create(:project, organization: organization) }

    context 'when project is nil' do
      it 'raises ArgumentError' do
        expect { described_class.replica_project?(nil) }.to raise_error(ArgumentError, /Project cannot be nil/)
      end
    end

    context 'when current node is a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.replica_project?(project)).to be_truthy
      end
    end

    context 'when current node is an org migration target' do
      let(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        org_migration_target_node.update!(selective_sync_type: 'organizations')
        org_migration_target_node.organizations << organization
      end

      it 'returns true for project in synced organization' do
        expect(described_class.replica_project?(project)).to be_truthy
      end

      it 'returns false for project not in synced organization' do
        other_project = create(:project)

        expect(described_class.replica_project?(other_project)).to be_falsey
      end
    end
  end

  describe '.replica_organization_id?' do
    let_it_be(:organization, freeze: true) { create(:organization) }

    context 'when organization_id is nil' do
      it 'raises ArgumentError' do
        expect { described_class.replica_organization_id?(nil) }.to raise_error(ArgumentError)
      end
    end

    context 'when current node is a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.replica_organization_id?(organization.id)).to be_truthy
      end
    end

    context 'when current node is an org migration target' do
      let(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        org_migration_target_node.update!(selective_sync_type: 'organizations')
        org_migration_target_node.organizations << organization
      end

      it 'returns true for organization in selective sync' do
        expect(described_class.replica_organization_id?(organization.id)).to be_truthy
      end

      it 'returns false for organization not in selective sync' do
        other_organization = create(:organization)

        expect(described_class.replica_organization_id?(other_organization.id)).to be_falsey
      end
    end

    context 'when current node is an org migration target without selective sync configured' do
      before do
        stub_org_migration_target_cell
      end

      it 'returns false' do
        expect(described_class.replica_organization_id?(organization.id)).to be_falsey
      end
    end
  end

  describe '.replica_namespace_id?' do
    let_it_be(:organization, freeze: true) { create(:organization) }
    let_it_be(:namespace, freeze: true) { create(:namespace, organization: organization) }

    context 'when namespace_id is nil' do
      it 'raises ArgumentError' do
        expect { described_class.replica_namespace_id?(nil) }.to raise_error(ArgumentError)
      end
    end

    context 'when current node is a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.replica_namespace_id?(namespace.id)).to be_truthy
      end
    end

    context 'when current node is an org migration target' do
      let(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        org_migration_target_node.update!(selective_sync_type: 'organizations')
        org_migration_target_node.organizations << organization
      end

      it 'returns true for namespace in synced organization' do
        expect(described_class.replica_namespace_id?(namespace.id)).to be_truthy
      end

      it 'returns false for namespace not in synced organization' do
        other_namespace = create(:namespace)

        expect(described_class.replica_namespace_id?(other_namespace.id)).to be_falsey
      end
    end

    context 'when current node is an org migration target without selective sync configured' do
      before do
        stub_org_migration_target_cell
      end

      it 'returns false' do
        expect(described_class.replica_namespace_id?(namespace.id)).to be_falsey
      end
    end
  end

  describe '.replica_project_id?' do
    let_it_be(:organization, freeze: true) { create(:organization) }
    let_it_be(:project, freeze: true) { create(:project, organization: organization) }

    context 'when project_id is nil' do
      it 'raises ArgumentError' do
        expect { described_class.replica_project_id?(nil) }.to raise_error(ArgumentError)
      end
    end

    context 'when current node is a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.replica_project_id?(project.id)).to be_truthy
      end
    end

    context 'when current node is an org migration target' do
      let(:org_migration_target_node) { create(:geo_node) }

      before do
        stub_org_migration_target_cell(org_migration_target_node)
        org_migration_target_node.update!(selective_sync_type: 'organizations')
        org_migration_target_node.organizations << organization
      end

      it 'returns true for project in synced organization' do
        expect(described_class.replica_project_id?(project.id)).to be_truthy
      end

      it 'returns false for project not in synced organization' do
        other_project = create(:project)

        expect(described_class.replica_project_id?(other_project.id)).to be_falsey
      end
    end

    context 'when current node is an org migration target without selective sync configured' do
      before do
        stub_org_migration_target_cell
      end

      it 'returns false' do
        expect(described_class.replica_project_id?(project.id)).to be_falsey
      end
    end
  end

  describe '.replica_sharding_object?' do
    let_it_be(:organization, freeze: true) { create(:organization) }
    let_it_be(:namespace, freeze: true) { create(:namespace, organization: organization) }
    let_it_be(:project, freeze: true) { create(:project, organization: organization) }

    context 'when current node is a secondary' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true for a Project' do
        expect(described_class.replica_sharding_object?(project)).to be true
      end

      it 'returns true for a Namespace' do
        expect(described_class.replica_sharding_object?(namespace)).to be true
      end

      it 'returns true for an Organization' do
        expect(described_class.replica_sharding_object?(organization)).to be true
      end
    end

    context 'when current node is a primary' do
      before do
        stub_current_geo_node(primary_node)
      end

      it 'returns false for a Project' do
        expect(described_class.replica_sharding_object?(project)).to be false
      end

      it 'returns false for a Namespace' do
        expect(described_class.replica_sharding_object?(namespace)).to be false
      end

      it 'returns false for an Organization' do
        expect(described_class.replica_sharding_object?(organization)).to be false
      end
    end

    context 'when given an unsupported type' do
      it 'raises ArgumentError for User' do
        user = build_stubbed(:user)

        expect { described_class.replica_sharding_object?(user) }
          .to raise_error(ArgumentError, /Unsupported sharding object type: User/)
      end

      it 'raises ArgumentError for String' do
        expect { described_class.replica_sharding_object?("not_a_sharding_object") }
          .to raise_error(ArgumentError, /Unsupported sharding object type: String/)
      end
    end
  end

  describe '.skip_writes_if_replica' do
    let(:project) { build_stubbed(:project) }

    context 'when the sharding object is a replica' do
      before do
        allow(described_class).to receive(:replica_sharding_object?).with(project).and_return(true)
      end

      it 'does not yield the block' do
        block_called = false

        described_class.skip_writes_if_replica(project) { block_called = true }

        expect(block_called).to be false
      end

      it 'returns nil' do
        result = described_class.skip_writes_if_replica(project) { 'value' }

        expect(result).to be_nil
      end
    end

    context 'when the sharding object is not a replica' do
      before do
        allow(described_class).to receive(:replica_sharding_object?).with(project).and_return(false)
      end

      it 'yields the block' do
        block_called = false

        described_class.skip_writes_if_replica(project) { block_called = true }

        expect(block_called).to be true
      end

      it 'returns the block value' do
        result = described_class.skip_writes_if_replica(project) { 'value' }

        expect(result).to eq('value')
      end
    end
  end

  describe '.secondary_check_without_db_connection' do
    subject { described_class.secondary_check_without_db_connection }

    context 'when in a test environment' do
      before do
        allow(Rails).to receive_message_chain(:env, :test?).and_return(true)
      end

      it { is_expected.to be_falsey }
    end

    where(:geo_database_configured, :is_dev, :is_gdk_geo_secondary, :expected_secondary) do
      true  | true  | false | false
      true  | true  | true  | true
      true  | false | false | true
      true  | false | true  | true
      false | true  | false | false
      false | true  | true  | false
      false | false | false | false
      false | false | true  | false
    end

    with_them do
      before do
        allow(Rails).to receive_message_chain(:env, :test?).and_return(false)
        allow(Rails).to receive_message_chain(:env, :development?).and_return(is_dev)
        allow(described_class).to receive(:geo_database_configured?) { geo_database_configured }
        allow(described_class).to receive(:gdk_geo_secondary?) { is_gdk_geo_secondary }
      end

      after do
        unstub_geo_database_configured
      end

      it { is_expected.to be(expected_secondary) }
    end
  end

  describe '.gdk_geo_secondary?' do
    subject { described_class.gdk_geo_secondary? }

    context 'when GDK_GEO_SECONDARY environment variable is not set' do
      it { is_expected.to be_falsey }
    end

    context 'when GDK_GEO_SECONDARY environment variable is 1' do
      before do
        stub_env('GDK_GEO_SECONDARY', '1')
      end

      it { is_expected.to be_truthy }
    end

    context 'when GDK_GEO_SECONDARY environment variable is 0' do
      before do
        stub_env('GDK_GEO_SECONDARY', '0')
      end

      it { is_expected.to be_falsey }
    end

    context 'when GDK_GEO_SECONDARY environment variable is true' do
      before do
        stub_env('GDK_GEO_SECONDARY', 'true')
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '.secondary_with_primary?' do
    context 'when current node is a primary node' do
      it 'returns false' do
        expect(described_class.secondary_with_primary?).to be_falsey
      end
    end

    context 'when current node is a secondary node' do
      before do
        stub_current_geo_node(secondary_node)
      end

      it 'returns true' do
        expect(described_class.secondary_with_primary?).to be_truthy
      end

      context 'when a primary does not exist' do
        it 'returns false' do
          allow(::Gitlab::Geo).to receive(:primary_node_configured?).and_return(false)

          expect(described_class.secondary_with_primary?).to be_falsey
        end
      end
    end
  end

  describe '.secondary_with_unified_url?' do
    context 'when current node is a primary node' do
      it 'returns false' do
        expect(described_class.secondary_with_unified_url?).to be_falsey
      end
    end

    context 'when current node is a secondary node' do
      before do
        stub_current_geo_node(secondary_node)
      end

      context 'when a primary does not exist' do
        it 'returns false' do
          allow(::Gitlab::Geo).to receive(:primary_node_configured?).and_return(false)

          expect(described_class.secondary_with_unified_url?).to be_falsey
        end
      end

      context 'when the secondary node has different URLs' do
        it 'returns false' do
          expect(described_class.secondary_with_unified_url?).to be_falsey
        end
      end

      context 'when the secondary node has unified URL' do
        before do
          stub_current_geo_node(create(:geo_node, url: primary_node.url))
        end

        it 'returns true' do
          expect(described_class.secondary_with_unified_url?).to be_truthy
        end
      end
    end
  end

  describe '.proxied_request?' do
    it 'returns true when the header is set' do
      expect(described_class.proxied_request?({ 'HTTP_GITLAB_WORKHORSE_GEO_PROXY' => '1' })).to be_truthy
    end

    it 'returns false when the header is not present or set to an invalid value' do
      expect(described_class.proxied_request?({})).to be_falsey
      expect(described_class.proxied_request?({ 'HTTP_GITLAB_WORKHORSE_GEO_PROXY' => 'invalid' })).to be_falsey
    end
  end

  describe '.proxied_site' do
    let(:env) { {} }

    subject { described_class.proxied_site(env) }

    before do
      described_class.clear_memoization(:proxied_site)
    end

    context 'for a non-proxied request' do
      it { is_expected.to be_nil }
    end

    context 'without Geo enabled' do
      it { is_expected.to be_nil }
    end

    # this should not _really_ get called in a real-life scenario, as
    # as a secondary should always proxy a primary, so this is nil in
    # case this somehow happens
    context 'on a secondary' do
      before do
        stub_secondary_node
      end

      it { is_expected.to be_nil }
    end

    context 'on a primary' do
      before do
        stub_primary_node
      end

      context 'for a proxied request' do
        before do
          stub_proxied_request
        end

        context 'with an absent proxied site ID header' do
          it { is_expected.to be_nil }
        end

        context 'with a proxy extra data header' do
          context 'for an invalid header' do
            let(:env) do
              {
                ::Gitlab::Geo::GEO_PROXIED_EXTRA_DATA_HEADER => "invalid"
              }
            end

            it { is_expected.to be_nil }
          end

          context 'for an existing site' do
            let(:signed_data) { Gitlab::Geo::SignedData.new(geo_node: secondary_node).sign_and_encode_data({}) }
            let(:env) do
              {
                ::Gitlab::Geo::GEO_PROXIED_EXTRA_DATA_HEADER => signed_data
              }
            end

            it { is_expected.to eq(secondary_node) }
          end
        end
      end
    end
  end

  describe '.enabled?' do
    it_behaves_like 'a Geo cached value', :enabled?, :node_enabled

    context 'when any GeoNode exists' do
      it 'returns true' do
        expect(described_class.enabled?).to be_truthy
      end
    end

    context 'when no GeoNode exists' do
      before do
        GeoNode.delete_all
      end

      it 'returns false' do
        expect(described_class.enabled?).to be_falsey
      end
    end
  end

  describe '.oauth_authentication' do
    context 'for Geo primary' do
      before do
        stub_current_geo_node(primary_node)
      end

      it 'returns nil' do
        expect(described_class.oauth_authentication).to be_nil
      end
    end

    context 'when oauth_authentication returns nil' do
      before do
        stub_secondary_node
        stub_current_geo_node(secondary_node)
        allow(described_class).to receive(:oauth_authentication).and_return(nil)
      end

      it 'returns nil for oauth_authentication_uid' do
        expect(described_class.oauth_authentication_uid).to be_nil
      end

      it 'returns nil for oauth_authentication_secret' do
        expect(described_class.oauth_authentication_secret).to be_nil
      end
    end
  end

  describe '.connected?' do
    context 'when there is a database issue' do
      it 'returns false when it cannot open an active database connection' do
        allow(GeoNode.retrieve_connection).to receive(:active?).and_return(false)

        expect(described_class.connected?).to be_falsey
      end

      it 'returns false when the table does not exist' do
        allow(GeoNode).to receive(:table_exists?).and_return(false)

        expect(described_class.connected?).to be_falsey
      end
    end
  end

  describe '.expire_cache!' do
    it 'clears the Geo cache keys', :request_store do
      described_class::CACHE_KEYS.each do |key|
        content = "#{key}-content"

        described_class.cache_value(key) { content }
        expect(described_class.cache_value(key)).to eq(content)
      end

      described_class.expire_cache!

      described_class::CACHE_KEYS.each do |key|
        expect(described_class.cache_value(key) { nil }).to be_nil
      end
    end
  end

  describe '.expire_cache_keys!' do
    it 'clears specified keys', :request_store do
      cache_data = { one: 1, two: 2 }

      cache_data.each do |key, value|
        described_class.cache_value(key) { value }
        expect(described_class.cache_value(key)).to eq(value)
      end

      described_class.expire_cache_keys!(cache_data.keys)

      cache_data.keys.each do |key|
        expect(described_class.cache_value(key) { nil }).to be_nil
      end
    end
  end

  describe '.license_allows?' do
    it 'returns true if license has Geo addon' do
      stub_licensed_features(geo: true)
      expect(described_class.license_allows?).to be_truthy
    end

    it 'returns false if license doesnt have Geo addon' do
      stub_licensed_features(geo: false)
      expect(described_class.license_allows?).to be_falsey
    end

    it 'returns false if no license is present' do
      allow(License).to receive(:current).and_return(nil)
      expect(described_class.license_allows?).to be_falsey
    end
  end

  describe '.generate_access_keys' do
    it 'returns a public and secret access key' do
      keys = described_class.generate_access_keys

      expect(keys[:access_key].length).to eq(20)
      expect(keys[:secret_access_key].length).to eq(40)
    end
  end

  describe '.configure_cron_jobs!' do
    let(:manager) { double('cron_manager').as_null_object }

    before do
      allow(Gitlab::Geo::CronManager).to receive(:new) { manager }
    end

    it 'creates a cron watcher' do
      expect(manager).to receive(:create_watcher!)

      described_class.configure_cron_jobs!
    end

    it 'runs the cron manager' do
      expect(manager).to receive(:execute)

      described_class.configure_cron_jobs!
    end
  end

  describe '.allowed_ip?' do
    where(:allowed_ips, :ip, :allowed) do
      "192.1.1.1"                  | "192.1.1.1"     | true
      "192.1.1.1, 192.1.2.1"       | "192.1.2.1"     | true
      "192.1.1.0/24"               | "192.1.1.223"   | true
      "192.1.0.0/16"               | "192.1.223.223" | true
      "192.1.0.0/16, 192.1.2.0/24" | "192.1.2.223"   | true
      "192.1.0.0/16"               | "192.2.1.1"     | false
      "192.1.0.1"                  | "192.2.1.1"     | false
    end

    with_them do
      specify do
        stub_application_setting(geo_node_allowed_ips: allowed_ips)

        expect(described_class.allowed_ip?(ip)).to eq(allowed)
      end
    end
  end

  describe '.proxying_to_primary_message' do
    it 'returns a message as a string' do
      url = 'ssh://git@primary.com/namespace/repo.git'
      message = <<~STR
      This request to a Geo secondary node will be forwarded to the
      Geo primary node:

        #{url}
      STR

      expect(described_class.interacting_with_primary_message(url)).to eq(message)
    end
  end

  describe '.redirecting_to_primary_message' do
    it 'returns a message as a string' do
      url = 'http://primary.com/namespace/repo.git'
      message = <<~STR
      This request to a Geo secondary node will be forwarded to the
      Geo primary node:

        #{url}
      STR

      expect(described_class.interacting_with_primary_message(url)).to eq(message)
    end
  end

  describe '.replication_enabled_replicator_classes' do
    it 'returns an Array of replicator classes' do
      result = described_class.replication_enabled_replicator_classes

      expect(result).to be_an(Array)
      expect(result).to include(Geo::PackageFileReplicator)
    end

    context 'when replication is disabled' do
      before do
        stub_feature_flags(geo_package_file_replication: false)
      end

      it 'does not return the replicator class' do
        expect(described_class.replication_enabled_replicator_classes).not_to include(Geo::PackageFileReplicator)
      end
    end
  end

  describe '.blob_replicator_classes' do
    it 'returns an Array of blob replicator classes' do
      result = described_class.blob_replicator_classes

      expect(result).to be_an(Array)
      expect(result).to include(Geo::PackageFileReplicator)
    end

    it 'does not return repository replicator classes' do
      expect(described_class.blob_replicator_classes).not_to include(Geo::ContainerRepositoryReplicator)
      expect(described_class.blob_replicator_classes).not_to include(Geo::GroupWikiRepositoryReplicator)
    end

    context 'when replication is disabled' do
      before do
        stub_feature_flags(geo_package_file_replication: false)
      end

      it 'does not return the replicator class' do
        expect(described_class.blob_replicator_classes).not_to include(Geo::PackageFileReplicator)
      end
    end
  end

  describe '.repository_replicator_classes' do
    context 'when replication is enabled' do
      before do
        stub_container_registry_config(enabled: true)
      end

      it 'returns an Array of repository replicator classes' do
        result = described_class.repository_replicator_classes

        expect(result).to be_an(Array)
        expect(result).to include(Geo::ContainerRepositoryReplicator)
        expect(result).to include(Geo::GroupWikiRepositoryReplicator)
      end

      it 'does not return a blob replicator class' do
        expect(described_class.repository_replicator_classes).not_to include(Geo::PackageFileReplicator)
      end
    end

    context 'when replication is disabled' do
      before do
        stub_feature_flags(geo_group_wiki_repository_replication: false)
        stub_container_registry_config(enabled: false)
      end

      it 'does not return the replicator class' do
        expect(described_class.repository_replicator_classes).not_to include(Geo::GroupWikiRepositoryReplicator)
      end

      it 'does not return the container repository replicator class' do
        expect(described_class.repository_replicator_classes).not_to include(Geo::ContainerRepositoryReplicator)
      end
    end
  end

  describe '.verification_enabled_replicator_classes' do
    context 'on a Geo primary site' do
      before do
        stub_primary_site
      end

      it 'returns an Array of replicator classes' do
        result = described_class.verification_enabled_replicator_classes

        expect(result).to be_an(Array)
        expect(result).to include(Geo::PackageFileReplicator)
      end

      context 'when replication feature flag is enabled' do
        before do
          stub_feature_flags(geo_package_file_replication: true)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: true)

            expect(described_class.verification_enabled_replicator_classes).to include(Geo::PackageFileReplicator)
          end
        end

        context 'when force primary checksumming feature flag is disabled' do
          it 'returns the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: false)

            expect(described_class.verification_enabled_replicator_classes).to include(Geo::PackageFileReplicator)
          end
        end
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(geo_package_file_replication: false)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: true)

            expect(described_class.verification_enabled_replicator_classes).to include(Geo::PackageFileReplicator)
          end
        end

        context 'when force primary checksumming feature flag is disabled' do
          it 'does not return the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: false)

            expect(described_class.verification_enabled_replicator_classes).not_to include(Geo::PackageFileReplicator)
          end
        end
      end
    end

    context 'on a Geo secondary site' do
      before do
        stub_secondary_site
      end

      it 'returns an Array of replicator classes' do
        result = described_class.verification_enabled_replicator_classes

        expect(result).to be_an(Array)
        expect(result).to include(Geo::PackageFileReplicator)
      end

      context 'when replication feature flag is enabled' do
        before do
          stub_feature_flags(geo_package_file_replication: true)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'returns the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: true)

            expect(described_class.verification_enabled_replicator_classes).to include(Geo::PackageFileReplicator)
          end
        end

        context 'when force primary checksumming feature flag is disabled' do
          it 'returns the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: true)

            expect(described_class.verification_enabled_replicator_classes).to include(Geo::PackageFileReplicator)
          end
        end
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(geo_package_file_replication: false)
        end

        context 'when force primary checksumming feature flag is enabled' do
          it 'does not return the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: false)

            expect(described_class.verification_enabled_replicator_classes).not_to include(Geo::PackageFileReplicator)
          end
        end

        context 'when force primary checksumming feature flag is disabled' do
          it 'does not return the replicator class' do
            stub_feature_flags(geo_package_file_force_primary_checksumming: false)

            expect(described_class.verification_enabled_replicator_classes).not_to include(Geo::PackageFileReplicator)
          end
        end
      end
    end
  end

  describe '.verification_concurrency_limit' do
    let(:verification_max_capacity) { 12 }
    let(:node) do
      double('node', verification_max_capacity: verification_max_capacity, primary?: false, secondary?: true,
        secondary_or_org_migration_target?: true)
    end

    context 'when the current node is a secondary' do
      before do
        stub_current_geo_node(node)
      end

      it 'returns the configured capacity as a global limit' do
        expect(described_class.verification_concurrency_limit).to eq(verification_max_capacity)
      end

      it 'does not divide the capacity by the number of verification-enabled Replicator classes' do
        allow(described_class).to receive(:verification_enabled_replicator_classes).and_return(
          Array.new(6) { 'a replicator class' }
        )

        expect(described_class.verification_concurrency_limit).to eq(verification_max_capacity)
      end

      context 'when the configured capacity is 0' do
        let(:verification_max_capacity) { 0 }

        it 'returns a minimum of 1' do
          expect(described_class.verification_concurrency_limit).to eq(1)
        end
      end
    end

    context 'when current node is the primary node' do
      let(:initial_verification_max_capacity) { 10 }
      let(:updated_verification_max_capacity) { 20 }

      it 'hot-reloads updates to verification_max_capacity' do
        allow(Gitlab.config.geo).to receive(:node_name).and_return(primary_node.name)

        # Read the default value - warms the cache
        expect(described_class.verification_concurrency_limit).to eq(initial_verification_max_capacity)

        primary_node.update!(verification_max_capacity: updated_verification_max_capacity)

        expect(described_class.verification_concurrency_limit).to eq(updated_verification_max_capacity)
      end
    end
  end

  describe '.uncached_queries' do
    context 'when no block is given' do
      it 'raises error' do
        expect do
          described_class.uncached_queries
        end.to raise_error('No block given')
      end
    end

    context 'when the current node is a primary' do
      it 'wraps the block in an ApplicationRecord.uncached block' do
        stub_current_geo_node(primary_node)

        expect(Geo::TrackingBase).not_to receive(:uncached)
        expect(ApplicationRecord).to receive(:uncached).and_call_original

        expect do |b|
          described_class.uncached_queries(&b)
        end.to yield_control
      end
    end

    context 'when the current node is a secondary' do
      it 'wraps the block in a Geo::TrackingBase.uncached block and an ApplicationRecord.uncached block' do
        stub_current_geo_node(secondary_node)

        expect(Geo::TrackingBase).to receive(:uncached).and_call_original
        expect(ApplicationRecord).to receive(:uncached).and_call_original

        expect do |b|
          described_class.uncached_queries(&b)
        end.to yield_control
      end
    end

    context 'when there is no current node' do
      it 'wraps the block in an ApplicationRecord.uncached block' do
        expect(Geo::TrackingBase).not_to receive(:uncached)
        expect(ApplicationRecord).to receive(:uncached).and_call_original

        expect do |b|
          described_class.uncached_queries(&b)
        end.to yield_control
      end
    end
  end

  describe '.primary_pipeline_refs' do
    let(:project_id) { 1 }

    it 'executes the ::Geo::PrimaryApiRequestService call' do
      allow_next_instance_of(::Geo::PrimaryApiRequestService) do |service|
        allow(service).to receive(:execute).and_return('pipeline_refs' => ['foo'])
      end
      expect(described_class.primary_pipeline_refs(project_id)).to eq(['foo'])
    end

    it 'returns an empty array when no results are found' do
      allow_next_instance_of(::Geo::PrimaryApiRequestService) do |service|
        allow(service).to receive(:execute).and_return(false)
      end
      expect(described_class.primary_pipeline_refs(project_id)).to eq([])
    end
  end

  describe '.postgresql_replication_agnostic_enabled?' do
    it 'returns false when the feature flag is disabled' do
      stub_feature_flags(geo_postgresql_replication_agnostic: false)

      expect(described_class.postgresql_replication_agnostic_enabled?).to be_falsey
    end
  end
end
