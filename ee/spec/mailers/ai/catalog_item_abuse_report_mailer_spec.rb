# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CatalogItemAbuseReportMailer, feature_category: :workflow_catalog do
  include EmailSpec::Matchers

  let_it_be(:reporter) { build_stubbed(:user, username: 'reporter_user') }
  let_it_be(:catalog_item) { build_stubbed(:ai_catalog_agent, name: 'Test Agent') }

  before do
    stub_application_setting(abuse_notification_email: 'admin@example.com')
    allow(User).to receive(:find_by_id).with(reporter.id).and_return(reporter)
    allow(Ai::Catalog::Item).to receive(:find_by_id).with(catalog_item.id).and_return(catalog_item)
  end

  describe '#notify' do
    let(:args) do
      {
        item_id: catalog_item.id,
        reason: 'Inappropriate content',
        message: 'This item contains offensive material'
      }
    end

    subject(:email) { described_class.notify(reporter.id, args) }

    context 'when all required parameters are present' do
      it { is_expected.to deliver_to 'admin@example.com' }
      it { is_expected.to have_subject "ATTENTION: #{catalog_item.name} flagged" }
      it { is_expected.to have_body_text 'Hello Admin' }
      it { is_expected.to have_body_text reporter.username }
      it { is_expected.to have_body_text catalog_item.name }
      it { is_expected.to have_body_text "(ID: #{catalog_item.id})" }
      it { is_expected.to have_body_text 'Inappropriate content' }
      it { is_expected.to have_body_text 'This item contains offensive material' }
      it { is_expected.to have_body_text 'aiCatalogAgentDelete' }

      it 'includes link to reporter' do
        expect(email.body.encoded).to include(Gitlab::Routing.url_helpers.user_url(reporter))
      end

      it 'includes link to catalog item' do
        catalog_item_url = Gitlab::UrlBuilder.build(catalog_item)
        expect(email.body.encoded).to include(catalog_item_url)
      end

      it 'includes catalog item URL in the correct format' do
        expected_url = "#{Settings.gitlab['url']}/explore/ai-catalog/agents/#{catalog_item.id}"
        expect(email.body.encoded).to include(expected_url)
      end

      it 'includes UI deletion instructions' do
        expect(email.body.encoded).to include('To delete the item from the UI:')
      end
    end

    context 'when message is not provided' do
      let(:args) do
        {
          item_id: catalog_item.id,
          reason: 'Spam'
        }
      end

      it { is_expected.to have_body_text 'Spam' }
      it { is_expected.not_to have_body_text 'This item contains offensive material' }
    end

    context 'when item is a flow' do
      let_it_be(:flow_item) { build_stubbed(:ai_catalog_flow) }

      let(:args) do
        {
          item_id: flow_item.id,
          reason: 'Inappropriate content'
        }
      end

      before do
        allow(Ai::Catalog::Item).to receive(:find_by_id).with(flow_item.id).and_return(flow_item)
      end

      it { is_expected.to have_body_text 'aiCatalogFlowDelete' }

      it 'includes flow URL in email body' do
        expected_url = "#{Settings.gitlab['url']}/explore/ai-catalog/flows/#{flow_item.id}"
        expect(email.body.encoded).to include(expected_url)
      end
    end

    context 'when item is a third_party_flow' do
      let_it_be(:third_party_flow_item) { build_stubbed(:ai_catalog_third_party_flow) }

      let(:args) do
        {
          item_id: third_party_flow_item.id,
          reason: 'Inappropriate content'
        }
      end

      before do
        allow(Ai::Catalog::Item).to receive(:find_by_id).with(third_party_flow_item.id)
          .and_return(third_party_flow_item)
      end

      it { is_expected.to have_body_text 'aiCatalogThirdPartyFlowDelete' }

      it 'includes third party flow URL in email body' do
        expected_url = "#{Settings.gitlab['url']}/explore/ai-catalog/agents/#{third_party_flow_item.id}"
        expect(email.body.encoded).to include(expected_url)
      end
    end

    context 'when user_id is missing' do
      before do
        allow(User).to receive(:find_by_id).with(nil).and_return(nil)
      end

      it 'does not send email' do
        expect { described_class.notify(nil, args).deliver_now }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when item_id is missing' do
      let(:args) { { reason: 'Spam' } }

      before do
        allow(Ai::Catalog::Item).to receive(:find_by_id).with(nil).and_return(nil)
      end

      it 'does not send email' do
        expect { described_class.notify(reporter.id, args).deliver_now }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when reason is missing' do
      let(:args) { { item_id: catalog_item.id } }

      it 'does not send email' do
        expect { described_class.notify(reporter.id, args).deliver_now }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    context 'when abuse_notification_email is not set' do
      before do
        stub_application_setting(abuse_notification_email: nil)
      end

      it 'does not send email' do
        expect { described_class.notify(reporter.id, args).deliver_now }
          .not_to change { ActionMailer::Base.deliveries.count }
      end
    end
  end
end
