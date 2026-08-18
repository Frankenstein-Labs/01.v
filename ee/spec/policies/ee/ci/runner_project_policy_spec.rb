# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerProjectPolicy, feature_category: :runner_core do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project, group: group) }
  let_it_be(:runner) { create(:ci_runner, :project, projects: [project, other_project]) }
  let_it_be(:owner_runner_project) { project.runner_projects.order(:id).first }
  let_it_be(:member_runner_project) { other_project.runner_projects.order(:id).first }

  let_it_be(:locked_runner) { create(:ci_runner, :project, :locked, projects: [project]) }
  let_it_be(:locked_runner_project) { locked_runner.runner_projects.order(:id).first }

  let(:runner_project) { member_runner_project }

  subject(:policy) { described_class.new(user, runner_project) }

  describe 'Custom Roles' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_licensed_features(custom_roles: true)
    end

    describe 'ability :unassign_runner' do
      shared_examples 'custom role admin_runners permission behavior' do
        context 'with regular runner' do
          it { expect_allowed :unassign_runner }
        end

        context 'with locked runner' do
          let(:runner_project) { locked_runner_project }

          it { expect_disallowed :unassign_runner }
        end

        context 'with owner runner project (assigned to owner project)' do
          let(:runner_project) { owner_runner_project }

          it { expect_disallowed :unassign_runner }
        end
      end

      it { expect_disallowed :unassign_runner }

      context 'when user has the admin_runners custom permission' do
        let_it_be(:role) { create(:member_role, :guest, :admin_runners, namespace: group) }
        let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

        it_behaves_like 'custom role admin_runners permission behavior'

        context 'when custom roles feature is disabled' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it { expect_disallowed :unassign_runner }
        end
      end

      context 'when user has other custom permissions but not admin_runners' do
        let!(:role) { create(:member_role, :guest, :read_runners, namespace: group) }
        let!(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

        it { expect_disallowed :unassign_runner }
      end

      context 'when user is a member without custom roles' do
        let!(:membership) { create(:group_member, :guest, user: user, source: group) }

        it { expect_disallowed :unassign_runner }
      end

      context 'when user has admin_runners permission on different group' do
        let_it_be(:other_group) { create(:group) }
        let!(:role) { create(:member_role, :guest, :admin_runners, namespace: other_group) }
        let!(:membership) { create(:group_member, :guest, member_role: role, user: user, source: other_group) }

        it { expect_disallowed :unassign_runner }
      end

      context 'when user has admin_runners permission with guest access level' do
        let_it_be(:role) { create(:member_role, :guest, :admin_runners, namespace: group) }
        let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

        it_behaves_like 'custom role admin_runners permission behavior'
      end
    end
  end
end
