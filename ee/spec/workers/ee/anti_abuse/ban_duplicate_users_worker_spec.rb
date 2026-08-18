# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::BanDuplicateUsersWorker, :clean_gitlab_redis_shared_state, feature_category: :instance_resiliency do
  let(:worker) { described_class.new }
  let_it_be_with_reload(:banned_user) { create(:user, email: 'user+banned@example.com') }

  subject { worker.perform(banned_user.id) }

  # The banned user cannot be instantiated as banned because validators prevent users from
  # being created that have similar characteristics of previously banned users.
  before do
    stub_application_setting(enforce_email_subaddress_restrictions: true)
    banned_user.ban!
  end

  describe 'ban users with the same detumbled email address' do
    let(:ban_reason) { "User #{banned_user.id} was banned with the same detumbled email address" }
    let_it_be_with_reload(:duplicate_user) { create(:user, email: 'user+duplicate@example.com') }

    it_behaves_like 'bans the duplicate user'

    context "when the user is an enterprise user" do
      let_it_be(:enterprise_group) { create(:group) }

      before do
        duplicate_user.update!(enterprise_group_id: enterprise_group.id)
      end

      it_behaves_like 'does not ban the duplicate user'
    end

    context "when the user belongs to a paid namespace", :saas do
      before do
        create(:group_with_plan, plan: :ultimate_plan, developers: duplicate_user)
      end

      it_behaves_like 'does not ban the duplicate user'
    end
  end
end
