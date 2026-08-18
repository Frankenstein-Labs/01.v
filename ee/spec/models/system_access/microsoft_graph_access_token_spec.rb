# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemAccess::MicrosoftGraphAccessToken, feature_category: :system_access do
  it do
    is_expected
      .to belong_to(:system_access_microsoft_application)
            .inverse_of(:system_access_microsoft_graph_access_token)
  end

  it_behaves_like 'encrypted attribute', :token, :db_key_base_32 do
    let(:record) { create(:system_access_microsoft_graph_access_token) }
  end

  describe 'validations' do
    let_it_be(:graph_access_token) { create(:system_access_microsoft_graph_access_token) }

    it { is_expected.to validate_presence_of(:system_access_microsoft_application_id) }
    it { is_expected.to validate_presence_of(:expires_in) }
    it { is_expected.to validate_numericality_of(:expires_in).is_greater_than_or_equal_to(0) }
  end

  it 'has a bidirectional relationship' do
    application = create(:system_access_microsoft_application)
    token_obj = create(:system_access_microsoft_graph_access_token, system_access_microsoft_application: application)

    expect(token_obj.system_access_microsoft_application).to eq(application)
    expect(token_obj.system_access_microsoft_application.system_access_microsoft_graph_access_token).to eq(token_obj)
  end

  describe '#expired?' do
    it 'returns true for an unpersisted token' do
      access_token = build(:system_access_microsoft_graph_access_token)

      expect(access_token.expired?).to be(true)
    end

    context 'when the access token is persisted' do
      let_it_be(:access_token) { create(:system_access_microsoft_graph_access_token, expires_in: 7200) }

      it 'returns false when the token is not expired' do
        expect(access_token.expired?).to be(false)
      end

      it 'returns true when the token is expired' do
        travel_to(3.hours.from_now) do
          expect(access_token.expired?).to be(true)
        end
      end
    end
  end
end
