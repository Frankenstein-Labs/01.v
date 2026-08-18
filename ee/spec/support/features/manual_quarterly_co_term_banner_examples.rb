# frozen_string_literal: true

RSpec.shared_examples 'manual quarterly co-term banner' do |path_to_visit:|
  shared_examples 'a visible manual quarterly co-term banner' do
    it 'displays a banner' do
      expect(page).to have_selector('[data-testid="manual-quarterly-co-term-banner"]')
    end
  end

  shared_examples 'a hidden manual quarterly co-term banner' do
    it 'does not display a banner' do
      expect(page).not_to have_selector('[data-testid="manual-quarterly-co-term-banner"]')
    end
  end

  describe 'manual quarterly co-term banner', :js do
    let_it_be(:reminder_days) { Gitlab::ManualQuarterlyCoTermBanner::REMINDER_DAYS }

    before do
      stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions_enabled)

      create_current_license(
        cloud_licensing_enabled: true,
        offline_cloud_licensing_enabled: true,
        seat_reconciliation_enabled: true
      )

      create(:upcoming_reconciliation, type, next_reconciliation_date: reconciliation_date)

      visit(send(path_to_visit))
    end

    context 'when gitlab_com_subscriptions saas feature is available' do
      let(:reconciliation_date) { Date.current }
      let(:gitlab_com_subscriptions_enabled) { true }
      let(:type) { :saas }

      it_behaves_like 'a hidden manual quarterly co-term banner'
    end

    context 'when gitlab_com_subscriptions saas feature is not available' do
      let(:gitlab_com_subscriptions_enabled) { false }
      let(:type) { :self_managed }

      context 'when reconciliation is upcoming' do
        context 'within notification window' do
          let(:reconciliation_date) { Date.current + reminder_days }

          it_behaves_like 'a visible manual quarterly co-term banner'
        end

        context 'outside of notification window' do
          let(:reconciliation_date) { Date.tomorrow + reminder_days }

          it_behaves_like 'a hidden manual quarterly co-term banner'
        end
      end

      context 'when reconciliation date was passed' do
        let(:reconciliation_date) { Date.current }

        it_behaves_like 'a visible manual quarterly co-term banner'
      end

      context 'when reconciliation date is outside of the notification window' do
        let(:reconciliation_date) { 1.month.from_now.to_date }

        it_behaves_like 'a hidden manual quarterly co-term banner'
      end
    end
  end
end
