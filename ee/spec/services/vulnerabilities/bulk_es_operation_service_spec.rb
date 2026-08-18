# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkEsOperationService, :elastic, feature_category: :vulnerability_management do
  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:vulnerabilities_set_1) { create_list(:vulnerability, 2, :with_read, project: project) }

  before do
    allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(true)
    allow_next_found_instance_of(Vulnerabilities::Read) do |instance|
      allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
    end
    allow_next_found_instance_of(Vulnerability) do |instance|
      allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
    end
  end

  it 'converts Vulnerability relation to Vulnerabilities::Read and tracks reads' do
    expected_reads = vulnerabilities_set_1.map(&:vulnerability_read)

    expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*args|
      expect(args).to match_array(expected_reads)
    end

    execute_service(vulnerabilities_set_1)
  end

  it 'does not convert when relation is already Vulnerabilities::Read' do
    reads = Vulnerabilities::Read.by_vulnerabilities(vulnerabilities_set_1.map(&:id))

    expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*args|
      expect(args).to match_array(reads.to_a)
    end

    execute_service(reads)
  end

  it 'avoids n+1 DB queries' do
    control = ActiveRecord::QueryRecorder.new do
      execute_service(vulnerabilities_set_1)
    end
    group_2 = create(:group, :nested)
    project_2 = create(:project, namespace: group_2)
    vulnerabilities_set_2 = create_list(:vulnerability, 2, :with_read, project: project_2)

    expect do
      execute_service(vulnerabilities_set_1 + vulnerabilities_set_2)
    end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
  end

  context 'when ES migrations have not completed' do
    before do
      set_elasticsearch_migration_to :create_vulnerability_reads_index, including: false
    end

    it 'tracks Vulnerability records directly' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*args|
        expect(args).to all(be_a(Vulnerability))
      end

      execute_service(vulnerabilities_set_1)
    end

    it 'avoids n+1 DB queries' do
      control = ActiveRecord::QueryRecorder.new do
        execute_service(vulnerabilities_set_1)
      end
      group_2 = create(:group, :nested)
      project_2 = create(:project, namespace: group_2)
      vulnerabilities_set_2 = create_list(:vulnerability, 2, project: project_2)

      expect do
        execute_service(vulnerabilities_set_1 + vulnerabilities_set_2)
      end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
    end
  end

  context 'when indexing is not allowed' do
    before do
      allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(false)
    end

    it 'yields the relation without tracking' do
      expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

      result = execute_service(vulnerabilities_set_1)
      expect(result).to be(true)
    end
  end

  describe 'vulnerability_read association sharing' do
    let_it_be(:vulnerability_with_read) { create(:vulnerability, :with_read, project: project) }
    let_it_be(:vulnerability_without_read) { create(:vulnerability, project: project) }

    it 'handles vulnerability with vulnerability_read present' do
      relation = Vulnerability.id_in([vulnerability_with_read.id])

      expect do
        execute_service(relation)
      end.not_to raise_error
    end

    it 'handles vulnerability without vulnerability_read (nil case)' do
      relation = Vulnerability.id_in([vulnerability_without_read.id])

      expect do
        execute_service(relation)
      end.not_to raise_error
    end

    it 'handles mixed batch with both present and nil vulnerability_read' do
      relation = Vulnerability.id_in([vulnerability_with_read.id, vulnerability_without_read.id])

      expect do
        execute_service(relation)
      end.not_to raise_error
    end
  end

  describe '#execute' do
    let(:relation) { Vulnerability.id_in(vulnerabilities_set_1.map(&:id)) }

    subject(:service) { described_class.new(relation) }

    context 'when indexing is allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(true)
      end

      context 'when a block is given' do
        it 'executes the block before ES bookkeeping' do
          call_order = []

          expect(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*_args|
            call_order << :es_bookkeeping
          end

          service.execute do |_rel|
            call_order << :block
          end

          expect(call_order).to eq([:block, :es_bookkeeping])
        end

        it 'yields the relation to the block' do
          yielded_relation = nil

          service.execute { |rel| yielded_relation = rel }

          expect(yielded_relation).to eq(relation)
        end
      end

      context 'when no block is given' do
        it 'still performs ES bookkeeping' do
          expect(::Elastic::ProcessBookkeepingService).to receive(:track!)

          service.execute
        end
      end
    end

    context 'when indexing is not allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexHelper).to receive(:indexing_allowed?).and_return(false)
      end

      context 'when a block is given' do
        it 'executes the block' do
          block_executed = false

          service.execute { |_rel| block_executed = true }

          expect(block_executed).to be(true)
        end

        it 'yields the relation to the block' do
          yielded_relation = nil

          service.execute { |rel| yielded_relation = rel }

          expect(yielded_relation).to eq(relation)
        end

        it 'returns true' do
          expect(service.execute { |_rel| nil }).to be(true)
        end

        it 'does not perform ES bookkeeping' do
          expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

          service.execute { |_rel| nil }
        end
      end

      context 'when no block is given' do
        it 'returns true' do
          expect(service.execute).to be(true)
        end

        it 'does not perform ES bookkeeping' do
          expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)

          service.execute
        end
      end
    end
  end

  private

  def execute_service(vulnerabilities_or_relation)
    relation = if vulnerabilities_or_relation.is_a?(ActiveRecord::Relation)
                 vulnerabilities_or_relation
               else
                 Vulnerability.id_in(vulnerabilities_or_relation.map(&:id))
               end

    described_class.new(relation).execute
  end
end
