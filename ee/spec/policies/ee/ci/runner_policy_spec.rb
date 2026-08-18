# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerPolicy, feature_category: :runner_core do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

  subject(:policy) { described_class.new(user, runner) }

  describe 'ci/cd runners' do
    context 'with auditor access' do
      let_it_be(:user) { create(:auditor) }

      context 'with instance runner' do
        let(:runner) { instance_runner }

        it 'allows only read permissions' do
          expect_allowed :read_runner
          expect_allowed :read_builds
          expect_disallowed :assign_runner, :update_runner, :delete_runner
        end
      end

      context 'with group runner' do
        let(:runner) { group_runner }

        it 'allows only read permissions' do
          expect_allowed :read_runner
          expect_allowed :read_builds
          expect_disallowed :assign_runner, :update_runner, :delete_runner
        end
      end

      context 'with project runner' do
        let(:runner) { project_runner }

        it 'allows only read permissions' do
          expect_allowed :read_runner
          expect_allowed :read_builds
          expect_disallowed :assign_runner, :update_runner, :delete_runner
        end
      end
    end
  end

  describe 'Custom Roles' do
    shared_examples 'custom role admin_runners permission behavior' do
      context 'when custom roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it { expect_allowed(:assign_runner, :read_runner, :update_runner, :delete_runner) }
      end

      context 'when custom roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { expect_disallowed(:assign_runner, :read_runner, :update_runner, :delete_runner) }
      end
    end

    shared_examples 'custom role read_runners permission behavior' do
      context 'when custom roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it { expect_allowed(:read_runner) }
      end

      context 'when custom roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { expect_disallowed(:read_runner) }
      end
    end

    shared_examples 'custom role read_admin_cicd permission behavior' do
      context 'when custom roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it { expect_allowed(:read_runner, :read_builds) }
      end

      context 'when custom roles feature is disabled' do
        let(:expected_disallowed) do
          runner.instance_type? ? %i[read_builds] : %i[read_runner read_builds]
        end

        before do
          stub_licensed_features(custom_roles: false)
        end

        it { expect_disallowed(*expected_disallowed) }
      end
    end

    context 'for a group runner' do
      let(:runner) { group_runner }

      let(:resource) { group_runner }
      let(:resource_parent) { group }

      context 'when user has the admin_runners permission' do
        context 'with a custom role' do
          let_it_be(:admin_runners_role) { create(:member_role, :guest, :admin_runners, namespace: group) }
          let_it_be(:membership) do
            create(:group_member, :guest, member_role: admin_runners_role, user: user, source: group)
          end

          it_behaves_like 'custom role admin_runners permission behavior'
        end

        context 'as a group owner' do
          it_behaves_like 'does not call custom role query', [:owner] do
            let(:ability) { :assign_runner }
          end
        end
      end

      context 'when user has the read_runners permission' do
        context 'with a custom role' do
          let_it_be(:read_runners_role) { create(:member_role, :guest, :read_runners, namespace: group) }
          let_it_be(:membership) do
            create(:group_member, :guest, member_role: read_runners_role, user: user, source: group)
          end

          it_behaves_like 'custom role read_runners permission behavior'
        end

        context 'as a group owner' do
          it_behaves_like 'does not call custom role query', [:owner] do
            let(:ability) { :read_runner }
          end
        end
      end
    end

    context 'for a project runner' do
      let(:runner) { project_runner }

      let(:resource) { project_runner }
      let(:resource_parent) { project }

      context 'when user has the admin_runners permission' do
        context 'with a custom role' do
          let_it_be(:admin_runners_role) { create(:member_role, :guest, :admin_runners, namespace: group) }
          let_it_be(:membership) do
            create(:group_member, :guest, member_role: admin_runners_role, user: user, source: group)
          end

          it_behaves_like 'custom role admin_runners permission behavior'
        end

        context 'as a project owner' do
          it_behaves_like 'does not call custom role query', [:owner] do
            let(:ability) { :assign_runner }
          end
        end
      end

      context 'when user has the read_runners permission' do
        context 'with a custom role' do
          let_it_be(:read_runners_role) { create(:member_role, :guest, :read_runners, namespace: group) }
          let_it_be(:membership) do
            create(:group_member, :guest, member_role: read_runners_role, user: user, source: group)
          end

          it_behaves_like 'custom role read_runners permission behavior'
        end

        context 'as a project owner' do
          it_behaves_like 'does not call custom role query', [:owner] do
            let(:ability) { :read_runner }
          end
        end
      end
    end

    describe 'with admin custom roles', :enable_admin_mode do
      let_it_be_with_refind(:user) { create(:user) }

      context 'when user has the read_admin_cicd custom permission' do
        let_it_be(:admin_role) { create(:admin_member_role, :read_admin_cicd, user: user) }

        context 'for an instance runner' do
          let(:runner) { instance_runner }

          it_behaves_like 'custom role read_admin_cicd permission behavior'
        end

        context 'for a group runner' do
          let(:runner) { group_runner }

          it_behaves_like 'custom role read_admin_cicd permission behavior'
        end

        context 'for a project runner' do
          let(:runner) { project_runner }

          it_behaves_like 'custom role read_admin_cicd permission behavior'
        end
      end
    end
  end
end
