# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Codeowners' do
      context 'when the project is in a subgroup', :requires_admin do
        let(:approver) { create(:user, api_client: Runtime::API::Client.as_admin) }

        let(:project) { create(:project, :with_readme, name: 'approve-and-merge') }

        before do
          group_or_project.add_member(approver, Resource::Members::AccessLevel::MAINTAINER)

          Flow::Login.sign_in

          project.visit!
        end

        context 'and the code owner is the root group' do
          let(:codeowner) { project.group.sandbox.path }
          let(:group_or_project) { project.group.sandbox }

          context 'with quarantine test 1',
            quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/20565', type: :investigating } do
            it_behaves_like 'code owner merge request'
          end
        end

        context 'and the code owner is the subgroup' do
          let(:codeowner) { project.group.full_path }
          let(:group_or_project) { project.group }

          context 'with quarantine test 2',
            quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/20565', type: :investigating } do
            it_behaves_like 'code owner merge request'
          end
        end

        context 'and the code owner is a user' do
          let(:codeowner) { approver.username }
          let(:group_or_project) { project }

          context 'with quarantine test 3',
            quarantine: { issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/20565', type: :investigating } do
            it_behaves_like 'code owner merge request'
          end
        end
      end
    end
  end
end
