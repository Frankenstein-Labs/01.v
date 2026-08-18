# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ArtifactRegistry::TokenExchange, feature_category: :artifact_registry do
  let(:slug) { 'my-group' }
  let(:current_user) { Object.new }

  subject(:token_exchange) { described_class.new }

  describe '#token_for' do
    it 'returns no credential yet, since the real token exchange is not built' do
      expect(token_exchange.token_for(current_user, slug)).to be_nil
    end

    it 'accepts the (current_user, slug) call shape the client relies on', :aggregate_failures do
      expect { token_exchange.token_for(current_user, slug) }.not_to raise_error
      expect { token_exchange.token_for(nil, slug) }.not_to raise_error
    end
  end
end
