# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteMirrors::Attributes, feature_category: :source_code_management do
  subject(:attributes) { described_class.new(attrs) }

  let(:attrs) do
    {
      url: 'https://example.com',
      mirror_branch_regex: mirror_branch_regex,
      only_protected_branches: only_protected_branches
    }
  end

  let(:only_protected_branches) { true }
  let(:mirror_branch_regex) { nil }

  describe '#allowed' do
    subject { attributes.allowed }

    it { is_expected.to eq(attrs) }

    context 'when mirror_branch_regex is provided' do
      let(:mirror_branch_regex) { 'regex' }

      it 'sets "mirror_branch_regex" value and disables only_protected_branches' do
        is_expected.to include(mirror_branch_regex: mirror_branch_regex, only_protected_branches: false)
      end
    end

    context 'when both mirror_branch_regex and only_protected_branches are provided' do
      let(:mirror_branch_regex) { 'regex' }
      let(:only_protected_branches) { true }

      it 'prefers "mirror_branch_regex"' do
        is_expected.to include(
          mirror_branch_regex: mirror_branch_regex,
          only_protected_branches: false
        )
      end
    end
  end

  describe '#keys' do
    subject { attributes.keys }

    it 'returns a list of allowed keys' do
      is_expected.to include(*(described_class::ALLOWED_ATTRIBUTES + described_class::EE_ALLOWED_ATTRIBUTES))
    end
  end
end
