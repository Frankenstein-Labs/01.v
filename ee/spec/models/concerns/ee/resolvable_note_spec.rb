# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Note, ResolvableNote, feature_category: :code_review_workflow do
  describe '.resolvable_types' do
    specify do
      expect(described_class.resolvable_types).to eq(
        described_class::RESOLVABLE_TYPES + EE::ResolvableNote::EE_RESOLVABLE_TYPES
      )
    end
  end
end
