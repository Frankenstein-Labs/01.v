# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspacesController, feature_category: :workspaces do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  shared_examples 'remote development feature licensing' do |is_licensed, expected_status|
    before do
      stub_licensed_features(remote_development: is_licensed)
    end

    describe 'GET #index' do
      it "responds with status '#{expected_status}'" do
        get :index

        expect(response).to have_gitlab_http_status(expected_status)
      end
    end
  end

  context 'with remote development feature' do
    it_behaves_like 'remote development feature licensing', true, :ok
  end

  context 'with remote development not licensed' do
    before do
      stub_licensed_features(remote_development: false)
    end

    describe 'GET #index' do
      it 'responds with the not found status' do
        get :index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
