# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Notes, :aggregate_failures, feature_category: :portfolio_management do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :public) }
  let(:private_user) { create(:user) }

  before_all do
    project.add_reporter(user)
  end

  context "when noteable is an Epic" do
    let_it_be(:group, freeze: false) { create(:group, :public) }
    let(:epic) { create(:epic, group: group, author: user) }
    let!(:epic_note) { create(:note, noteable: epic, project: project, author: user) }

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(epics: true)
    end

    it_behaves_like "noteable API with confidential notes", 'groups', 'epics', 'id' do
      let(:parent) { group }
      let(:noteable) { epic }
      let(:note) { epic_note }
    end

    context 'when epic is locked' do
      let(:params) { { body: 'hi!' } }

      before do
        epic.work_item.update!(discussion_locked: true)
      end

      it 'creates a new note when user is a group member' do
        post api("/groups/#{group.id}/epics/#{epic.id}/notes", user), params: params

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['body']).to eq('hi!')
        expect(json_response['author']['username']).to eq(user.username)
      end

      it 'does not create a new note when user is not a group member' do
        post api("/groups/#{group.id}/epics/#{epic.id}/notes", private_user), params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when issue was promoted to epic' do
      let_it_be(:owner, freeze: false) { create(:group_member, :owner, user: create(:user), group: group).user }
      let_it_be(:reporter, freeze: false) { create(:group_member, :reporter, user: create(:user), group: group).user }
      let_it_be(:guest, freeze: false) { create(:group_member, :guest, user: create(:user), group: group).user }
      let_it_be(:promoted_issue_epic, freeze: false) do
        create(:epic, group: group, author: owner, created_at: 1.day.ago)
      end

      let_it_be(:previous_note, freeze: false) do
        create(:note, :system, noteable: promoted_issue_epic, created_at: 2.days.ago)
      end

      let_it_be(:previous_note2, freeze: false) do
        create(:note, :system, noteable: promoted_issue_epic, created_at: 2.minutes.ago)
      end

      let_it_be(:epic_note, freeze: false) { create(:note, noteable: promoted_issue_epic, author: owner) }

      context 'when user is reporter' do
        it 'returns previous issue system notes' do
          get api("/groups/#{group.id}/epics/#{promoted_issue_epic.id}/notes", reporter)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(3)
        end
      end

      context 'when user is guest' do
        it 'does not return previous issue system notes' do
          get api("/groups/#{group.id}/epics/#{promoted_issue_epic.id}/notes", guest)

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to include_pagination_headers
          expect(json_response).to be_an Array
          expect(json_response.size).to eq(2)
        end
      end
    end

    describe 'epic to work item translation' do
      shared_examples "epic noteable response" do |status|
        it 'presents noteable_type as epic and noteable_id as epic id' do
          expect(response).to have_gitlab_http_status(status)
          expect(json_response['noteable_type']).to eq('Epic')
          expect(json_response['noteable_id']).to eq(epic.id)
          expect(json_response['noteable_work_item_id']).to eq(epic.issue_id)
        end
      end

      it 'presents noteable_type as Epic and noteable_id as epic id' do
        get api("/groups/#{group.id}/epics/#{epic.id}/notes", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an Array
        note_response = json_response.detect { |n| n['id'] == epic_note.id }
        expect(note_response['noteable_type']).to eq('Epic')
        expect(note_response['noteable_id']).to eq(epic.id)
        expect(note_response['noteable_work_item_id']).to eq(epic.issue_id)
      end

      context 'for single note' do
        before do
          get api("/groups/#{group.id}/epics/#{epic.id}/notes/#{epic_note.id}", user)
        end

        it_behaves_like 'epic noteable response', :ok
      end

      context 'for created note' do
        before do
          post api("/groups/#{group.id}/epics/#{epic.id}/notes", user), params: { body: 'test note' }
        end

        it_behaves_like 'epic noteable response', :created
      end

      context 'for updated note' do
        before do
          put api("/groups/#{group.id}/epics/#{epic.id}/notes/#{epic_note.id}", user), params: { body: 'updated' }
        end

        it_behaves_like 'epic noteable response', :ok
      end
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it_behaves_like 'forbids quick actions for ai_workflows scope' do
        let(:method) { :post }
        let(:url) { "/groups/#{group.id}/epics/#{epic.id}/notes" }
        let(:field) { :body }
        let(:success_status) { :created }
        let(:quick_action_success_status) { :accepted }
      end
    end

    describe 'granular token permissions for epic notes' do
      let(:url) { "/groups/#{group.id}/epics/#{epic.id}/notes" }
      let(:note_url) { "/groups/#{group.id}/epics/#{epic.id}/notes/#{epic_note.id}" }

      it_behaves_like 'authorizing granular token permissions', :read_epic_note do
        let(:boundary_object) { group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :read_epic_note do
        let(:boundary_object) { group }
        let(:request) do
          get api(note_url, personal_access_token: pat)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_epic_note do
        let(:boundary_object) { group }
        let(:request) do
          post api(url, personal_access_token: pat), params: { body: 'Test note' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :update_epic_note do
        let(:boundary_object) { group }
        let(:request) do
          put api(note_url, personal_access_token: pat), params: { body: 'Updated note' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :delete_epic_note do
        let(:boundary_object) { group }
        let(:request) do
          delete api(note_url, personal_access_token: pat)
        end
      end
    end
  end

  context "when noteable is a WikiPage::Meta for a group wiki" do
    let(:group) { create(:group, :public) }
    let!(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }
    let!(:wiki_page_meta_note) { create(:note, noteable: wiki_page_meta, namespace: group, project: nil, author: user) }

    before do
      group.add_owner(user)
      stub_licensed_features(group_wikis: true)
    end

    describe 'granular token permissions for group wiki page notes' do
      let(:url) { "/groups/#{group.id}/wiki_pages/#{wiki_page_meta.id}/notes" }
      let(:note_url) { "/groups/#{group.id}/wiki_pages/#{wiki_page_meta.id}/notes/#{wiki_page_meta_note.id}" }

      it_behaves_like 'authorizing granular token permissions', :read_wiki_page_meta_note do
        let(:boundary_object) { group }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :read_wiki_page_meta_note do
        let(:boundary_object) { group }
        let(:request) do
          get api(note_url, personal_access_token: pat)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_wiki_page_meta_note do
        let(:boundary_object) { group }
        let(:request) do
          post api(url, personal_access_token: pat), params: { body: 'Test note' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :update_wiki_page_meta_note do
        let(:boundary_object) { group }
        let(:request) do
          put api(note_url, personal_access_token: pat), params: { body: 'Updated note' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :delete_wiki_page_meta_note do
        let(:boundary_object) { group }
        let(:request) do
          delete api(note_url, personal_access_token: pat)
        end
      end
    end

    it_behaves_like "noteable API", 'groups', 'wiki_pages', 'id' do
      let(:parent) { group }
      let(:noteable) { wiki_page_meta }
      let(:note) { wiki_page_meta_note }
    end
  end

  context "when noteable is a Vulnerability" do
    let_it_be(:vulnerability, freeze: false) { create(:vulnerability, :with_finding, project: project) }
    let_it_be(:vulnerability_note, freeze: false) do
      create(:note, noteable: vulnerability, project: project, author: user)
    end

    before_all do
      project.add_developer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    describe 'granular token permissions for vulnerability notes' do
      let(:url) { "/projects/#{project.id}/vulnerabilities/#{vulnerability.id}/notes" }
      let(:note_url) { "#{url}/#{vulnerability_note.id}" }

      it_behaves_like 'authorizing granular token permissions', :read_vulnerability_note do
        let(:boundary_object) { project }
        let(:request) do
          get api(url, personal_access_token: pat)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :read_vulnerability_note do
        let(:boundary_object) { project }
        let(:request) do
          get api(note_url, personal_access_token: pat)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_vulnerability_note do
        let(:boundary_object) { project }
        let(:request) do
          post api(url, personal_access_token: pat), params: { body: 'Test note' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :update_vulnerability_note do
        let(:boundary_object) { project }
        let(:request) do
          put api(note_url, personal_access_token: pat), params: { body: 'Updated note' }
        end
      end

      it_behaves_like 'authorizing granular token permissions', :delete_vulnerability_note do
        let(:boundary_object) { project }
        let(:request) do
          delete api(note_url, personal_access_token: pat)
        end
      end
    end
  end

  context "when noteable is an Issue" do
    let_it_be(:issue, freeze: false) { create(:issue, project: project, author: user) }
    let_it_be(:issue_note, freeze: false) { create(:note, noteable: issue, project: project, author: user) }

    it_behaves_like "composite identity attribution"

    context 'when authenticated with a token that has the ai_workflows scope' do
      it_behaves_like 'forbids quick actions for ai_workflows scope' do
        let(:method) { :post }
        let(:url) { "/projects/#{project.id}/issues/#{issue.iid}/notes" }
        let(:field) { :body }
        let(:success_status) { :created }
        let(:quick_action_success_status) { :accepted }
      end
    end

    it 'does not present noteable_work_item_id' do
      get api("/projects/#{project.id}/issues/#{issue.iid}/notes", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.first).not_to include('noteable_work_item_id')
    end
  end

  context "when noteable is an Merge Request" do
    let_it_be(:merge_request, freeze: false) do
      create(:merge_request, source_project: project, target_project: project, author: user)
    end

    context 'when authenticated with a token that has the ai_workflows scope' do
      it_behaves_like 'forbids quick actions for ai_workflows scope' do
        let(:method) { :post }
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/notes" }
        let(:field) { :body }
        let(:success_status) { :created }
        let(:quick_action_success_status) { :accepted }
      end
    end
  end
end
