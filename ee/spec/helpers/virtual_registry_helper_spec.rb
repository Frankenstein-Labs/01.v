# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistryHelper, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  describe '#virtual_registries_data' do
    let(:group) { build_stubbed(:group) }

    subject { Gitlab::Json.parse(helper.virtual_registries_data(group)) }

    it 'returns the correct structure' do
      is_expected.to include(
        'fullPath' => group.full_path,
        'registryTypes' => a_hash_including(
          'maven' => a_hash_including(
            'newPagePath' => a_string_matching(%r{virtual_registries/maven/registries/new}),
            'landingPagePath' => a_string_matching(%r{virtual_registries/maven})
          )
        )
      )
    end

    it 'includes maxRegistriesCount for each registry type' do
      maven_data = Gitlab::Json.parse(helper.virtual_registries_data(group))
      expect(maven_data['registryTypes']['maven']['maxRegistriesCount']).to eq(
        VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT
      )
      expect(maven_data['registryTypes']['container']['maxRegistriesCount']).to eq(
        VirtualRegistries::Container::Registry::MAX_REGISTRY_COUNT
      )
    end
  end

  describe '#registry_types_for_vue' do
    let(:group) { build_stubbed(:group) }

    subject(:registry_types) { helper.registry_types_for_vue(group) }

    context 'when all feature flags are enabled' do
      it 'returns both maven and container types' do
        is_expected.to include(:maven, :container)
      end

      it 'includes correct paths for maven' do
        expect(registry_types[:maven]).to include(
          newPagePath: new_group_virtual_registries_maven_registry_path(group),
          landingPagePath: group_virtual_registries_maven_registries_and_upstreams_path(group),
          maxRegistriesCount: VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT
        )
      end

      it 'includes correct paths for container' do
        expect(registry_types[:container]).to include(
          newPagePath: new_group_virtual_registries_container_registry_path(group),
          landingPagePath: group_virtual_registries_container_registries_path(group),
          maxRegistriesCount: VirtualRegistries::Container::Registry::MAX_REGISTRY_COUNT
        )
      end
    end

    context 'when maven_virtual_registry feature flag is disabled' do
      before do
        stub_feature_flags(maven_virtual_registry: false)
      end

      it 'does not include maven type' do
        is_expected.not_to include(:maven)
      end

      it 'includes container type' do
        is_expected.to include(:container)
      end
    end

    context 'when container_virtual_registries feature flag is disabled' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it 'includes maven type' do
        is_expected.to include(:maven)
      end

      it 'does not include container type' do
        is_expected.not_to include(:container)
      end
    end

    context 'when all feature flags are disabled' do
      before do
        stub_feature_flags(
          maven_virtual_registry: false,
          container_virtual_registries: false
        )
      end

      it 'returns empty hash' do
        is_expected.to eq({})
      end
    end
  end

  describe '#can_create_virtual_registry?' do
    let(:group) { build_stubbed(:group) }
    let(:user) { build_stubbed(:user) }
    let(:policy_subject) { instance_double(::VirtualRegistries::Policies::Group) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(group).to receive(:virtual_registry_policy_subject).and_return(policy_subject)
      allow(Ability).to receive(:allowed?).with(user, :create_virtual_registry,
        policy_subject).and_return(allow_create_virtual_registry)
    end

    subject { helper.can_create_virtual_registry?(group) }

    where(:allow_create_virtual_registry, :result) do
      true  | true
      false | false
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#can_destroy_virtual_registry?' do
    let(:group) { build_stubbed(:group) }
    let(:user) { build_stubbed(:user) }
    let(:policy_subject) { instance_double(::VirtualRegistries::Policies::Group) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(group).to receive(:virtual_registry_policy_subject).and_return(policy_subject)
      allow(Ability).to receive(:allowed?).with(user, :destroy_virtual_registry,
        policy_subject).and_return(allow_destroy_virtual_registry)
    end

    subject { helper.can_destroy_virtual_registry?(group) }

    where(:allow_destroy_virtual_registry, :result) do
      true  | true
      false | false
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#maven_registries_and_upstreams_data' do
    let(:group) { build_stubbed(:group) }

    subject { ::Gitlab::Json.parse(helper.maven_registries_and_upstreams_data(group)) }

    it 'returns maven registries JSON data' do
      is_expected.to include(
        'fullPath' => group.full_path,
        'editRegistryPathTemplate' => edit_group_virtual_registries_maven_registry_path(group, ':id'),
        'showRegistryPathTemplate' => group_virtual_registries_maven_registry_path(group, ':id'),
        'editUpstreamPathTemplate' => edit_group_virtual_registries_maven_upstream_path(group, ':id'),
        'showUpstreamPathTemplate' => group_virtual_registries_maven_upstream_path(group, ':id')
      )
    end
  end

  describe '#delete_registry_modal_data' do
    let(:maven_registry) do
      build_stubbed(:virtual_registries_packages_maven_registry, group: group, name: 'test-registry')
    end

    let(:group) { build_stubbed(:group) }

    subject { helper.delete_registry_modal_data(group, maven_registry) }

    it 'returns the JSON data for modal to delete registry' do
      is_expected.to eq({
        path: group_virtual_registries_maven_registry_path(group, maven_registry),
        method: 'delete',
        modal_attributes: {
          title: 'Delete Maven registry',
          size: 'sm',
          modalClass: 'gl-break-words',
          messageHtml: 'Are you sure you want to delete <strong>test-registry</strong>?',
          okVariant: 'danger',
          okTitle: 'Delete'
        }
      })
    end
  end

  describe '#max_maven_registries_count_exceeded?' do
    let(:group) { build_stubbed(:group) }

    subject { helper.max_maven_registries_count_exceeded?(group) }

    before do
      stub_const('VirtualRegistries::Packages::Maven::Registry::MAX_REGISTRY_COUNT', 20)
      allow(::VirtualRegistries).to receive(:registries_count_for)
        .with(group, registry_type: 'maven')
        .and_return(current_count)
    end

    context 'when current count is below maximum' do
      let(:current_count) { 15 }

      it { is_expected.to be false }
    end

    context 'when current count equals maximum' do
      let(:current_count) { 20 }

      it { is_expected.to be true }
    end

    context 'when current count exceeds maximum' do
      let(:current_count) { 25 }

      it { is_expected.to be true }
    end
  end

  describe '#edit_upstream_template_data' do
    let(:maven_upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }
    let(:maven_upstream_attributes) do
      {
        'id' => maven_upstream.id,
        'name' => maven_upstream.name,
        'username' => maven_upstream.username,
        'url' => maven_upstream.url,
        'description' => maven_upstream.description,
        'cacheValidityHours' => maven_upstream.cache_validity_hours,
        'metadataCacheValidityHours' => maven_upstream.metadata_cache_validity_hours
      }
    end

    before do
      allow(helper).to receive(:maven_upstream_attributes).with(maven_upstream).and_return(maven_upstream_attributes)
    end

    subject { ::Gitlab::Json.parse(helper.edit_upstream_template_data(maven_upstream)) }

    it 'returns maven upstream edit template data' do
      is_expected.to include(
        'mavenCentralUrl' => ::VirtualRegistries::Packages::Maven::Upstream::MAVEN_CENTRAL_URL,
        'initialUpstream' => maven_upstream_attributes,
        'upstreamsPath' =>
          group_virtual_registries_maven_registries_and_upstreams_path(maven_upstream.group, { tab: 'upstreams' }),
        'upstreamPath' =>
          group_virtual_registries_maven_upstream_path(maven_upstream.group, maven_upstream)
      )
    end
  end

  describe '#maven_upstream_data' do
    let(:maven_upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }
    let(:maven_upstream_attributes) do
      {
        'id' => maven_upstream.id,
        'name' => maven_upstream.name,
        'url' => maven_upstream.url,
        'description' => maven_upstream.description
      }
    end

    subject { ::Gitlab::Json.parse(helper.maven_upstream_data(maven_upstream)) }

    it 'returns maven upstream template data' do
      is_expected.to include(
        'initialUpstream' => maven_upstream_attributes,
        'editUpstreamPath' =>
          edit_group_virtual_registries_maven_upstream_path(maven_upstream.group, maven_upstream)
      )
    end
  end

  describe '#maven_registry_data' do
    let(:group) { build_stubbed(:group) }

    let(:maven_registry) do
      build_stubbed(:virtual_registries_packages_maven_registry, group: group, name: 'test-registry')
    end

    subject { ::Gitlab::Json.parse(helper.maven_registry_data(group, maven_registry)) }

    it 'returns maven registry data as JSON' do
      is_expected.to include(
        'fullPath' => group.full_path,
        'initialRegistry' => {
          'id' => maven_registry.id,
          'name' => maven_registry.name,
          'description' => maven_registry.description
        },
        'mavenCentralUrl' => ::VirtualRegistries::Packages::Maven::Upstream::MAVEN_CENTRAL_URL,
        'registryEditPath' => edit_group_virtual_registries_maven_registry_path(group, maven_registry),
        'maxRegistryUpstreamsCount' => VirtualRegistries::Packages::Maven::RegistryUpstream::MAX_UPSTREAMS_COUNT,
        'showUpstreamPathTemplate' => group_virtual_registries_maven_upstream_path(group, ':id'),
        'editUpstreamPathTemplate' => edit_group_virtual_registries_maven_upstream_path(group, ':id')
      )
    end
  end

  describe '#container_template_data' do
    let(:group) { build_stubbed(:group) }

    subject { helper.container_template_data(group) }

    it 'returns container template data' do
      is_expected.to eq({
        full_path: group.full_path,
        base_path: group_virtual_registries_container_path(group),
        max_registries_count: VirtualRegistries::Container::Registry::MAX_REGISTRY_COUNT,
        max_registry_upstreams_count: VirtualRegistries::Container::RegistryUpstream::MAX_UPSTREAMS_COUNT
      })
    end
  end
end
