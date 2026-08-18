# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::IngestSliceBaseService, :elastic, feature_category: :vulnerability_management do
  let_it_be(:pipeline) { create(:ci_pipeline) }
  let_it_be(:vulnerability_1) { create(:vulnerability, :with_read) }
  let_it_be(:vulnerability_2) { create(:vulnerability, :with_read) }

  let(:finding_map_1) { create(:finding_map, vulnerability: vulnerability_1) }
  let(:finding_map_2) { create(:finding_map, vulnerability: vulnerability_2) }
  let(:finding_maps) { [finding_map_1, finding_map_2] }

  let(:service_class) do
    Class.new(described_class) do
      const_set(:SEC_DB_TASKS, %w[TaskOne])
      const_set(:MAIN_DB_TASKS, %w[TaskTwo])
    end
  end

  subject(:service) { service_class.new(pipeline, finding_maps) }

  before do
    stub_const('Security::Ingestion::Tasks::TaskOne', Class.new)
    stub_const('Security::Ingestion::Tasks::TaskTwo', Class.new)

    allow(Security::Ingestion::Tasks::TaskOne).to receive(:execute).and_return(true)
    allow(Security::Ingestion::Tasks::TaskTwo).to receive(:execute).and_return(true)
  end

  describe '#execute' do
    it 'executes all tasks and returns the vulnerability IDs' do
      expect(Security::Ingestion::Tasks::TaskOne).to receive(:execute).with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::TaskTwo).to receive(:execute).with(pipeline, finding_maps)

      result = service.execute

      expect(result).to contain_exactly(vulnerability_1.id, vulnerability_2.id)
    end

    it_behaves_like 'sync vulnerabilities changes to ES' do
      let(:expected_vulnerabilities) { [vulnerability_1, vulnerability_2].map(&:vulnerability_read) }

      subject do
        service.execute
      end
    end
  end
end
