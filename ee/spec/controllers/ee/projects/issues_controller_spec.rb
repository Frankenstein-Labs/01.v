# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::IssuesController, feature_category: :team_planning do
  let_it_be_with_reload(:namespace) { create(:group, :public) }
  let_it_be_with_reload(:project) { create(:project_empty_repo, :public, namespace: namespace) }
  let_it_be_with_reload(:user) { create(:user) }

  describe 'licensed features' do
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:user) { create(:user) }
    let(:epic) { create(:epic, group: namespace) }
    let(:issue) { create(:issue, project: project, weight: 5) }
    let(:issue2) { create(:issue, project: project, weight: 1) }
    let(:new_issue) { build(:issue, project: project, weight: 5) }

    before do
      namespace.add_developer(user)
      sign_in(user)
    end

    def perform(method, action, opts = {})
      send(method, action, params: opts.merge(namespace_id: project.namespace.to_param, project_id: project.to_param))
    end

    context 'licensed' do
      before do
        stub_licensed_features(issue_weights: true, epics: true)
      end

      describe '#index' do
        shared_examples 'epic parameter rewrite' do |path_helper|
          let_it_be(:group) { create(:group) }
          let_it_be(:project_with_group_parent) { create(:project, group: group) }
          let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }

          let(:redirect_path) { path_helper }

          before do
            sign_in user
            project_with_group_parent.add_developer(user) # -- Does not work in before_all
          end

          def expected_params(params)
            params.except("type", "type[]")
          end

          it 'rewrites the epic_id param' do
            get :index, params: { namespace_id: project_with_group_parent.namespace, project_id: project_with_group_parent, epic_id: epic.id }
            expect(response).to redirect_to send(redirect_path, project_with_group_parent, params: expected_params({ parent_id: epic.work_item.id }))

            get :index, params: { namespace_id: project_with_group_parent.namespace, project_id: project_with_group_parent, epic_id: 'NONE' }
            expect(response).to redirect_to send(redirect_path, project_with_group_parent, params: expected_params({ parent_id: 'NONE' }))
          end

          it 'rewrites the not epic_id param' do
            get :index, params: { namespace_id: project_with_group_parent.namespace, project_id: project_with_group_parent, not: { epic_id: epic.id } }
            expect(response).to redirect_to send(redirect_path, project_with_group_parent, params: expected_params({ not: { parent_id: epic.work_item.id } }))
          end

          it 'rewrites the epic_wildcard_id param' do
            get :index, params: { namespace_id: project_with_group_parent.namespace, project_id: project_with_group_parent, epic_wildcard_id: 'ANY' }
            expect(response).to redirect_to send(redirect_path, project_with_group_parent, params: expected_params({ parent_wildcard_id: 'ANY' }))
          end
        end

        it_behaves_like 'epic parameter rewrite', :project_work_items_path
      end

      context 'when user can generate description' do
        before do
          allow(controller).to receive(:push_licensed_feature)
          allow(controller).to receive(:can?).and_call_original
          allow(controller).to receive(:can?).with(anything, :generate_description, anything).and_return(true)
        end

        describe 'generate_description feature' do
          describe 'GET #show' do
            let(:issue) { create(:issue, project: project) }

            it 'redirects to work item' do
              get :show, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }
              expect(response).to redirect_to project_work_item_path(project, issue.iid)
            end
          end
        end
      end

      describe '#update' do
        it 'sets issue weight and epic' do
          perform :put, :update, id: issue.to_param, issue: { weight: 6, epic_id: epic.id }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(issue.reload.weight).to eq(6)
          expect(issue.epic).to eq(epic)
        end
      end

      shared_examples 'creates vulnerability issue link' do
        it 'links the issue to the vulnerability' do
          send_request

          expect(project.issues.last.vulnerability_links.first.vulnerability).to eq(vulnerability)
        end

        context 'when vulnerability already has a linked issue' do
          render_views

          let!(:vulnerabilities_issue_link) { create(:vulnerabilities_issue_link, :created, vulnerability: vulnerability) }

          it 'shows an error message' do
            send_request

            expect(flash[:raw]).to include('id="js-unable-to-link-vulnerability"')
            expect(flash[:raw]).to include("data-vulnerability-link=\"/#{namespace.path}/#{project.path}/-/security/vulnerabilities/#{vulnerabilities_issue_link.vulnerability.id}\"")

            expect(vulnerability.issue_links.map(&:issue)).to eq([vulnerabilities_issue_link.issue])
          end
        end
      end

      describe '#create' do
        it 'sets issue weight and epic' do
          perform :post, :create, issue: new_issue.attributes.merge(epic_id: epic.id)

          project_issues = Issue.where.not(project: nil)
          issue = project_issues.first

          expect(response).to have_gitlab_http_status(:found)
          expect(project_issues.count).to eq(1)

          expect(issue.weight).to eq(new_issue.weight)
          expect(issue.epic).to eq(epic)
        end

        context 'when created from a vulnerability' do
          let(:finding) { create(:vulnerabilities_finding, :with_pipeline) }
          let(:vulnerability) { create(:vulnerability, project: project, findings: [finding]) }

          before do
            stub_licensed_features(security_dashboard: true)
            namespace.add_maintainer(user)
          end

          it 'overwrites the default fields' do
            send_request

            issue = project.issues.last
            expect(issue.title).to eq('Title')
            expect(issue.description).to eq('Description')
            expect(issue.confidential).to be false
          end

          it 'does not show an error message' do
            expect(flash[:alert]).to be_nil
          end

          it 'creates vulnerability feedback' do
            send_request

            expect(project.issues.last).to eq(Vulnerabilities::Feedback.last.issue)
          end

          it_behaves_like 'creates vulnerability issue link'

          private

          def send_request
            post :create, params: {
              namespace_id: project.namespace.to_param,
              project_id: project,
              issue: { title: 'Title', description: 'Description', confidential: 'false' },
              vulnerability_id: vulnerability.id
            }
          end
        end
      end
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(issue_weights: false, epics: false, security_dashboard: false)
      end

      describe '#update' do
        it 'does not set issue weight' do
          perform :put, :update, id: issue.to_param, issue: { weight: 6 }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(issue.reload.weight).to be_nil
          expect(issue.reload.read_attribute(:weight)).to eq(5) # pre-existing data is not overwritten
        end
      end

      describe '#create' do
        it 'does not set issue weight ane epic' do
          perform :post, :create, issue: new_issue.attributes

          expect(response).to have_gitlab_http_status(:found)
          expect(Issue.count).to eq(1)

          issue = Issue.first
          expect(issue.weight).to be_nil
          expect(issue.epic).to be_nil
        end
      end
    end
  end

  describe '#new' do
    before do
      sign_in user
    end

    it 'redirects to new work item' do
      get :new, params: { namespace_id: project.namespace, project_id: project }

      expect(response).to redirect_to new_project_work_item_url(project)
    end
  end

  describe 'GET #show' do
    before do
      project.add_developer(user)
      sign_in(user)
      stub_licensed_features(okrs: true)
    end

    shared_examples 'redirects to show work item page' do
      it 'redirects to work item page using iid' do
        make_request

        expect(response).to redirect_to(project_work_item_path(project, work_item.iid, query))
      end
    end

    context 'when issue is of type objective' do
      let(:query) { {} }

      let_it_be(:work_item) { create(:issue, :objective, project: project) }

      context 'show action' do
        let(:query) { { query: 'any' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :show, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, **query }
          end
        end
      end

      context 'edit action' do
        let(:query) { { query: 'any', edit: 'true' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :edit, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, query: 'any' }
          end
        end
      end

      context 'update action' do
        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            put :update, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: work_item.iid,
              issue: { title: 'New title' }
            }
          end
        end
      end
    end

    context 'when issue is of type key_result' do
      let(:query) { {} }

      let_it_be(:work_item) { create(:issue, :key_result, project: project) }

      context 'show action' do
        let(:query) { { query: 'any' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :show, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, **query }
          end
        end
      end

      context 'edit action' do
        let(:query) { { query: 'any', edit: 'true' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :edit, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, query: 'any' }
          end
        end
      end

      context 'update action' do
        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            put :update, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: work_item.iid,
              issue: { title: 'New title' }
            }
          end
        end
      end
    end
  end

  describe 'GET #discussions' do
    let(:issue) { create(:issue, project: project) }
    let!(:discussion) { create(:discussion_note_on_issue, noteable: issue, project: issue.project) }

    context 'with a related system note' do
      let(:confidential_issue) { create(:issue, :confidential, project: project) }
      let!(:system_note) { SystemNoteService.relate_issuable(issue, confidential_issue, user) }

      shared_examples 'user can see confidential issue' do |access_level|
        context "when a user is a #{access_level}" do
          before do
            project.add_member(user, access_level)
          end

          it 'displays related notes' do
            get :discussions, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

            discussions = json_response
            notes = discussions.flat_map { |d| d['notes'] }

            expect(discussions.count).to equal(2)
            expect(notes).to include(a_hash_including('id' => system_note.id.to_s))
          end
        end
      end

      shared_examples 'user cannot see confidential issue' do |access_level|
        context "when a user is a #{access_level}" do
          before do
            project.add_member(user, access_level)
          end

          it 'redacts note related to a confidential issue' do
            get :discussions, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

            discussions = json_response
            notes = discussions.flat_map { |d| d['notes'] }

            expect(discussions.count).to equal(1)
            expect(notes).not_to include(a_hash_including('id' => system_note.id.to_s))
          end
        end
      end

      context 'when authenticated' do
        before do
          sign_in(user)
        end

        %i[reporter developer maintainer].each do |access|
          it_behaves_like 'user can see confidential issue', access
        end

        it_behaves_like 'user cannot see confidential issue', :guest
      end

      context 'when unauthenticated' do
        let(:project) { create(:project, :public) }

        it_behaves_like 'user cannot see confidential issue', Gitlab::Access::NO_ACCESS
      end
    end
  end

  describe 'PUT #update' do
    let(:issue) { create(:issue, project: project) }

    def update_issue(issue_params: {}, additional_params: {}, id: nil)
      id ||= issue.iid
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: id,
        issue: { title: 'New title' }.merge(issue_params),
        format: :json
      }.merge(additional_params)

      put :update, params: params
    end

    context 'when changing the assignee' do
      let(:assignee) { create(:user) }

      before do
        project.add_developer(assignee)
        sign_in(assignee)
      end

      it 'exposes expected attributes' do
        update_issue(issue_params: { assignee_ids: [assignee.id] })

        expect(json_response['assignees'].first.keys)
          .to match_array(%w[id name username public_email avatar_url state locked web_url])
      end
    end
  end

  describe 'DescriptionDiffActions' do
    let_it_be(:project) { create(:project_empty_repo, :public) }

    context 'when issuable is an issue type issue' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:issue, project: project) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
      end
    end

    context 'when issuable is a task/work_item' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:issue, :task, project: project) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
      end
    end
  end
end
