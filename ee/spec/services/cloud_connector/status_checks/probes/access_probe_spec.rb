# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::AccessProbe, :freeze_time, feature_category: :duo_setting do
  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    subject(:probe) { described_class.new }

    # nil trait means record is missing
    where(:access_trait, :success?, :details?, :message) do
      :current | true  | true  | 'Subscription synchronized successfully'
      nil      | false | false | 'Subscription has not yet been synchronized'
      :stale   | false | true  | 'Subscription has not been synchronized recently'
    end

    with_them do
      before do
        create(:cloud_connector_access, access_trait) if access_trait
      end

      it 'returns the expected result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be success?
        expect(result.message).to match(message)

        if details?
          expect(result.details).to include(
            updated_at: CloudConnector::Access.last.updated_at,
            catalog: CloudConnector::Access.last.catalog
          )
        end
      end
    end
  end
end
