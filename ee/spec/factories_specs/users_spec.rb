# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE User factory', feature_category: :user_management do
  describe 'trait group_managed' do
    subject(:created_user) { create(:user, :group_managed) }

    it 'associates the user with a saml identity' do
      expect(created_user.group_saml_identities).not_to be_empty
      expect(
        created_user.group_saml_identities.first.saml_provider
      ).to eq(created_user.managing_group.saml_provider)
    end
  end
end
