# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::GenerateDescription, feature_category: :team_planning do
  describe '#to_prompt' do
    let(:content) { "I found a bug" }

    subject { described_class.new(content, template: template).to_prompt }

    context 'when template is not supplied' do
      let(:template) { nil }

      it { is_expected.not_to include "<template>" }

      it { is_expected.to include content }
    end

    context 'when a template is supplied' do
      let(:template) { "Reproduction steps: \n\n" }

      it { is_expected.to include template }

      it { is_expected.to include content }
    end
  end
end
