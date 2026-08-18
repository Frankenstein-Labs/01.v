# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::EmailsHelper, feature_category: :shared do
  include NotifyHelper

  describe '#action_title' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :result) do
      'somedomain.com/groups/agroup/-/epics/231'     | 'View Epic'
      'somedomain.com/aproject/issues/231'           | 'View Issue'
      'somedomain.com/aproject/-/merge_requests/231' | 'View Merge request'
      'somedomain.com/aproject/-/commit/al3f231'     | 'View Commit'
      'somedomain.com/aproject/-/wikis/foobar'       | 'View Wiki'
    end

    with_them do
      it 'returns the expected title' do
        title = helper.action_title(path)
        expect(title).to eq(result)
      end
    end
  end

  describe '#service_desk_email_additional_text' do
    let(:custom_text) { 'this is some additional custom text' }

    subject { helper.service_desk_email_additional_text }

    context 'when additional email text is enabled through license' do
      before do
        stub_licensed_features(email_additional_text: true)
        stub_ee_application_setting(email_additional_text: custom_text)
      end

      it { expect(subject).to eq(custom_text) }
    end

    context 'when additional email text is disabled' do
      before do
        stub_licensed_features(email_additional_text: false)
        stub_usage_ping_features(false)
      end

      it { expect(subject).to be_nil }
    end

    context 'when additional email text is enabled through usage ping features' do
      before do
        stub_usage_ping_features(true)
        stub_ee_application_setting(email_additional_text: custom_text)
      end

      it { is_expected.to eq(custom_text) }
    end
  end

  describe '#show_email_additional_text?' do
    subject { helper.show_email_additional_text? }

    context 'when email_additional_text is available' do
      before do
        stub_licensed_features(email_additional_text: true)
      end

      it 'returns true when setting is present' do
        stub_ee_application_setting(email_additional_text: 'custom text')

        expect(subject).to be(true)
      end

      it 'returns false when setting is blank' do
        stub_ee_application_setting(email_additional_text: '')

        expect(subject).to be(false)
      end
    end

    context 'when email_additional_text is not available' do
      before do
        stub_licensed_features(email_additional_text: false)
        stub_ee_application_setting(email_additional_text: 'custom text')
      end

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#closure_reason_text' do
    context 'when work item is of epic type' do
      let_it_be(:user) { build_stubbed(:user) }
      let_it_be(:work_item) { build_stubbed(:work_item, :epic) }

      before do
        helper.instance_variable_set(:@issue, work_item)
        helper.instance_variable_set(:@recipient, user)
      end

      subject do
        helper.closure_reason_text(closed_via, format: :html, name: 'Gitlab User')
      end

      context 'when closed_via is nil' do # For now is the only possible scenario for epic work items
        let(:closed_via) { nil }

        it { is_expected.to include('Epic was closed by Gitlab User') }
      end
    end
  end
end
