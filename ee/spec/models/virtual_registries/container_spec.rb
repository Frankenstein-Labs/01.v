# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, guest_of: group) }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_feature_flags(container_virtual_registries: true)
    stub_licensed_features(container_virtual_registry: true)
    allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(
      build_stubbed(:virtual_registries_setting, group: group)
    )
  end

  describe '.feature_enabled?' do
    subject { described_class.feature_enabled?(group) }

    context 'when all conditions are met' do
      it { is_expected.to be(true) }
    end

    context 'when dependency proxy is disabled' do
      before do
        stub_config(dependency_proxy: { enabled: false })
      end

      it { is_expected.to be(false) }
    end

    context 'when container_virtual_registries feature flag is disabled' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when container_virtual_registry licensed feature is not available' do
      before do
        stub_licensed_features(container_virtual_registry: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when virtual registry setting is disabled' do
      before do
        allow(VirtualRegistries::Setting).to receive(:enabled_for_group?).with(group).and_return(false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.feature_prerequisites_met?' do
    subject { described_class.feature_prerequisites_met?(group) }

    where(:dependency_proxy_enabled, :feature_flag_enabled, :licensed_feature_enabled, :expected_result) do
      true  | true  | true  | true
      false | true  | true  | false
      true  | false | true  | false
      true  | true  | false | false
    end

    with_them do
      before do
        stub_config(dependency_proxy: { enabled: dependency_proxy_enabled })
        stub_feature_flags(container_virtual_registries: feature_flag_enabled)
        stub_licensed_features(container_virtual_registry: licensed_feature_enabled)
      end

      it { is_expected.to be(expected_result) }
    end
  end

  describe '.virtual_registry_available?' do
    subject { described_class.virtual_registry_available?(group, user) }

    context 'when all conditions are met' do
      it { is_expected.to be(true) }
    end

    context 'when dependency proxy feature is not available' do
      before do
        stub_config(dependency_proxy: { enabled: false })
      end

      it { is_expected.to be(false) }
    end

    context 'when container_virtual_registries feature flag is disabled' do
      before do
        stub_feature_flags(container_virtual_registries: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when container_virtual_registry licensed feature is not available' do
      before do
        stub_licensed_features(container_virtual_registry: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when user does not have read_virtual_registry permission' do
      let_it_be_with_reload(:user) { create(:user) }

      it { is_expected.to be(false) }
    end

    context 'when virtual registry setting is disabled' do
      before do
        allow(VirtualRegistries::Setting).to receive(:enabled_for_group?).with(group).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'for admin_virtual_registry permission' do
      subject { described_class.virtual_registry_available?(group, user, :admin_virtual_registry) }

      it { is_expected.to be(false) }

      context 'when permission is sufficient' do
        before_all do
          group.add_owner(user)
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '.extract_digest_from_path' do
    subject { described_class.extract_digest_from_path(path) }

    let(:digest) { 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }

    context 'with a manifest path containing a digest' do
      let(:path) { "v2/library/alpine/manifests/#{digest}" }

      it { is_expected.to eq(digest) }
    end

    context 'with a blob path containing a digest' do
      let(:path) { "v2/library/alpine/blobs/#{digest}" }

      it { is_expected.to eq(digest) }
    end

    context 'with a manifest path containing a tag' do
      let(:path) { 'v2/library/alpine/manifests/latest' }

      it { is_expected.to be_nil }
    end

    context 'with an unrelated path' do
      let(:path) { 'v2/library/alpine/tags/list' }

      it { is_expected.to be_nil }
    end

    context 'with a nil path' do
      let(:path) { nil }

      it { is_expected.to be_nil }
    end
  end
end
