# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::RolesFinder, feature_category: :system_access do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:subgroup, freeze: false) { create(:group, parent: group) }
  let_it_be(:project, freeze: false) { create(:project, group: subgroup) }

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:guest, freeze: false) { create(:user, guest_of: group) }
  let_it_be(:developer, freeze: false) { create(:user, developer_of: group) }
  let_it_be(:owner, freeze: false) { create(:user, owner_of: group) }
  let_it_be(:admin, freeze: false) { create(:admin) }

  let_it_be(:member_role_instance, freeze: false) { create(:member_role, :instance, name: 'Instance role') }

  let_it_be_with_reload(:member_role_1) { create(:member_role, name: 'Tester', namespace: group) }
  let_it_be(:member_role_2, freeze: false) { create(:member_role, name: 'Manager', namespace: group) }

  let_it_be(:member_role_another_group, freeze: false) { create(:member_role, name: 'Another role') }

  let(:current_user) { user }
  let(:params) { { parent: group } }

  subject(:find_member_roles) { described_class.new(current_user, params).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  context 'when filtering roles by parent' do
    let(:params) { { parent: group } }

    context 'when on SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when user is not a group owner' do
        it 'returns an empty array' do
          expect(find_member_roles).to be_empty
        end
      end

      context 'when user is a group owner' do
        let(:user) { owner }

        it 'returns member roles' do
          expect(find_member_roles).to eq([member_role_2, member_role_1])
        end

        context 'without custom roles feature' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'returns an empty array' do
            expect(find_member_roles).to be_empty
          end
        end

        context 'when parent param is not given' do
          let(:params)  { {} }

          it 'raises an error' do
            expect { find_member_roles }.to raise_error(ArgumentError)
          end
        end

        context 'when parent param is a sub-group' do
          let(:params) { { parent: subgroup } }

          it 'returns member roles' do
            expect(find_member_roles).to eq([member_role_2, member_role_1])
          end
        end

        context 'when parent param is a project' do
          let(:params) { { parent:  project } }

          it 'returns member roles' do
            expect(find_member_roles).to eq([member_role_2, member_role_1])
          end
        end
      end

      context 'when a user is the sub-group owner' do
        before_all do
          subgroup.add_owner(user)
        end

        context 'when parent param is the root group' do
          let(:params) { { parent: group } }

          it 'returns an empty array' do
            expect(find_member_roles).to be_empty
          end
        end

        context 'when parent param is the sub-group' do
          let(:params) { { parent: subgroup } }

          it 'returns member roles' do
            expect(find_member_roles).to eq([member_role_2, member_role_1])
          end
        end
      end

      context 'when a user is the project owner' do
        before_all do
          project.add_owner(user)
        end

        context 'when parent param is the root group' do
          let(:params) { { parent: group } }

          it 'returns an empty array' do
            expect(find_member_roles).to be_empty
          end
        end

        context 'when parent param is the project' do
          let(:params) { { parent: project } }

          it 'returns member roles' do
            expect(find_member_roles).to eq([member_role_2, member_role_1])
          end
        end
      end
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      let(:user) { owner }

      it 'returns instance-level member roles' do
        expect(find_member_roles).to eq([member_role_instance])
      end
    end
  end

  context 'when filtering group-level roles by ids' do
    let(:params) { { id: member_role_1.id } }

    context 'when on SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when the user is not the group owner' do
        it 'returns an empty array' do
          expect(find_member_roles).to be_empty
        end
      end

      context 'when the user is the group owner' do
        let(:user) { owner }

        it 'returns the member role' do
          expect(find_member_roles).to eq([member_role_1])
        end

        context 'when filtering by multiple ids' do
          let(:params) { { id: [member_role_1.id, member_role_2.id, member_role_another_group.id], parent: group } }

          it 'returns only member roles a user can read' do
            expect(find_member_roles).to eq([member_role_2, member_role_1])
          end
        end
      end
    end

    context 'when on self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      let(:user) { owner }

      it 'returns an empty array' do
        expect(find_member_roles).to be_empty
      end
    end
  end

  context 'when filtering instance-level roles by id' do
    let(:params) { { id: member_role_instance.id } }

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns the member role' do
          expect(find_member_roles).to eq([member_role_instance])
        end
      end
    end

    context 'when the user is the group owner' do
      let(:user) { owner }

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns the member role' do
          expect(find_member_roles).to eq([member_role_instance])
        end
      end
    end
  end

  context 'when filtering roles for the instance' do
    let(:params) { {} }

    context 'when the user is an admin', :enable_admin_mode do
      let(:current_user) { admin }

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns instance-level member roles' do
          expect(find_member_roles).to match_array([member_role_instance])
        end
      end

      context 'when on SaaS', :saas do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it 'raises an error' do
          expect { find_member_roles }.to raise_error(ArgumentError)
        end
      end
    end

    context 'when the user is the group owner' do
      let(:user) { owner }

      context 'when on self-managed' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it 'returns instance-level member roles' do
          expect(find_member_roles).to eq([member_role_instance])
        end
      end

      context 'when on SaaS', :saas do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        it 'raises an error' do
          expect { find_member_roles }.to raise_error(ArgumentError)
        end
      end
    end
  end

  context 'when filtering assignable roles' do
    shared_examples 'filters assignable roles' do
      let(:user) { developer }

      context 'when assignable param is NOT provided' do
        let(:params) { { parent: group } }

        context 'when user not assign any member roles' do
          it "doesn't perform assignable filtering" do
            expect(find_member_roles).to match_array([member_role_1, member_role_2])
          end
        end
      end

      context 'when assignable param is false' do
        let(:params) { { assignable: false, parent: group } }

        context 'when user can assign member roles' do
          let(:user) { owner }

          it "doesn't perform assignable filtering" do
            expect(find_member_roles).to match_array([member_role_1, member_role_2])
          end
        end
      end

      context 'when parent is NOT provided' do
        let(:params) { { assignable: true, parent: group } }

        it "doesn't perform assignable filtering" do
          expect(find_member_roles).to match_array([member_role_1, member_role_2])
        end
      end

      context 'when parent provided' do
        let(:params) { { assignable: true, parent: group } }

        context 'when user can assign no member roles' do
          let(:user) { guest }

          it 'returns empty' do
            expect(find_member_roles).to be_empty
          end
        end

        context 'when user can assign all member roles' do
          it 'returns member roles' do
            expect(find_member_roles).to match_array([member_role_1, member_role_2])
          end
        end

        context 'when user can assign some member roles' do
          before do
            member_role_1.update!(admin_security_attributes: true)
          end

          it 'returns the roles the user should be able to assign' do
            expect(find_member_roles).to eq([member_role_2])
          end
        end
      end
    end

    context 'when on self-managed' do
      it_behaves_like 'filters assignable roles' do
        let_it_be(:member_role_2, freeze: false) { create(:member_role, :instance) }
        let(:member_role_1) { member_role_instance }
      end
    end

    context 'when on SaaS', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it_behaves_like 'filters assignable roles'
    end
  end

  context 'when sorting member roles' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    let_it_be(:name_asc) { [member_role_2, member_role_1] }
    let_it_be(:name_desc) { [member_role_1, member_role_2] }
    let_it_be(:id_asc) { [member_role_1, member_role_2] }
    let_it_be(:id_desc) { [member_role_2, member_role_1] }
    let(:user) { owner }

    where(:order, :sort, :result) do
      nil         | nil   | :name_asc
      nil         | :asc  | :name_asc
      nil         | :desc | :name_desc
      :name       | nil   | :name_asc
      :name       | :asc  | :name_asc
      :name       | :desc | :name_desc
      :id         | nil   | :id_asc
      :id         | :asc  | :id_asc
      :id         | :desc | :id_desc
      :created_at | nil   | :id_asc
      :created_at | :asc  | :id_asc
      :created_at | :desc | :id_desc
    end

    with_them do
      let(:params) { super().merge(order_by: order, sort: sort, parent: group) }

      it 'returns the result with correct ordering' do
        expect(find_member_roles).to eq public_send(result)
      end
    end
  end
end
