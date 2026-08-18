# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CurrentActivePlansForUserFinder, feature_category: :subscription_management do
  describe '#execute' do
    subject(:execute) { described_class.new(user).execute }

    context 'when user is blank' do
      let(:user) { nil }

      it { is_expected.to be_empty }
    end

    context 'when user is present', :saas do
      let_it_be_with_reload(:user) { create(:user) }
      let_it_be_with_reload(:user_namespace) do
        # prove we do not consider user namespaces in this collection
        create(:namespace_with_plan, plan: :free_plan, owner: user) do |namespace|
          user.update!(namespace: namespace)
        end
      end

      let_it_be(:free_plan) { create(:free_plan) }
      let_it_be(:premium_plan) { create(:premium_plan) }
      let_it_be(:ultimate_plan) { create(:ultimate_plan) }
      let_it_be(:ultimate_trial_plan) { create(:ultimate_trial_plan) }

      before_all do
        create(:group_with_plan, plan: :ultimate_trial_plan, owners: user)
      end

      it { is_expected.to be_empty }

      context 'when user is only an owner of a project' do
        before do
          clashing_id = [Project.maximum(:id).to_i, Namespace.maximum(:id).to_i].max + 42
          another_user = create(:user)
          create(:group_with_plan, id: clashing_id, plan: :premium_plan, owners: another_user)
          create(:project, id: clashing_id, owners: user)
        end

        it { is_expected.to be_empty }
      end

      context 'when user is only a owner of one plan' do
        before_all do
          create(:group_with_plan, plan: :free_plan, owners: user)
          # prove distinct
          create(:group_with_plan, plan: :free_plan, owners: user)
          create(:group_with_plan, plan: :premium_plan)
          create(:group_with_plan, plan: :ultimate_plan) do |g|
            # do not consider requests
            create(:group_member, :owner, :access_request, source: g, user: user)
          end
        end

        it { is_expected.to match_array([free_plan]) }
      end

      context 'when user is in groups for each current plan' do
        before_all do
          create(:group_with_plan, plan: :free_plan, owners: user)
          create(:group_with_plan, plan: :premium_plan, developers: user)
          create(:group_with_plan, plan: :ultimate_plan, guests: user)
        end

        it { is_expected.to match_array([free_plan, premium_plan, ultimate_plan]) }
      end
    end
  end
end
