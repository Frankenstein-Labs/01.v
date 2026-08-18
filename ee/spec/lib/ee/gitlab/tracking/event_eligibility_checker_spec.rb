# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::EventEligibilityChecker, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  describe '.internal_duo_events' do
    around do |example|
      described_class.instance_variable_set(:@internal_duo_events, nil)
      example.run
      described_class.instance_variable_set(:@internal_duo_events, nil)
    end

    it 'contains the same values that would be filtered from event definitions' do
      duo_event1 = instance_double(Gitlab::Tracking::EventDefinition, action: 'duo_event1', duo_event?: true)
      duo_event2 = instance_double(Gitlab::Tracking::EventDefinition, action: 'duo_event2', duo_event?: true)
      non_duo_event = instance_double(Gitlab::Tracking::EventDefinition, action: 'regular_event', duo_event?: false)

      allow(Gitlab::Tracking::EventDefinition).to receive(:definitions)
        .and_return([duo_event1, duo_event2, non_duo_event])

      result = described_class.internal_duo_events

      expect(result).to match_array %w[duo_event1 duo_event2]
    end
  end

  describe '#eligible?' do
    let(:checker) { described_class.new }

    subject { checker.eligible?(event_name) }

    context 'when fully eligible due to produce usage data' do
      let(:event_name) { 'perform_completion_worker' }

      before do
        stub_application_setting(snowplow_enabled: false, gitlab_product_usage_data_enabled: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when app_id is not passed' do
      where(:event_name, :self_hosted_duo, :result) do
        'perform_completion_worker' | false | true
        'perform_completion_worker' | true | false
        'some_other_event'          | false | false
        'some_other_event'          | true | false
      end

      before do
        stub_application_setting(
          snowplow_enabled?: false, gitlab_product_usage_data_enabled?: false
        )
        create(:ai_self_hosted_model) if self_hosted_duo
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end

    context 'when app_id is passed' do
      subject { checker.eligible?(event_name, app_id) }

      before do
        stub_application_setting(
          snowplow_enabled?: false, gitlab_product_usage_data_enabled?: false
        )
        event_definition = instance_double(
          Gitlab::Tracking::EventDefinition,
          action: 'perform_completion_worker',
          duo_event?: true
        )
        allow(Gitlab::Tracking::EventDefinition).to receive(:definitions).and_return([event_definition])
        create(:ai_self_hosted_model) if self_hosted_duo
      end

      where(:event_name, :app_id, :self_hosted_duo, :result) do
        'click_button'                  | 'gitlab_ide_extension' | false | true
        'click_button'                  | 'gitlab_ide_extension' | true  | false
        'suggestion_shown'              | 'gitlab_ide_extension' | false | true
        'suggestion_shown'              | 'gitlab_ide_extension' | true  | false
        'some_non_ide_extension_event'  | 'gitlab_ide_extension' | false | false
        'some_non_ide_extension_event'  | 'gitlab_ide_extension' | true  | false
        'click_button'                  | 'some_other_app'       | false | false
        'suggestion_shown'              | 'some_other_app'       | false | false
        'some_non_ide_extension_event'  | 'some_other_app'       | false | false
        'some_non_ide_extension_event'  | 'some_other_app'       | true  | false
        'perform_completion_worker'     | 'some_other_app'       | false | true
        'perform_completion_worker'     | 'some_other_app'       | true  | false
        'perform_completion_worker'     | 'gitlab_ide_extension' | false | false
        'perform_completion_worker'     | 'gitlab_ide_extension' | true  | false
      end

      with_them do
        it { is_expected.to eq(result) }
      end
    end
  end
end
