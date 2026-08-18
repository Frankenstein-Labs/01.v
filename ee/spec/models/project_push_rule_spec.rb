# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectPushRule, feature_category: :source_code_management do
  it_behaves_like 'a push ruleable model'

  describe 'associations' do
    it { is_expected.to belong_to(:project).required }
  end

  describe '#global?' do
    it 'returns false' do
      push_rule = build(:project_push_rule)

      expect(push_rule.global?).to be false
    end
  end

  describe '#available?' do
    let_it_be(:project) { create(:project) }
    let(:push_rule) { build(:project_push_rule, project: project) }

    context 'when feature is available' do
      before do
        stub_licensed_features(reject_unsigned_commits: true)
      end

      it 'returns true' do
        expect(push_rule.available?(:reject_unsigned_commits)).to be true
      end
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(reject_unsigned_commits: false)
      end

      it 'returns false' do
        expect(push_rule.available?(:reject_unsigned_commits)).to be false
      end
    end
  end
end
