# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::AwardEmoji, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be_with_reload(:epic) { create(:epic, group: group, author: user) }
  let_it_be_with_reload(:award_emoji) { create(:award_emoji, awardable: epic, user: user) }
  let_it_be_with_reload(:note) { create(:note, noteable: epic) }

  before do
    stub_licensed_features(epics: true)
  end

  describe "GET /groups/:id/awardable/:awardable_id/award_emoji" do
    context 'on an epic' do
      let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/award_emoji" }

      it "returns an array of award_emoji with epic-flavored response" do
        get api(request_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an Array
        expect(json_response.first['name']).to eq(award_emoji.name)
        expect(json_response.first['awardable_type']).to eq('Epic')
        expect(json_response.first['awardable_id']).to eq(epic.id)
        expect(json_response.first['awardable_work_item_id']).to eq(epic.issue_id)
      end

      context 'when award emoji points to the work item (post-backfill)' do
        before do
          award_emoji.update_columns(awardable_type: 'Issue', awardable_id: epic.issue_id)
        end

        it 'still returns epic-flavored response' do
          get api(request_path, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first['awardable_type']).to eq('Epic')
          expect(json_response.first['awardable_id']).to eq(epic.id)
          expect(json_response.first['awardable_work_item_id']).to eq(epic.issue_id)
        end
      end

      it "returns a 404 error when epic id not found" do
        get api("/groups/#{group.id}/epics/#{non_existing_record_iid}/award_emoji", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like 'authorizing granular token permissions', :read_epic_award_emoji do
        let(:boundary_object) { group }
        let(:request) do
          get api(request_path, personal_access_token: pat)
        end
      end
    end
  end

  describe 'GET /groups/:id/awardable/:awardable_id/notes/:note_id/award_emoji' do
    let!(:rocket) { create(:award_emoji, awardable: note, name: 'rocket') }
    let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/notes/#{note.id}/award_emoji" }

    it 'returns an array of award emoji' do
      get api(request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_an Array
      expect(json_response.first['name']).to eq(rocket.name)
    end

    it_behaves_like 'authorizing granular token permissions', :read_epic_note_award_emoji do
      let(:boundary_object) { group }
      let(:request) do
        get api(request_path, personal_access_token: pat)
      end
    end
  end

  describe "GET /groups/:id/awardable/:awardable_id/award_emoji/:award_id" do
    context 'on an epic' do
      let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/award_emoji/#{award_emoji.id}" }

      it "returns the award emoji with epic-flavored response" do
        get api(request_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['name']).to eq(award_emoji.name)
        expect(json_response['awardable_type']).to eq('Epic')
        expect(json_response['awardable_id']).to eq(epic.id)
        expect(json_response['awardable_work_item_id']).to eq(epic.issue_id)
      end

      context 'when award emoji points to the work item (post-backfill)' do
        before do
          award_emoji.update_columns(awardable_type: 'Issue', awardable_id: epic.issue_id)
        end

        it 'still returns epic-flavored response' do
          get api(request_path, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['awardable_type']).to eq('Epic')
          expect(json_response['awardable_id']).to eq(epic.id)
          expect(json_response['awardable_work_item_id']).to eq(epic.issue_id)
        end
      end

      it "returns a 404 error if the award is not found" do
        get api("/groups/#{group.id}/epics/#{epic.iid}/award_emoji/#{non_existing_record_id}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like 'authorizing granular token permissions', :read_epic_award_emoji do
        let(:boundary_object) { group }
        let(:request) do
          get api(request_path, personal_access_token: pat)
        end
      end
    end
  end

  describe 'GET /groups/:id/awardable/:awardable_id/notes/:note_id/award_emoji/:award_id' do
    let!(:rocket) { create(:award_emoji, awardable: note, name: 'rocket') }
    let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/notes/#{note.id}/award_emoji/#{rocket.id}" }

    it 'returns an award emoji' do
      get api(request_path, user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).not_to be_an Array
      expect(json_response['name']).to eq(rocket.name)
    end

    it_behaves_like 'authorizing granular token permissions', :read_epic_note_award_emoji do
      let(:boundary_object) { group }
      let(:request) do
        get api(request_path, personal_access_token: pat)
      end
    end
  end

  describe "POST /groups/:id/awardable/:awardable_id/award_emoji" do
    context "on an epic" do
      let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/award_emoji" }

      it "creates a new award emoji with epic-flavored response" do
        post api(request_path, user), params: { name: 'blowfish' }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['name']).to eq('blowfish')
        expect(json_response['user']['username']).to eq(user.username)
        expect(json_response['awardable_type']).to eq('Epic')
        expect(json_response['awardable_id']).to eq(epic.id)
        expect(json_response['awardable_work_item_id']).to eq(epic.issue_id)
      end

      it "returns a 400 bad request error if the name is not given" do
        post api(request_path, user)

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it "returns a 404 if the user is not authenticated" do
        post api(request_path), params: { name: AwardEmoji::THUMBS_UP }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it "normalizes +1 as thumbsup award" do
        post api(request_path, user), params: { name: '+1' }

        expect(epic.award_emoji.last.name).to eq(AwardEmoji::THUMBS_UP)
      end

      context 'when the emoji already has been awarded' do
        it 'returns a 404 status code' do
          post api(request_path, user), params: { name: AwardEmoji::THUMBS_UP }
          post api(request_path, user), params: { name: AwardEmoji::THUMBS_UP }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response["message"]).to match("has already been taken")
        end
      end

      it_behaves_like 'authorizing granular token permissions', :create_epic_award_emoji do
        let(:boundary_object) { group }
        let(:request) do
          post api(request_path, personal_access_token: pat), params: { name: 'blowfish' }
        end
      end
    end
  end

  describe "POST /groups/:id/awardable/:awardable_id/notes/:note_id/award_emoji" do
    let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/notes/#{note.id}/award_emoji" }
    let(:note2) { create(:note, noteable: epic, author: user) }

    it 'creates a new award emoji' do
      expect do
        post api(request_path, user), params: { name: 'rocket' }
      end.to change { note.award_emoji.count }.from(0).to(1)

      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['user']['username']).to eq(user.username)
    end

    it 'marks Todos on the Noteable as done' do
      todo = create(:todo, target: note2.noteable, group: group, user: user)

      post api(request_path, user), params: { name: 'rocket' }

      expect(todo.reload).to be_done
    end

    it "normalizes +1 as thumbsup award" do
      post api(request_path, user), params: { name: '+1' }

      expect(note.award_emoji.last.name).to eq(AwardEmoji::THUMBS_UP)
    end

    context 'when the emoji already has been awarded' do
      it 'returns a 404 status code' do
        post api(request_path, user), params: { name: 'rocket' }
        post api(request_path, user), params: { name: 'rocket' }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response["message"]).to match("has already been taken")
      end
    end

    it_behaves_like 'authorizing granular token permissions', :create_epic_note_award_emoji do
      let(:boundary_object) { group }
      let(:request) do
        post api(request_path, personal_access_token: pat), params: { name: 'rocket' }
      end
    end
  end

  describe 'DELETE /groups/:id/awardable/:awardable_id/award_emoji/:award_id' do
    context 'when the awardable is an Epic' do
      let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/award_emoji/#{award_emoji.id}" }

      it 'deletes the award' do
        expect do
          delete api(request_path, user)

          expect(response).to have_gitlab_http_status(:no_content)
        end.to change { epic.award_emoji.count }.from(1).to(0)
      end

      it 'returns a 404 error when the award emoji can not be found' do
        delete api("/groups/#{group.id}/epics/#{epic.iid}/award_emoji/#{non_existing_record_id}", user)

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like '412 response' do
        let(:request) { api(request_path, user) }
      end

      it_behaves_like 'authorizing granular token permissions', :delete_epic_award_emoji do
        let(:boundary_object) { group }
        let(:request) do
          delete api(request_path, personal_access_token: pat)
        end
      end
    end
  end

  describe 'DELETE /groups/:id/awardable/:awardable_id/notes/:note_id/award_emoji/:award_id' do
    let!(:rocket)  { create(:award_emoji, awardable: note, name: 'rocket', user: user) }
    let(:request_path) { "/groups/#{group.id}/epics/#{epic.iid}/notes/#{note.id}/award_emoji/#{rocket.id}" }

    it 'deletes the award' do
      expect do
        delete api(request_path, user)

        expect(response).to have_gitlab_http_status(:no_content)
      end.to change { note.award_emoji.count }.from(1).to(0)
    end

    it_behaves_like '412 response' do
      let(:request) { api(request_path, user) }
    end

    it_behaves_like 'authorizing granular token permissions', :delete_epic_note_award_emoji do
      let(:boundary_object) { group }
      let(:request) do
        delete api(request_path, personal_access_token: pat)
      end
    end
  end
end
