# frozen_string_literal: true

require 'spec_helper'
require_relative 'anthropic_shared_examples'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeSonnet, feature_category: :code_suggestions do
  it_behaves_like 'anthropic code completion' do
    let(:model_name) { 'claude-sonnet-4-20250514' }
  end
end
