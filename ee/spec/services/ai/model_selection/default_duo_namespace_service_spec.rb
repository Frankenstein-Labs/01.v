# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::DefaultDuoNamespaceService, feature_category: :"self-hosted_models" do
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(user) }

  describe '#initialize' do
    it 'sets the user' do
      expect(service.send(:user)).to eq(user)
    end

    it 'sets current_user to the provided user' do
      expect(service.send(:current_user)).to eq(user)
    end
  end

  describe 'module inclusions' do
    it 'includes Gitlab::Utils::StrongMemoize' do
      expect(described_class.included_modules).to include(Gitlab::Utils::StrongMemoize)
    end

    it 'includes Ai::ModelSelection::SelectionApplicable' do
      expect(described_class.included_modules).to include(Ai::ModelSelection::SelectionApplicable)
    end
  end
end
