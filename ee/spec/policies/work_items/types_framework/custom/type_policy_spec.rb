# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::Custom::TypePolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  subject(:policy) { described_class.new(user, custom_type) }

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  context 'with namespace-scoped custom type' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group) }

    context 'when user does not have access to the namespace' do
      it { expect_disallowed(:read_work_item_type) }
    end

    context 'when user has access to the namespace' do
      before_all do
        group.add_guest(user)
      end

      it { expect_allowed(:read_work_item_type) }

      context 'when user is a maintainer' do
        before_all do
          group.add_maintainer(user)
        end

        before do
          stub_licensed_features(configurable_work_item_types: true, work_item_status: true)
        end

        it { expect_allowed(:admin_work_item_lifecycle) }
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(configurable_work_item_types: false)
        end

        it { expect_allowed(:read_work_item_type) }
        it { expect_disallowed(:admin_work_item_lifecycle) }
      end
    end

    context 'when namespace is public' do
      let_it_be(:public_group) { create(:group, :public) }
      let_it_be(:custom_type) { create(:work_item_custom_type, namespace: public_group) }

      it { expect_allowed(:read_work_item_type) }
    end
  end

  context 'with organization-scoped custom type' do
    let_it_be(:organization) { create(:organization, :private) }
    let_it_be(:custom_type) { create(:work_item_custom_type, :with_organization, organization: organization) }

    context 'when user does not have access to the organization' do
      it { expect_disallowed(:read_work_item_type) }
    end

    context 'when user has access to the organization' do
      before_all do
        create(:organization_user, organization: organization, user: user)
      end

      it { expect_allowed(:read_work_item_type) }

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(configurable_work_item_types: false)
        end

        it { expect_allowed(:read_work_item_type) }
        it { expect_disallowed(:admin_work_item_lifecycle) }
      end
    end

    context 'when organization is public' do
      let_it_be(:public_organization) { create(:organization, :public) }
      let_it_be(:custom_type) { create(:work_item_custom_type, :with_organization, organization: public_organization) }

      it { expect_allowed(:read_work_item_type) }
    end
  end
end
