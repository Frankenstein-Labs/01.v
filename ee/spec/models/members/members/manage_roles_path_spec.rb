# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ManageRolesPath, feature_category: :permissions do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:source) { build_stubbed(:group) }
  let_it_be(:root_group) { source.root_ancestor }

  subject(:path) { described_class.for(source, user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  context 'when the source is nil' do
    let(:source) { nil }

    it { is_expected.to be_nil }
  end

  context 'when gitlab_com_subscriptions feature is available', :saas_gitlab_com_subscriptions do
    it { is_expected.to be_nil }

    context 'as owner' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_group_member, root_group).and_return(true)
      end

      it { is_expected.to eq(Gitlab::Routing.url_helpers.group_settings_roles_and_permissions_path(root_group)) }

      context 'when custom roles are not available' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be_nil }
      end
    end
  end

  context 'when in admin mode', :enable_admin_mode do
    it { is_expected.to be_nil }

    context 'as admin' do
      let_it_be(:user) { build_stubbed(:user, :admin) }

      it { is_expected.to eq(Gitlab::Routing.url_helpers.admin_application_settings_roles_and_permissions_path) }

      context 'when custom roles are not available' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be_nil }
      end
    end
  end
end
