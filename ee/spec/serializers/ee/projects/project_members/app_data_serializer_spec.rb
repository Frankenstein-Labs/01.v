# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectMembers::AppDataSerializer, feature_category: :groups_and_projects do
  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- FreeUserCap enforcement and finder checks need persisted records
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  let(:serializer) { described_class.new(project, current_user: current_user, members: []) }

  describe '#app_data' do
    subject(:app_data) do
      serializer.app_data(
        invited: [],
        links: ::Members::GroupLinksCollection.new([]),
        access_requests: [],
        pending_members_count: pending_members_count
      )
    end

    let(:pending_members_count) { nil }

    it 'includes `manage_member_roles_path` data' do
      allow(::Members::ManageRolesPath).to receive(:for).with(project, current_user)
        .and_return(Gitlab::Routing.url_helpers.admin_application_settings_roles_and_permissions_path)

      expect(app_data[:manage_member_roles_path])
        .to eq(Gitlab::Routing.url_helpers.admin_application_settings_roles_and_permissions_path)
    end

    context 'with promotion_request feature' do
      context 'when the feature is enabled' do
        let(:pending_members_count) { 2 }

        before do
          allow(serializer).to receive(:member_promotion_management_enabled?).and_return(true)
        end

        it 'returns enabled promotion_request data with the pending count' do
          expect(app_data[:promotion_request]).to include({ enabled: true, total_items: 2 })
        end
      end

      context 'when the feature is disabled' do
        let(:pending_members_count) { nil }

        before do
          allow(serializer).to receive(:member_promotion_management_enabled?).and_return(false)
        end

        it 'returns disabled promotion_request data without a count' do
          expect(app_data[:promotion_request]).to include({ enabled: false, total_items: nil })
        end
      end
    end

    context 'with `can_approve_access_requests`' do
      subject(:can_approve_access_requests) { app_data[:can_approve_access_requests] }

      context 'when project has an associated group' do
        # rubocop:disable RSpec/FactoryBot/AvoidCreate -- FreeUserCap enforcement resolves the persisted root ancestor
        let_it_be(:project) { create(:project, group: create(:group)) }
        # rubocop:enable RSpec/FactoryBot/AvoidCreate

        context 'when namespace has reached the user limit (can not approve access requests)' do
          before do
            stub_ee_application_setting(dashboard_limit_enabled: true)

            allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement, project.root_ancestor) do |instance|
              allow(instance).to receive(:enforce_cap?).and_return(true)
            end
          end

          it 'sets the value to false' do
            stub_ee_application_setting(dashboard_limit: 0)

            expect(can_approve_access_requests).to be(false)
          end
        end

        context 'when namespace has not reached the user limit (can approve access requests)' do
          it 'sets the value to true' do
            expect(can_approve_access_requests).to be(true)
          end
        end
      end

      context 'when project is a personal project (no associated group)' do
        it 'sets the value to true' do
          expect(can_approve_access_requests).to be(true)
        end
      end
    end

    context 'with `namespace_user_limit`' do
      subject(:namespace_user_limit) { app_data[:namespace_user_limit] }

      context 'when dashboard limit is set' do
        before do
          stub_ee_application_setting(dashboard_limit: 5)
        end

        it 'returns the limit' do
          expect(namespace_user_limit).to eq(5)
        end
      end

      context 'when dashboard limit is not set' do
        it 'returns 0' do
          expect(namespace_user_limit).to eq(0)
        end
      end
    end

    describe 'available roles' do
      subject(:available_roles) { app_data[:available_roles] }

      context 'when custom roles exist' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        # rubocop:disable RSpec/FactoryBot/AvoidCreate -- MemberRoles::RolesFinder loads the role from the database
        let!(:member_role) { create(:member_role, :instance) }
        # rubocop:enable RSpec/FactoryBot/AvoidCreate

        it { is_expected.to include(title: member_role.name, value: "custom-#{member_role.id}") }
      end
    end
  end
end
