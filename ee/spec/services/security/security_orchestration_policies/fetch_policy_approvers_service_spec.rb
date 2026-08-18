# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::FetchPolicyApproversService, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, :private, parent: group) }
    let_it_be(:subgroup_2) { create(:group, :private, parent: group) }
    let_it_be(:project) { create(:project, :public, namespace: group) }
    let_it_be(:subgroup_project) { create(:project, namespace: subgroup_2) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:user) { create(:user) }

    let(:container) { project }
    let(:policy) { build(:approval_policy, actions: [action]) }

    subject(:service) do
      described_class.new(policy: policy, current_user: user, container: container)
    end

    before do
      group.add_member(user, :owner)
    end

    context 'with multiple actions' do
      let(:policy) { build(:approval_policy, actions: [action1, action2]) }
      let(:action1) { { type: "require_approval", approvals_required: 1, group_approvers_ids: [group.id] } }
      let(:action2) { { type: "require_approval", approvals_required: 1, user_approvers_ids: [user.id] } }

      it 'returns only group approvers for groups' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:groups]).to match_array([group])
        expect(response[:all_groups]).to match_array([group])
        expect(response[:users]).to be_empty
        expect(response[:approvers].count).to eq(2)
        expect(response[:approvers][0]).to include(groups: [group])
        expect(response[:approvers][1]).to include(users: [user])
      end
    end

    context 'with group outside of the scope' do
      let(:unrelated_group) { create(:group, :private) }
      let(:action) { { type: "require_approval", approvals_required: 1, group_approvers_ids: [unrelated_group.id, group.id] } }

      specify do
        response = service.execute

        expect(response[:groups]).to contain_exactly(group)
        expect(response[:all_groups]).to contain_exactly(group, unrelated_group)
      end
    end

    context 'with user approver' do
      let(:action) { { type: "require_approval", approvals_required: 1, user_approvers: [user.username] } }

      it 'returns user approvers' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:users]).to match_array([user])
        expect(response[:groups]).to be_empty
        expect(response[:all_groups]).to be_empty
        expect(response[:approvers].first[:users]).to match_array([user])
      end

      context 'with container of a group type' do
        let(:container) { group }

        it 'returns user approvers' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:users]).to match_array([user])
          expect(response[:groups]).to be_empty
          expect(response[:all_groups]).to be_empty
          expect(response[:approvers].first[:users]).to match_array([user])
        end

        context 'with user approvers inherited from parent group' do
          let(:action) { { type: "require_approval", approvals_required: 1, user_approvers: [user.username] } }

          let_it_be(:child) { create(:group, parent: group) }
          let(:container) { child }

          it 'returns user approvers' do
            response = service.execute

            expect(response[:status]).to eq(:success)
            expect(response[:users]).to match_array([user])
            expect(response[:groups]).to be_empty
            expect(response[:all_groups]).to be_empty
            expect(response[:approvers].first[:users]).to match_array([user])
          end
        end
      end

      context 'with container of any other type' do
        let(:container) { create(:namespace) }

        it 'does returns any user approvers' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:users]).to be_empty
          expect(response[:groups]).to be_empty
          expect(response[:all_groups]).to be_empty
          expect(response[:approvers]).to match_array([{ all_groups: [], groups: [], roles: [], users: [], custom_roles: [] }])
        end
      end

      context 'with nil container' do
        let(:container) { nil }

        it 'does returns any user approvers' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:users]).to be_empty
          expect(response[:groups]).to be_empty
          expect(response[:all_groups]).to be_empty
          expect(response[:approvers]).to match_array([{ all_groups: [], groups: [], roles: [], users: [], custom_roles: [] }])
        end
      end
    end

    context 'with group approver' do
      let(:action) { { type: "require_approval", approvals_required: 1, group_approvers_ids: [group.id] } }

      it 'returns group approvers' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:groups]).to match_array([group])
        expect(response[:all_groups]).to match_array([group])
        expect(response[:users]).to be_empty
        expect(response[:approvers].first).to include(all_groups: [group], groups: [group])
      end

      context 'when groups with same name exist in and outside of container' do
        let_it_be(:other_container) { create(:group) }
        let_it_be(:other_group) { create(:group, name: group.name, parent: other_container) }

        let(:action) { { type: "require_approval", approvals_required: 1, group_approvers: [group.name] } }

        subject { service.execute }

        context 'with security_policy_global_group_approvers_enabled setting disabled' do
          before do
            stub_ee_application_setting(security_policy_global_group_approvers_enabled: false)
          end

          it 'excludes groups outside the container' do
            expect(subject[:groups]).not_to include(other_group)
            expect(subject[:all_groups]).not_to include(other_group)
            expect(subject[:approvers].first[:all_groups]).not_to include(other_group)
          end
        end

        context 'with security_policy_global_group_approvers_enabled setting enabled' do
          before do
            stub_ee_application_setting(security_policy_global_group_approvers_enabled: true)
          end

          it 'includes groups outside the container' do
            expect(subject[:groups]).to include(other_group)
            expect(subject[:all_groups]).to include(other_group)
            expect(subject[:approvers].first[:all_groups]).to include(other_group)
          end
        end
      end

      context 'when subgroup' do
        let(:container) { subgroup_project }
        let(:action) { { type: 'require_approval', approvals_required: 1, group_approvers_ids: [subgroup.id] } }

        it 'returns group approvers' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:groups]).to match_array([subgroup])
          expect(response[:all_groups]).to match_array([subgroup])
          expect(response[:users]).to be_empty
          expect(response[:approvers].first).to include(groups: [subgroup], all_groups: [subgroup])
        end
      end

      context 'with nil container' do
        let(:container) { nil }

        it 'returns global group approvers only' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:groups]).to match_array([group])
          expect(response[:all_groups]).to match_array([group])
          expect(response[:users]).to be_empty
          expect(response[:approvers].first).to include(groups: [group], all_groups: [group])
        end
      end
    end

    context 'with role approver' do
      let(:action) { { type: "require_approval", approvals_required: 1, role_approvers: roles } }

      context 'when role_approvers in policy is empty' do
        let(:roles) { [] }

        it 'returns empty roles' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:roles]).to be_empty
          expect(response[:users]).to be_empty
          expect(response[:approvers]).to match_array([{ all_groups: [], groups: [], roles: [], users: [], custom_roles: [] }])
        end
      end

      context 'when role_approvers in policy is not empty' do
        let(:roles) { %w[maintainer developer] }

        it 'returns role approvers' do
          response = service.execute

          expect(response[:status]).to eq(:success)
          expect(response[:roles]).to match_array(roles)
          expect(response[:users]).to be_empty
          expect(response[:approvers].first[:roles]).to match_array(roles)
          expect(response[:approvers].first).to include(roles: %w[maintainer developer])
        end

        context 'and contains GUEST or REPORTER' do
          let(:roles) { %w[maintainer developer guest reporter] }

          it 'returns role approvers without guest and reporters' do
            response = service.execute

            expect(response[:status]).to eq(:success)
            expect(response[:roles]).to match_array(%w[maintainer developer])
            expect(response[:users]).to be_empty
            expect(response[:approvers].first).to include(roles: %w[maintainer developer])
          end
        end

        context 'with custom_roles' do
          let(:roles) { ['maintainer', member_role.id] }

          shared_examples 'with custom_roles and roles' do
            it 'returns custom roles and roles', :aggregate_failures do
              response = service.execute

              expect(response[:roles]).to contain_exactly('maintainer')
              expect(response[:custom_roles]).to contain_exactly(member_role)
              expect(response[:approvers].first[:roles]).to contain_exactly('maintainer')
              expect(response[:approvers].first[:custom_roles]).to contain_exactly(member_role)
            end
          end

          context 'when on gitlab.com', :saas do
            let(:member_role) { create(:member_role, namespace: container.root_ancestor) }

            it_behaves_like 'with custom_roles and roles'
          end

          context 'when on self-managed' do
            before do
              stub_saas_features(gitlab_com_subscriptions: false)
            end

            let(:member_role) { create(:member_role, :instance) }

            it_behaves_like 'with custom_roles and roles'
          end
        end
      end
    end

    context 'with both user and group approvers' do
      let(:action) { { type: "require_approval", approvals_required: 1, group_approvers: [group.path], user_approvers_ids: [user.id] } }

      it 'returns all approvers' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:users]).to match_array([user])
        expect(response[:groups]).to match_array([group])
        expect(response[:all_groups]).to match_array([group])
        expect(response[:approvers].first).to include(groups: [group], users: [user])
      end
    end

    context 'with policy equals to nil' do
      let(:policy) { nil }

      it 'returns no approver' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:users]).to be_empty
        expect(response[:groups]).to be_empty
        expect(response[:all_groups]).to be_empty
      end
    end

    context 'with action equals to nil' do
      let(:action) { nil }

      it 'returns no approver' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:users]).to be_empty
        expect(response[:groups]).to be_empty
        expect(response[:all_groups]).to be_empty
        expect(response[:approvers]).to be_empty
      end
    end

    context 'with action of an unknown type' do
      let(:action) { { type: "random_type", approvals_required: 1, group_approvers_ids: [group.id] } }

      it 'returns no approver' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:users]).to be_empty
        expect(response[:groups]).to be_empty
        expect(response[:all_groups]).to be_empty
        expect(response[:approvers]).to be_empty
      end
    end

    context 'with more users than the limit' do
      using RSpec::Parameterized::TableSyntax

      let(:user_ids) { [user.id] }
      let(:user_names) { [user.username] }

      where(:ids_multiplier, :names_multiplier, :ids_expected, :names_expected) do
        150 | 150 | 150 | 150
        300 | 300 | 0   | 300
        300 | 200 | 100 | 200
        600 | 600 | 0   | 300
      end

      with_them do
        let(:user_ids_multiplied) { user_ids * ids_multiplier }
        let(:user_name_multiplied) { user_names * names_multiplier }
        let(:user_ids_expected) { user_ids * ids_expected }
        let(:user_name_expected) { user_names * names_expected }
        let(:action) { { type: "require_approval", approvals_required: 1, user_approvers: user_name_multiplied, user_approvers_ids: user_ids_multiplied } }

        it 'considers only the first within the limit' do
          expect(project).to receive_message_chain(:team, :users, :by_ids_or_usernames).with(user_ids_expected, user_name_expected)

          service.execute

          expect((user_ids_expected + user_name_expected).count).not_to be > Security::ScanResultPolicy::APPROVERS_LIMIT
        end
      end
    end

    context 'with more groups than the limit' do
      let_it_be(:over_limit) { Security::ScanResultPolicy::APPROVERS_LIMIT + 1 }
      let_it_be(:groups) { create_list(:group, over_limit) }
      let_it_be(:groups_ids) { groups.pluck(:id) }
      let_it_be(:groups_paths) { groups.pluck(:path) }

      let(:action) { { type: "require_approval", approvals_required: 1, group_approvers: groups_paths, group_approvers_ids: groups_ids } }

      it 'considers only the first within the limit' do
        response = service.execute

        expect(response[:status]).to eq(:success)
        expect(response[:users]).to be_empty
        expect(response[:groups].count).not_to be > Security::ScanResultPolicy::APPROVERS_LIMIT
        expect(response[:all_groups].count).not_to be > Security::ScanResultPolicy::APPROVERS_LIMIT
      end
    end
  end
end
