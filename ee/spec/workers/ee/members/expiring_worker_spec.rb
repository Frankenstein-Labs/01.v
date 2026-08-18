# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::ExpiringWorker, type: :worker, feature_category: :system_access do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:group) { create(:group_with_plan, plan: :ultimate_plan) }
    let(:expiring_7_days_group_member) { create(:group_member, :guest, group: group, expires_at: 7.days.from_now) }

    let(:expiring_7_days_minimal_access_group_member) do
      create(
        :group_member,
        :guest,
        group: group,
        access_level: Gitlab::Access::MINIMAL_ACCESS,
        expires_at: 7.days.from_now
      )
    end

    let(:notify_worker) { Members::ExpiringEmailNotificationWorker }

    before do
      allow(Gitlab).to receive(:com?).and_return(true)
      stub_licensed_features(minimal_access_role: true)
      allow(group).to receive(:feature_available?).and_return(true) # stub out the minimal_access feature
    end

    it "notifies only active users with membership expiring in less than 7 days" do
      expect(notify_worker).to receive(:perform_async).with(expiring_7_days_group_member.id)

      expect(notify_worker).not_to receive(:perform_async).with(expiring_7_days_minimal_access_group_member.id)

      worker.perform
    end
  end
end
