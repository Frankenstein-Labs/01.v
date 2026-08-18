# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/sbom/vulnerabilities_created_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Sbom::VulnerabilitiesCreatedEvent, feature_category: :software_composition_analysis do
  let(:valid_finding) do
    {
      uuid: 'abc-123',
      project_id: 1,
      vulnerability_id: 2,
      package_name: 'lodash',
      package_version: '4.17.21',
      purl_type: 'npm'
    }
  end

  it_behaves_like 'an event with schema',
    valid_data: {
      findings: [
        {
          uuid: 'abc-123',
          project_id: 1,
          vulnerability_id: 2,
          package_name: 'lodash',
          package_version: '4.17.21',
          purl_type: 'npm'
        }
      ]
    },
    missing_required: %i[findings],
    invalid_types: { findings: 'not_an_array' }

  describe '#schema' do
    context 'with invalid findings item' do
      it 'raises an error when a findings item is missing required uuid' do
        expect { described_class.new(data: { findings: [valid_finding.except(:uuid)] }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end

      it 'raises an error when a findings item has a string project_id' do
        expect { described_class.new(data: { findings: [valid_finding.merge(project_id: 'not_an_integer')] }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
