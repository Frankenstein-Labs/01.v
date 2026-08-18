# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserSettings::PersonalAccessTokensController, type: :request, feature_category: :shared do
  let(:user) { create(:enterprise_user, :with_namespace) }

  before do
    sign_in(user)
  end

  subject(:make_request) { get '/-/user_settings/personal_access_tokens' }

  context "when personal access tokens are disabled for enterprise users" do
    before do
      allow(user.enterprise_group).to receive(:disable_personal_access_tokens?).and_return(true)
      stub_licensed_features(disable_personal_access_tokens: true)
    end

    it 'returns not found' do
      make_request
      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  context "when personal access tokens are not disabled for enterprise users" do
    before do
      allow(user.enterprise_group).to receive(:disable_personal_access_tokens?).and_return(false)
      stub_licensed_features(disable_personal_access_tokens: true)
    end

    it 'render page' do
      make_request
      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end
