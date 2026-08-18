# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TransferPersonalService, feature_category: :groups_and_projects do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:organization, freeze: false) { create(:organization, users: [user]) }

  let_it_be(:user_namespace, freeze: false) do
    create(:user_namespace, name: 'user@example', path: 'userexample', owner: user, organization: organization)
  end

  let_it_be(:project, freeze: false) { create(:project, namespace: user_namespace) }

  let(:params) { { organization_id: organization.id } }

  subject(:service) do
    described_class.new(project, user, params)
  end

  it 'creates new group and transfers personal project there' do
    expect(service.execute).to be_success
    expect(project.namespace).to be_a(Group)
  end

  context 'when organization is not provided' do
    let(:params) { {} }

    it 'returns error response on group creation' do
      response = service.execute

      expect(response).to be_error
      expect(response.message).to be_present
    end
  end

  context 'when not project owner' do
    let_it_be(:project, freeze: false) { create(:project) }

    it 'returns error response on group creation' do
      response = service.execute

      expect(response).to be_error
      expect(response.message).to eq('Personal project cannot be transferred')
    end
  end
end
