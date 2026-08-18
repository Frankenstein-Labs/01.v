# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::PersonalAccessTokenCreator, feature_category: :workspaces do
  include ResultMatchers

  include_context 'with remote development shared fixtures'

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let(:workspace_name) { "workspace-example_agent_id-example_user_id-example_random_string" }
  let(:params) do
    {
      project: project
    }
  end

  let(:context) do
    {
      params: params,
      user: user,
      workspace_name: workspace_name
    }
  end

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- we are testing validation, we don't want an exception
  end

  context 'when personal access token creation is successful' do
    it 'returns ok result containing successful message with created token' do
      expect { result }.to change { user.personal_access_tokens.count }

      expect(result).to be_ok_result do |message|
        message => { personal_access_token: PersonalAccessToken => personal_access_token }
        expect(personal_access_token).to eq(user.personal_access_tokens.reload.last)
        expect(personal_access_token.description).to eq(
          'Generated automatically for this workspace. ' \
            'Revoking this token will make your workspace completely unusable.'
        )
      end
    end

    context 'when instance has a shorter max_personal_access_token_lifetime' do
      before do
        stub_application_setting(max_personal_access_token_lifetime: 90)
        stub_licensed_features(personal_access_token_expiration_policy: true)
      end

      it 'creates a PAT with expiry respecting the instance limit' do
        expect { result }.to change { user.personal_access_tokens.count }

        expect(result).to be_ok_result do |message|
          message => { personal_access_token: PersonalAccessToken => personal_access_token }
          expect(personal_access_token.expires_at).to be <= (Date.current + 90)
        end
      end
    end
  end

  context 'when personal access token creation fails' do
    before do
      invalid_token_expiration_lifetime_in_hours =
        ((PersonalAccessToken.new.send(:max_expiration_lifetime_in_days) + 1) * 24).hours
      allow(described_class)
        .to receive(:max_allowed_personal_access_token_expires_at)
              .with(user)
              .and_return(invalid_token_expiration_lifetime_in_hours.from_now.to_date)
    end

    it 'returns an error result containing a failed message with model errors' do
      expect { result }.not_to change { user.personal_access_tokens.count }

      expect(result).to be_err_result do |message|
        expect(message).to be_a(RemoteDevelopment::Messages::PersonalAccessTokenModelCreateFailed)
        message.content => { errors: ActiveModel::Errors => errors }
        expect(errors.full_messages).to match([/expiration date/i])
      end
    end
  end
end
