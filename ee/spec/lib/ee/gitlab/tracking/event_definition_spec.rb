# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::EventDefinition, feature_category: :service_ping do
  let(:attributes) do
    {
      description: 'Created issues',
      category: 'issues',
      action: 'create',
      label_description: 'API',
      property_description: 'The string "issue_id"',
      value_description: 'ID of the issue',
      extra_properties: { confidential: false },
      product_group: 'group::product analytics',
      distributions: %w[ee ce],
      tiers: %w[free premium ultimate],
      introduced_by_url: "https://gitlab.com/example/-/merge_requests/123",
      milestone: '1.6'
    }
  end

  describe '#extra_trackers' do
    let(:dummy_tracking_class) { Class.new }

    before do
      stub_const('Gitlab::Tracking::DummyTracking', dummy_tracking_class)
    end

    it 'adds default extra trackers to defined extra trackers' do
      extra_trackers = {
        extra_trackers:
          [
            {
              tracking_class: 'Gitlab::Tracking::DummyTracking',
              protected_properties: { prop: { description: 'description' } }
            }
          ]
      }
      config = attributes.merge(extra_trackers)

      expect(described_class.new(nil, config).extra_trackers).to eq({
        Gitlab::Tracking::AiTracking => {},
        dummy_tracking_class => { protected_properties: [:prop] }
      })
    end

    it 'respects extra tracker definition if provided' do
      extra_trackers = {
        extra_trackers:
          [
            {
              tracking_class: 'Gitlab::Tracking::AiTracking',
              protected_properties: { prop: { description: 'description' } }
            }
          ]
      }
      config = attributes.merge(extra_trackers)

      expect(described_class.new(nil, config).extra_trackers)
        .to eq({ Gitlab::Tracking::AiTracking => { protected_properties: [:prop] } })
    end
  end
end
