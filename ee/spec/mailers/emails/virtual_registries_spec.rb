# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Emails::VirtualRegistries, :aggregate_failures, feature_category: :virtual_registry do
  include EmailSpec::Matchers

  let(:group) { build_stubbed(:group) }
  let(:user) { build_stubbed(:user) }
  let(:policy) { build_stubbed(:virtual_registries_cleanup_policy, group:) }

  describe '#virtual_registry_cleanup_complete' do
    subject(:email) { Notify.virtual_registry_cleanup_complete(policy, user) }

    it_behaves_like 'it should not have Gmail Actions links'
    it_behaves_like 'a user cannot unsubscribe through footer link'
    it_behaves_like 'appearance header and footer enabled'
    it_behaves_like 'appearance header and footer not enabled'

    it 'sends mail with expected contents' do
      expect(email).to have_subject("Cache cleanup completed for #{group.name}")
      expect(email).to be_delivered_to([user.notification_email_or_default])
      expect(email).to have_body_text("Hi #{user.name}!")
      expect(email).to have_body_text('The cache cleanup policy has completed successfully for')
      expect(email).to have_body_text(group.name)
      expect(email).to have_body_text('Summary of the cleanup')
      expect(email).to have_body_text('Total entries removed:')
      expect(email).to have_body_text('Storage reclaimed:')
      expect(email).to have_body_text('Rule:')
      expect(email).to have_body_text("Not accessed in the last #{policy.keep_n_days_after_download} days")
      expect(email).to have_body_text('You can review the full cleanup details')
      expect(email).to have_body_text('audit log')
    end

    context 'when keep_n_days_after_download is one day' do
      let(:policy) { build_stubbed(:virtual_registries_cleanup_policy, group: group, keep_n_days_after_download: 1) }

      it { is_expected.to have_body_text('Not accessed in the last day') }
    end
  end

  describe '#virtual_registry_cleanup_failure' do
    subject(:email) { Notify.virtual_registry_cleanup_failure(policy, user) }

    before do
      policy.failure_message = 'Connection timeout'
    end

    it_behaves_like 'it should not have Gmail Actions links'
    it_behaves_like 'a user cannot unsubscribe through footer link'
    it_behaves_like 'appearance header and footer enabled'
    it_behaves_like 'appearance header and footer not enabled'

    it 'sends mail with expected contents' do
      expect(email).to have_subject("Cache cleanup failed for #{group.name}")
      expect(email).to be_delivered_to([user.notification_email_or_default])
      expect(email).to have_body_text("Hi #{user.name}!")
      expect(email).to have_body_text('The scheduled cache cleanup for')
      expect(email).to have_body_text(group.name)
      expect(email).to have_body_text('could not be completed')
      expect(email).to have_body_text('Summary of the cleanup')
      expect(email).to have_body_text('Rule:')
      expect(email).to have_body_text("Not accessed in the last #{policy.keep_n_days_after_download} days")
      expect(email).to have_body_text('Error:')
      expect(email).to have_body_text(policy.failure_message)
      expect(email).to have_body_text('You can review the full cleanup details')
      expect(email).to have_body_text('audit log')
    end

    context 'when keep_n_days_after_download is one day' do
      let(:policy) { build_stubbed(:virtual_registries_cleanup_policy, group: group, keep_n_days_after_download: 1) }

      it { is_expected.to have_body_text('Not accessed in the last day') }
    end
  end
end
