# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Transfer::TopLevelGroupService, :aggregate_failures, feature_category: :organization do
  let_it_be(:old_organization) { create(:organization) }
  let_it_be(:new_organization) { create(:organization) }
  let_it_be(:user) { create(:user, organization: old_organization) }
  let_it_be_with_refind(:group) { create(:group, organization: old_organization) }

  let(:groups_param) { group }
  let(:organization_param) { new_organization }
  let(:current_user_param) { user }

  subject(:service) do
    described_class.new(
      groups: groups_param,
      new_organization: organization_param,
      current_user: current_user_param
    )
  end

  before_all do
    group.add_owner(user)
    new_organization.add_owner(user)
  end

  describe '#execute' do
    context 'when transfer is successful' do
      it 'logs an audit event for the transferred group' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'group_transferred_to_organization',
            author: user,
            scope: group,
            target: new_organization,
            message: "Transferred group to organization #{new_organization.name}"
          )
        ).and_call_original

        service.execute
      end

      context 'with multiple groups' do
        let_it_be_with_refind(:group2) { create(:group, organization: old_organization) }
        let_it_be_with_refind(:group3) { create(:group, organization: old_organization) }

        let(:groups_param) { [group, group2, group3] }

        before_all do
          group2.add_owner(user)
          group3.add_owner(user)
        end

        it 'logs an audit event for each transferred group' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).exactly(3).times.and_call_original

          service.execute
        end

        it 'creates audit events for all transferred groups' do
          expect { service.execute }.to change { AuditEventReader.count }.by(3)
        end
      end
    end

    context 'when transfer fails' do
      let(:organization_param) { nil }

      it 'does not log an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end
    end

    context 'when transfer fails due to validation' do
      let_it_be(:parent_group) { create(:group, organization: old_organization) }
      let_it_be(:subgroup) { create(:group, parent: parent_group) }

      let(:groups_param) { subgroup }

      before_all do
        parent_group.add_owner(user)
      end

      it 'does not log an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end
    end
  end
end
