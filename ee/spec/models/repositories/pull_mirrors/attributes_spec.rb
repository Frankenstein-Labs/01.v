# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::PullMirrors::Attributes, feature_category: :source_code_management do
  subject(:attributes) { described_class.new(attrs) }

  let(:attrs) do
    {
      import_url: 'https://example.com',
      mirror: true
    }
  end

  describe '#allowed' do
    subject { attributes.allowed }

    it { is_expected.to eq(attrs) }

    context 'when an unsupported attribute is provided' do
      let(:attrs) { super().merge(unknown: :attribute) }

      it 'returns only allowed attributes' do
        is_expected.to eq(import_url: 'https://example.com', mirror: true)
      end
    end

    context 'when mirror_branch_regex is provided' do
      let(:attrs) { super().merge(mirror_branch_regex: 'regex') }

      it 'sets mirror_branch_regex and disables only_mirror_protected_branches' do
        is_expected.to include(mirror_branch_regex: 'regex', only_mirror_protected_branches: false)
      end
    end

    context 'when only_mirror_protected_branches is provided' do
      let(:attrs) { super().merge(only_mirror_protected_branches: true) }

      it 'sets "only_mirror_protected_branches" value and disables mirror_branch_regex' do
        is_expected.to include(mirror_branch_regex: nil, only_mirror_protected_branches: true)
      end
    end

    context 'when both mirror_branch_regex and only_mirror_protected_branches are provided' do
      let(:attrs) { super().merge(only_mirror_protected_branches: true, mirror_branch_regex: 'regex') }

      it 'prefers "mirror_branch_regex"' do
        is_expected.to include(
          mirror_branch_regex: 'regex',
          only_mirror_protected_branches: false
        )
      end
    end
  end

  describe '#keys' do
    subject { attributes.keys }

    it 'returns a list of allowed keys' do
      is_expected.to include(*described_class::ALLOWED_ATTRIBUTES)
    end
  end
end
