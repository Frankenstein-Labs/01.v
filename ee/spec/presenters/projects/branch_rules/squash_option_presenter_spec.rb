# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::BranchRules::SquashOptionPresenter, feature_category: :source_code_management do
  describe '#help_text' do
    subject { described_class.new(squash_option).help_text }

    using RSpec::Parameterized::TableSyntax

    where(:option, :expected_help_text) do
      'never'       | 'Squashing is never performed and the checkbox is hidden.'
      'always'      | 'Squashing is always performed. Checkbox is visible and selected, and users cannot change it.'
      'default_on'  | 'Checkbox is visible and selected by default.'
      'default_off' | 'Checkbox is visible and unselected by default.'
    end

    with_them do
      let(:squash_option) { build(:branch_rule_squash_option, squash_option: option) }

      it { is_expected.to eq(expected_help_text) }
    end
  end
end
