# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NavHelper, feature_category: :navigation do
  let(:user) { build_stubbed(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#page_has_markdown?' do
    before do
      allow(helper).to receive(:current_path?).and_call_original
    end

    it 'returns true for epic show page' do
      allow(helper).to receive(:current_path?).with('epics#show').and_return(true)
      expect(helper.page_has_markdown?).to be_truthy
    end

    it 'returns false for non-markdown pages' do
      allow(helper).to receive(:current_path?).with('epics#show').and_return(false)

      expect(helper.page_has_markdown?).to be_falsey
    end
  end
end
