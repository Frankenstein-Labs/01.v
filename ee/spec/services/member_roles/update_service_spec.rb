# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::UpdateService, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let(:user) { regular_user }
  let(:namespace) { role.namespace } # used in tracking custom role action shard examples

  describe '#execute' do
    let_it_be(:existing_abilities) { { read_vulnerability: true } }
    let(:updated_abilities) { { read_vulnerability: false, read_code: true } }
    let(:params) do
      {
        name: role_name,
        description: role_description,
        base_access_level: Gitlab::Access::DEVELOPER,
        **updated_abilities
      }
    end

    let(:role_name) { 'new name' }
    let(:role_description) { 'new description' }

    subject(:result) { described_class.new(user, params).execute(role) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'for self-managed' do
      let_it_be_with_reload(:role) { create(:member_role, :guest, :instance, **existing_abilities) }

      context 'with unauthorized user' do
        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with authorized user', :enable_admin_mode do
        let(:user) { admin }

        it_behaves_like 'custom role update'
        it_behaves_like 'tracking custom role action', 'update'

        context 'with admin roles' do
          let_it_be(:existing_abilities) { { read_admin_cicd: true } }
          let(:updated_abilities) { { read_admin_cicd: false, read_admin_users: true } }
          let_it_be_with_reload(:role) { create(:member_role, :admin, **existing_abilities) }

          it_behaves_like 'custom role update' do
            let(:audit_event_message) { 'Custom admin role was updated' }
            let(:audit_event_type) { 'custom_admin_role_updated' }
          end

          it_behaves_like 'tracking custom role action', 'update_admin'
        end
      end
    end

    context 'for SaaS', :saas do
      context 'when member role' do
        let_it_be_with_reload(:role) { create(:member_role, :guest, namespace: group, **existing_abilities) }

        context 'with unauthorized user' do
          before_all do
            group.add_maintainer(regular_user)
          end

          it 'returns an error' do
            expect(result).to be_error
          end
        end

        context 'with authorized user' do
          before_all do
            group.add_owner(regular_user)
          end

          it_behaves_like 'custom role update' do
            let(:audit_entity_id) { group.id }
            let(:audit_entity_type) { group.class.name }
          end

          it_behaves_like 'tracking custom role action', 'update'
        end
      end

      context 'when admin role', :enable_admin_mode do
        let_it_be(:existing_abilities) { { read_admin_cicd: true } }
        let(:updated_abilities) { { read_admin_cicd: false, read_admin_users: true } }
        let_it_be_with_reload(:role) { create(:member_role, :admin, **existing_abilities) }

        context 'with unauthorized user' do
          let(:user) { regular_user }

          it 'returns an error' do
            expect(result).to be_error
          end
        end

        context 'with authorized user' do
          let(:user) { admin }

          it_behaves_like 'custom role update' do
            let(:audit_event_message) { 'Custom admin role was updated' }
            let(:audit_event_type) { 'custom_admin_role_updated' }
          end

          it_behaves_like 'tracking custom role action', 'update_admin'
        end
      end
    end
  end
end
