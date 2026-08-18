# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/security/policy_updated_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Security::PolicyUpdatedEvent, feature_category: :security_policy_management do
  it_behaves_like 'an event with schema',
    valid_data: {
      security_policy_id: 1,
      diff: { 'enabled' => { 'from' => true, 'to' => false } },
      rules_diff: { created: [], updated: [], deleted: [] }
    },
    missing_required: %i[security_policy_id diff rules_diff],
    invalid_types: { security_policy_id: 'not_an_integer' }

  describe '#schema' do
    let(:valid_data) do
      {
        security_policy_id: 1,
        diff: { 'enabled' => { 'from' => true, 'to' => false } },
        rules_diff: { created: [], updated: [], deleted: [] }
      }
    end

    context 'with invalid diff pattern value' do
      it 'raises an error when a property is missing from/to' do
        data = valid_data.merge(diff: { 'enabled' => { 'from' => true } })

        expect { described_class.new(data: data) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
