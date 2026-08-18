# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::CreateService, feature_category: :system_access do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:user) { create(:user) }

  let(:namespace) { nil } # used in tracking custom role action shard examples

  describe '#execute' do
    let(:abilities) { { read_vulnerability: true } }
    let(:params) do
      {
        namespace: group,
        name: role_name,
        base_access_level: Gitlab::Access::GUEST
      }.merge(abilities)
    end

    let(:role_name) { 'new name' }
    let(:role_class) { MemberRole }

    subject(:create_role) { described_class.new(user, params).execute }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'for group member roles' do
      let(:fail_condition!) do
        allow(group).to receive(:custom_roles_enabled?).and_return(false)
      end

      context 'with unauthorized user', :saas do
        before_all do
          group.add_maintainer(user)
        end

        let(:error_message) { 'Operation not allowed' }

        it_behaves_like 'custom role create service returns error' do
          let(:audit_entity_id) { group.id }
          let(:audit_entity_type) { 'Group' }
        end
      end

      context 'with authorized user' do
        before_all do
          group.add_owner(user)
        end

        context 'with root group' do
          context 'when on SaaS', :saas do
            let(:namespace) { group }
            let(:expected_organization) { nil }

            it_behaves_like 'custom role creation', 'member_role_created', 'Member role was created' do
              let(:audit_entity_id) { group.id }
              let(:audit_entity_type) { 'Group' }
            end

            it_behaves_like 'tracking custom role action', 'create'

            context 'with a missing param' do
              before do
                params.delete(:base_access_level)
              end

              let(:error_message) { 'Base access level' }

              it_behaves_like 'custom role create service returns error'
            end

            context 'with admin custom permissions' do
              let(:abilities) { { read_admin_users: true } }

              let(:error_message) { 'Unknown permission: read_admin_users' }

              it_behaves_like 'custom role create service returns error'
            end
          end

          context 'when on self-managed' do
            let(:error_message) { 'Operation not allowed' }

            it_behaves_like 'custom role create service returns error'
          end
        end

        context 'with non-root group', :saas do
          before_all do
            group.update!(parent: create(:group))
          end

          let(:error_message) { 'Namespace must be top-level namespace' }

          it_behaves_like 'custom role create service returns error'
        end
      end
    end

    context 'for instance-level member roles' do
      let(:fail_condition!) do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(true)
      end

      before do
        params.delete(:namespace)
      end

      context 'with unauthorized user' do
        before_all do
          group.add_owner(user)
        end

        let(:error_message) { 'Operation not allowed' }

        it_behaves_like 'custom role create service returns error'
      end

      context 'with authorized user', :enable_admin_mode do
        before_all do
          user.update!(admin: true)
        end

        context 'when on self-managed' do
          let(:expected_organization) { user.organization }

          it_behaves_like 'custom role creation', 'member_role_created', 'Member role was created'

          it_behaves_like 'tracking custom role action', 'create'

          context 'with a missing param' do
            before do
              params.delete(:base_access_level)
            end

            let(:error_message) { 'Base access level' }

            it_behaves_like 'custom role create service returns error'
          end
        end

        context 'when on SaaS', :saas do
          context 'when creating a regular custom role' do
            let(:error_message) { "Namespace can't be blank" }

            it_behaves_like 'custom role create service returns error'
          end
        end

        context 'when creating an admin custom role' do
          let(:abilities) { { read_admin_users: true } }

          before do
            params.delete(:base_access_level)
          end

          it_behaves_like 'custom role creation' do
            let(:expected_organization) { user.organization }
            let(:fail_condition!) do
              allow(Ability).to receive(:allowed?).and_return(false)
            end

            let(:audit_event_message) { 'Custom admin role was created' }
            let(:audit_event_type) { 'custom_admin_role_created' }
          end

          it_behaves_like 'tracking custom role action', 'create_admin'
        end
      end
    end
  end
end
