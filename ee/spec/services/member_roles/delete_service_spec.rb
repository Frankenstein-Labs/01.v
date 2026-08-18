# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::DeleteService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  let(:namespace) { role.namespace } # used in tracking custom role action shard examples

  subject(:service) { described_class.new(user) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe '#execute' do
    subject(:result) { service.execute(role) }

    context 'for self-managed' do
      let_it_be_with_reload(:role) { create(:member_role, :guest, :instance) }

      context 'with unauthorized user' do
        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with admin', :enable_admin_mode do
        let_it_be(:user) { admin }

        it_behaves_like 'deleting a role'
        it_behaves_like 'tracking custom role action', 'delete'

        context 'when the member role is linked to a security policy' do
          before do
            create(:security_policy, content: {
              actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: [role.id] }]
            })

            stub_licensed_features(security_orchestration_policies: true, custom_roles: true)
          end

          it 'returns error with message' do
            expect(result).to be_error
            expect(result.message).to eq('Custom role linked with a security policy.')
          end
        end

        context 'with admin role' do
          let(:role) { create(:member_role, :admin) }

          it_behaves_like 'deleting a role' do
            let(:audit_event_message) { 'Custom admin role was deleted' }
            let(:audit_event_type) { 'custom_admin_role_deleted' }
            let(:audit_event_abilities) { 'read_admin_users' }
          end

          it_behaves_like 'tracking custom role action', 'delete_admin'
        end
      end
    end

    context 'for SaaS', :saas do
      context 'when member role' do
        let_it_be_with_reload(:role) { create(:member_role, :guest, namespace: group) }

        context 'with unauthorized user' do
          it 'returns an error' do
            expect(result).to be_error
          end
        end

        context 'with owner' do
          before_all do
            group.add_owner(user)
          end

          it_behaves_like 'deleting a role' do
            let(:audit_entity_id) { group.id }
            let(:audit_entity_type) { group.class.name }
          end

          it_behaves_like 'tracking custom role action', 'delete'
        end
      end

      context 'with admin role', :enable_admin_mode do
        let(:role) { create(:member_role, :admin) }
        let_it_be(:user) { admin }

        it_behaves_like 'deleting a role' do
          let(:audit_event_message) { 'Custom admin role was deleted' }
          let(:audit_event_type) { 'custom_admin_role_deleted' }
          let(:audit_event_abilities) { 'read_admin_users' }
        end

        it_behaves_like 'tracking custom role action', 'delete_admin'
      end
    end
  end
end
