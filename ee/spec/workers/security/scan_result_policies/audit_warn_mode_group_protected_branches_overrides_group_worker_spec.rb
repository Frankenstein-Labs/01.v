# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::AuditWarnModeGroupProtectedBranchesOverridesGroupWorker, "#perform", feature_category: :security_policy_management do
  subject(:perform) { described_class.new.perform(group_id) }

  shared_examples 'does not call service' do
    specify do
      expect(Security::ScanResultPolicies::AuditWarnModeGroupProtectedBranchesOverridesService).not_to receive(:perform)

      perform
    end
  end

  context 'with valid group ID' do
    let_it_be_with_reload(:group) { create(:group) }

    let(:group_id) { group.id }

    context 'when group has no protected branches' do
      include_examples "does not call service"
    end

    context 'when group has protected branches' do
      let_it_be(:protected_branch) { create(:protected_branch, :group, group: group) }

      specify do
        expect_next_instance_of(Security::ScanResultPolicies::AuditWarnModeGroupProtectedBranchesOverridesService,
          group: group) do |service|
          expect(service).to receive(:execute)
        end

        perform
      end

      context 'when group is archived' do
        before do
          group.archive
        end

        include_examples "does not call service"
      end

      context 'when group is scheduled for deletion' do
        let_it_be(:user) { create(:user) }

        before do
          group.create_deletion_schedule(marked_for_deletion_on: 1.day.from_now, user_id: user.id)
        end

        include_examples "does not call service"
      end
    end
  end

  context 'with invalid group ID' do
    let(:group_id) { non_existing_record_id }

    include_examples "does not call service"
  end
end
