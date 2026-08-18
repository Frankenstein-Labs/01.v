# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::CodeReview::Modes::Disabled, feature_category: :duo_code_review do
  subject(:mode) { described_class.new(user: user, container: container) }

  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:container) { project }

  describe '#mode' do
    it 'returns the mode name' do
      expect(mode.mode).to eq(:disabled)
    end
  end

  describe '#enabled?' do
    it 'always returns false' do
      expect(mode).not_to be_enabled
    end
  end

  describe '#active?' do
    it 'always returns true' do
      expect(mode).to be_active
    end
  end
end
