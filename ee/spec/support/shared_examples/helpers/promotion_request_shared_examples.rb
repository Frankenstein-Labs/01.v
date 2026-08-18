# frozen_string_literal: true

RSpec.shared_examples 'adding promotion_request in app data' do
  context 'when the feature is enabled' do
    let!(:pending_members_count) { 2 }

    before do
      allow(helper).to receive(:member_promotion_management_enabled?).and_return(true)
    end

    it 'returns `promotion_request_count` property with nil' do
      expect(helper_app_data[:promotion_request]).to include({ enabled: true, total_items: 2 })
    end
  end

  context 'when the feature is disabled' do
    let!(:pending_members_count) { nil }

    before do
      allow(helper).to receive(:member_promotion_management_enabled?).and_return(false)
    end

    it 'returns `promotion_request_count` property with nil' do
      expect(helper_app_data[:promotion_request]).to include({ enabled: false, total_items: nil })
    end
  end
end
