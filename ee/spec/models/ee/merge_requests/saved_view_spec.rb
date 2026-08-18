# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::SavedView, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  describe '.views_limit' do
    where(:licensed, :expected_limit) do
      true  | 100
      false | 5
    end

    with_them do
      it 'returns the limit for the license' do
        stub_licensed_features(increased_saved_views_limit: licensed)

        expect(described_class.views_limit).to eq(expected_limit)
      end
    end
  end

  describe 'views limit validation' do
    let_it_be(:user) { create(:user) }
    let_it_be(:existing_views) { create_list(:merge_request_saved_view, 5, user: user) }

    where(:licensed, :valid) do
      true  | true
      false | false
    end

    with_them do
      it 'enforces the limit for the license' do
        stub_licensed_features(increased_saved_views_limit: licensed)

        expect(build(:merge_request_saved_view, user: user).valid?).to eq(valid)
      end
    end
  end
end
