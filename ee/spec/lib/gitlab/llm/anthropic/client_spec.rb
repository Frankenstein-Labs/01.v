# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Client, feature_category: :ai_abstraction_layer do
  it_behaves_like 'anthropic client' do
    let(:unit_primitive) { :explain_vulnerability }
  end
end
