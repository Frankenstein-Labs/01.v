# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  describe '.virtual_registry_available?' do
    subject { described_class.virtual_registry_available?(group, user) }

    where(:dependency_proxy_enabled, :feature_flag_enabled, :licensed_feature_enabled, :setting_enabled,
      :user_with_access, :expected_result) do
      true  | true  | true  | true  | true  | true
      false | true  | true  | true  | true  | false
      true  | false | true  | true  | true  | false
      true  | true  | false | true  | true  | false
      true  | true  | true  | false | true  | false
      true  | true  | true  | true  | false | false
    end

    with_them do
      before do
        stub_config(dependency_proxy: { enabled: dependency_proxy_enabled })
        stub_feature_flags(maven_virtual_registry: feature_flag_enabled)
        stub_licensed_features(packages_virtual_registry: licensed_feature_enabled)
        allow(VirtualRegistries::Setting).to receive(:enabled_for_group?).with(group).and_return(setting_enabled)

        group.add_guest(user) if user_with_access # rubocop:disable RSpec/BeforeAllRoleAssignment -- parameterized via with_them; `user_with_access` is not available in `before_all`
      end

      it { is_expected.to be(expected_result) }
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
        stub_feature_flags(maven_virtual_registry: feature_flag_enabled)
        stub_licensed_features(packages_virtual_registry: licensed_feature_enabled)
      end

      it { is_expected.to be(expected_result) }
    end
  end

  describe '.feature_enabled?' do
    subject { described_class.feature_enabled?(group) }

    where(:dependency_proxy_enabled, :feature_flag_enabled, :licensed_feature_enabled, :setting_enabled,
      :expected_result) do
      true  | true  | true  | true  | true
      false | true  | true  | true  | false
      true  | false | true  | true  | false
      true  | true  | false | true  | false
      true  | true  | true  | false | false
    end

    with_them do
      before do
        stub_config(dependency_proxy: { enabled: dependency_proxy_enabled })
        stub_feature_flags(maven_virtual_registry: feature_flag_enabled)
        stub_licensed_features(packages_virtual_registry: licensed_feature_enabled)
        allow(VirtualRegistries::Setting).to receive(:enabled_for_group?).with(group).and_return(setting_enabled)
      end

      it { is_expected.to be(expected_result) }
    end
  end
end
