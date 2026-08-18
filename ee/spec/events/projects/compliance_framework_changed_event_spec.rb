# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/projects/compliance_framework_changed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Projects::ComplianceFrameworkChangedEvent, feature_category: :compliance_management do
  it_behaves_like 'an event with schema',
    valid_data: { project_id: 1, compliance_framework_id: 2, event_type: 'added' },
    missing_required: %i[project_id compliance_framework_id event_type],
    invalid_types: { project_id: 'not_an_integer', event_type: 'updated' }

  describe '#schema' do
    context 'with valid event_type values' do
      it 'accepts removed' do
        data = { project_id: 1, compliance_framework_id: 2, event_type: 'removed' }

        expect { described_class.new(data: data) }.not_to raise_error
      end
    end
  end
end
