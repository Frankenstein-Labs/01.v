# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Snippet, feature_category: :source_code_management do
  describe '#repository_size_checker' do
    let(:checker) { subject.repository_size_checker }
    let(:current_size) { 60 }

    before do
      allow(subject.repository).to receive(:size).and_return(current_size)
    end

    context 'when snippet belongs to a project' do
      subject { build(:project_snippet, project: project) }

      let(:namespace) { build(:namespace) }
      let(:project) { build(:project, namespace: namespace) }

      include_examples 'size checker for snippet'
    end

    context 'when snippet without a project' do
      let(:namespace) { nil }

      include_examples 'size checker for snippet'
    end
  end

  describe '.by_repository_storage' do
    let_it_be(:snippet_in_default_storage) { create(:project_snippet, :repository) }
    let_it_be(:snippet_without_storage) { create(:project_snippet) }

    it 'filters snippet by repository storage name' do
      snippets = described_class.by_repository_storage("default")
      expect(snippets).to eq([snippet_in_default_storage])
    end
  end

  describe '.allowed_for_ip' do
    let_it_be(:current_ip) { '2.2.2.2' }

    # Group with valid IP range
    let_it_be(:valid_group) { create(:group) }
    let_it_be(:valid_ip_restriction) { create(:ip_restriction, group: valid_group, range: '10.0.0.0/22') }
    let_it_be(:snippet_with_valid_restriction) do
      create(:project_snippet, project: create(:project, group: valid_group))
    end

    # Group with PostgreSQL CIDR-invalid IP range
    # This range (1.1.1.1/22) is valid in networking terms and works with inet type,
    # but PostgreSQL considers it invalid for cidr type because it has bits set to right of mask.
    # We test this to ensure the inet casting handles it correctly.
    let_it_be(:non_cidr_compliant_group) { create(:group) }
    let_it_be(:non_cidr_compliant_restriction) do
      create(:ip_restriction, group: non_cidr_compliant_group, range: '1.1.1.1/22')
    end

    let_it_be(:snippet_with_non_cidr_restriction) do
      create(:project_snippet, project: create(:project, group: non_cidr_compliant_group))
    end

    # Group with multiple IP restrictions
    let_it_be(:multi_group) { create(:group) }
    let_it_be(:multi_restriction_1) { create(:ip_restriction, group: multi_group, range: '20.0.0.0/22') }
    let_it_be(:multi_restriction_2) { create(:ip_restriction, group: multi_group, range: '30.0.0.0/22') }
    let_it_be(:multi_restriction_3) { create(:ip_restriction, group: multi_group, range: '40.0.0.0/22') }
    let_it_be(:snippet_with_multi_restrictions) do
      create(:project_snippet, project: create(:project, group: multi_group))
    end

    # Group with specific IP
    let_it_be(:specific_group) { create(:group) }
    let_it_be(:specific_ip_restriction) { create(:ip_restriction, group: specific_group, range: '50.0.0.1') }
    let_it_be(:snippet_with_specific_ip) do
      create(:project_snippet, project: create(:project, group: specific_group))
    end

    # Snippet without any IP restrictions
    let_it_be(:snippet_without_restriction) { create(:project_snippet) }
    let_it_be(:personal_snippet) { create(:personal_snippet) }

    subject(:allowed_snippets) { described_class.allowed_for_ip(current_ip) }

    context 'when IP does not fall within any group range' do
      let(:current_ip) { '2.2.2.2' }

      it { is_expected.to contain_exactly(snippet_without_restriction, personal_snippet) }
    end

    context 'when IP falls within only non_cidr_restriction group range' do
      let(:current_ip) { '1.1.1.100' }

      it 'returns the expected snippets' do
        is_expected.to contain_exactly(snippet_without_restriction, personal_snippet, snippet_with_non_cidr_restriction)
      end
    end

    context 'when IP falls within only valid group range' do
      let(:current_ip) { '10.0.1.100' }

      it 'returns the expected snippets' do
        is_expected.to contain_exactly(snippet_without_restriction, personal_snippet, snippet_with_valid_restriction)
      end
    end

    context 'when IP falls within some of multiple restriction group range' do
      let(:current_ip) { '30.0.1.100' }

      it 'returns the expected snippets' do
        is_expected.to contain_exactly(snippet_without_restriction, personal_snippet, snippet_with_multi_restrictions)
      end
    end

    context 'when IP exactly matches specific IP restriction' do
      let(:current_ip) { '50.0.0.1' }

      it { is_expected.to contain_exactly(snippet_without_restriction, personal_snippet, snippet_with_specific_ip) }
    end

    context 'when the user IP falls within both non_cidr and valid group restrictions' do
      let_it_be(:valid_ip_restriction) { create(:ip_restriction, group: valid_group, range: '1.1.0.0/22') }
      let(:current_ip) { '1.1.1.100' }

      it 'returns the expected snippets' do
        expect(allowed_snippets).to include(snippet_with_non_cidr_restriction)
        expect(allowed_snippets).to include(snippet_with_valid_restriction)
        expect(allowed_snippets).not_to include(snippet_with_multi_restrictions)
        expect(allowed_snippets).not_to include(snippet_with_specific_ip)
        expect(allowed_snippets).to include(snippet_without_restriction)
        expect(allowed_snippets).to include(personal_snippet)
      end
    end
  end
end
