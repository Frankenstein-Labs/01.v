# frozen_string_literal: true

RSpec.shared_examples 'composite identity attribution' do
  let(:service_account) do
    create(:user, :service_account, composite_identity_enforced: true, organization: organization)
  end

  let(:oauth_app) { create(:doorkeeper_application) }
  let(:organization) { create(:organization) }
  let(:scopes) { ::Gitlab::Auth::AI_WORKFLOW_SCOPES + ['api'] + ["user:#{user.id}"] }

  let(:token) do
    create(:oauth_access_token, {
      organization: organization,
      application: oauth_app,
      resource_owner: service_account,
      expires_in: 1.hour,
      scopes: scopes
    })
  end

  let(:params) { { body: 'Hi!' } }

  before do
    project.add_developer(service_account)
    project.add_maintainer(user)
  end

  it 'attributes the note author to the service account' do
    post api("/projects/#{project.id}/issues/#{issue.iid}/notes", user, oauth_access_token: token), params: params
    expect(response).to have_gitlab_http_status(:created)

    note = Note.find(json_response['id'])
    expect(note.author.id).to eq(service_account.id)
  end

  it 'attributes note updates to the service account' do
    note = create(:note, project: project, noteable: issue, author: service_account)

    put api("/projects/#{project.id}/issues/#{issue.iid}/notes/#{note.id}", user, oauth_access_token: token),
      params: params
    expect(response).to have_gitlab_http_status(:ok)
    expect(note.reload.updated_by_id).to eq(service_account.id)
  end
end
