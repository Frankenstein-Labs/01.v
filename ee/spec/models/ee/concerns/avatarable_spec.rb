# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avatarable, feature_category: :shared do
  describe '#avatar_path' do
    context 'when the user is a security_policy_bot' do
      let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }
      let_it_be(:avatar_file) { ActionController::Base.helpers.image_path('bot_avatars/security-bot.png') }
      let_it_be(:image_path) { "#{Settings.gitlab.base_url}#{avatar_file}" }

      it 'returns the security_policy_bot static_avatar_path' do
        expect(security_policy_bot.avatar_path).to eq(image_path)
      end
    end
  end
end
