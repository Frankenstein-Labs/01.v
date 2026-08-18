# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::FoundationalFlows::AllowFlowExecutionProbe,
  feature_category: :duo_agent_platform do
  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    subject(:probe) { described_class.new }

    where(:setting_enabled, :success?, :expected_message) do
      true  | true  | 'The allow flow execution setting is enabled.'
      false | false | 'The allow flow execution setting is disabled.'
    end

    with_them do
      before do
        stub_application_setting(duo_remote_flows_enabled: setting_enabled)
      end

      it 'returns the expected result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be(success?)
        expect(result.message).to eq(expected_message)
        expect(result.name).to eq(:allow_flow_execution_probe)
      end
    end
  end
end
