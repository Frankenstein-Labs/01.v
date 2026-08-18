# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::UserActionsHelper, feature_category: :user_management do
  describe '#admin_actions', :enable_admin_mode do
    let_it_be(:current_user) { build_stubbed(:user) }
    let_it_be(:user) { build_stubbed(:user) }

    subject { helper.admin_actions(user) }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
    end

    context 'when the current user is a Restricted Administrator with the `read_admin_users` permission' do
      let_it_be(:role) { build_stubbed(:member_role, :read_admin_users) }
      let_it_be(:membership) { build_stubbed(:user_member_role, user: current_user, member_role: role) }

      before do
        allow(helper).to receive(:can?).and_call_original
        allow(helper).to receive(:can?).with(current_user, :read_admin_users).and_return(true)
      end

      it { is_expected.to be_empty }
    end
  end
end
