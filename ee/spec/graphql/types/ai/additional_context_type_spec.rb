# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAdditionalContext'], feature_category: :duo_chat do
  describe '.authorization' do
    it 'allows ai_features scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features)
    end
  end
end
