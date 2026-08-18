# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CiMinutesUsageMailer do
  include EmailSpec::Matchers

  let_it_be(:namespace) { create(:group) }
  let(:recipients) { %w[bob@example.com john@example.com] }

  shared_examples 'mail format' do
    it { is_expected.to have_subject subject_text }
    it { is_expected.to bcc_to recipients }
    it { is_expected.to have_body_text group_path(namespace) }
    it { is_expected.to have_body_text body_text }
  end

  describe '#notify' do
    let(:subject_text) do
      "Action required: There are no remaining compute minutes for #{namespace.name}"
    end

    let(:body_text) { "has reached its shared runner compute minutes quota" }

    subject { described_class.notify(namespace, recipients) }

    context 'when it is a group' do
      it_behaves_like 'mail format'

      it { is_expected.to have_body_text buy_minutes_subscriptions_url(selected_group: namespace.id) }
    end

    context 'when it is a namespace' do
      it_behaves_like 'mail format' do
        let_it_be(:namespace) { create(:namespace) }

        it { is_expected.to have_body_text ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url }
      end
    end
  end

  describe '#notify_limit' do
    let(:current_balance) { 2_025 }
    let(:total) { 10_000 }
    let(:percent) { 20.25 }
    let(:stage_percentage) { 25 }

    let(:subject_text) do
      "Action required: Less than #{stage_percentage}% of compute minutes remain for #{namespace.name}"
    end

    let(:body_text) { "has 2,025 / 10,000 (20%) shared runner compute minutes remaining" }

    subject { described_class.notify_limit(namespace, recipients, current_balance, total, percent, stage_percentage) }

    context 'when it is a group' do
      it_behaves_like 'mail format'
    end

    context 'when it is a namespace' do
      it_behaves_like 'mail format' do
        let_it_be(:namespace) { create(:namespace) }

        it { is_expected.to have_body_text ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url }
      end
    end
  end
end
