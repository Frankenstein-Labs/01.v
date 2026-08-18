# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::DismissMinimalAccessProvisioningAlertService,
  feature_category: :seat_cost_management do
  let_it_be(:user) { build_stubbed(:user) }

  describe '#execute' do
    subject(:execute) { described_class.new(current_user: user).execute }

    it 'records the instance dismissal count for the current user' do
      expect(::GitlabSubscriptions::MemberManagement::SeatAwareProvisioning)
        .to receive(:record_instance_count_at_dismissal).with(user)

      execute
    end

    context 'when group is provided' do
      let(:group) { build_stubbed(:group) }

      subject(:execute) { described_class.new(current_user: user, group: group).execute }

      it 'records the group dismissal count for the current user' do
        expect(::GitlabSubscriptions::MemberManagement::SeatAwareProvisioning)
          .to receive(:record_group_count_at_dismissal).with(group, user)

        execute
      end
    end
  end
end
