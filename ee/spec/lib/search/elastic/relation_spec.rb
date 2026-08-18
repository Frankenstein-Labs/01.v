# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Relation, :elastic_helpers, :sidekiq_inline, :elastic_delete_by_query, feature_category: :global_search do
  include_context 'with filters shared context'

  let(:sort_order) { :asc }
  let(:klass) { Vulnerability }
  let(:options) { { index_name: Search::Elastic::References::Vulnerability.index, primary_key: :vulnerability_id } }
  let(:relation) { described_class.new(klass, query_hash, options) }

  let(:all_vulnerabilities) { Vulnerability.all.order(id: :asc) }
  let(:fourth_vulnerability) { Vulnerability.fourth }

  before do
    allow(::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker).to receive(:perform_async)
    query_hash[:sort] = { created_at: { order: sort_order } }

    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    vulnerability_reads = create_list(:vulnerability_read, 7)
    Elastic::ProcessBookkeepingService.track!(*vulnerability_reads)

    ensure_elasticsearch_index!
  end

  describe 'paginating the records using ElasticSearch' do
    context 'when sorting ascending' do
      describe 'before' do
        before do
          relation.before(fourth_vulnerability.created_at, fourth_vulnerability.id)
        end

        describe 'first' do
          subject(:first_records) { relation.first(2) }

          it 'returns the records from the beginning of the slice' do
            expect(first_records).to eq([all_vulnerabilities[0], all_vulnerabilities[1]])
          end
        end

        describe 'last' do
          subject(:last_records) { relation.last(2) }

          it 'returns the records from the end of the slice' do
            expect(last_records).to eq([all_vulnerabilities[1], all_vulnerabilities[2]])
          end
        end
      end

      describe 'after' do
        before do
          relation.after(fourth_vulnerability.created_at, fourth_vulnerability.id)
        end

        describe 'first' do
          subject(:first_records) { relation.first(2) }

          it 'returns the records from the beginning of the slice' do
            expect(first_records).to eq([all_vulnerabilities[4], all_vulnerabilities[5]])
          end
        end

        describe 'last' do
          subject(:last_records) { relation.last(2) }

          it 'returns the records from the end of the slice' do
            expect(last_records).to eq([all_vulnerabilities[5], all_vulnerabilities[6]])
          end
        end
      end
    end

    context 'when sorting descending' do
      let(:sort_order) { :desc }

      describe 'before' do
        before do
          relation.before(fourth_vulnerability.created_at, fourth_vulnerability.id)
        end

        describe 'first' do
          subject(:first_records) { relation.first(2) }

          it 'returns the records from the beginning of the slice' do
            expect(first_records).to eq([all_vulnerabilities[6], all_vulnerabilities[5]])
          end
        end

        describe 'last' do
          subject(:last_records) { relation.last(2) }

          it 'returns the records from the end of the slice' do
            expect(last_records).to eq([all_vulnerabilities[5], all_vulnerabilities[4]])
          end
        end
      end

      describe 'after' do
        before do
          relation.after(fourth_vulnerability.created_at, fourth_vulnerability.id)
        end

        describe 'first' do
          subject(:first_records) { relation.first(2) }

          it 'returns the records from the beginning of the slice' do
            expect(first_records).to eq([all_vulnerabilities[2], all_vulnerabilities[1]])
          end
        end

        describe 'last' do
          subject(:last_records) { relation.last(2) }

          it 'returns the records from the end of the slice' do
            expect(last_records).to eq([all_vulnerabilities[1], all_vulnerabilities[0]])
          end
        end
      end
    end
  end

  describe 'preloading associations' do
    let(:project_association) { records.first.association(:project) }
    let(:group_association) { records.first.association(:group) }
    let(:findings_association) { records.first.association(:findings) }
    let(:vulnerability_read_association) { records.first.association(:vulnerability_read) }

    subject(:records) { relation.preload(:project, :group).preload(:findings).first(1) }

    it 'preloads the associations', :aggregate_failures do
      expect(project_association.loaded?).to be_truthy
      expect(group_association.loaded?).to be_truthy
      expect(findings_association.loaded?).to be_truthy
      expect(vulnerability_read_association.loaded?).to be_falsey
    end
  end

  describe '#cursor_for' do
    let(:record) { all_vulnerabilities.first }

    subject(:cursor) { relation.cursor_for(record) }

    before do
      relation.first(10)
    end

    it 'returns the cursor values for the given record' do
      expect(cursor).to match([an_instance_of(Integer), record.id])
    end

    context 'when sort values contain Elasticsearch sentinel values' do
      let(:sentinel_max) { described_class::ELASTICSEARCH_LONG_MAX_VALUE }
      let(:sentinel_min) { described_class::ELASTICSEARCH_LONG_MIN_VALUE }

      # Create a fresh relation for each test where we control the response_mapper
      let(:mocked_relation) { described_class.new(klass, query_hash, options) }
      let(:mock_response_mapper) { instance_double(Search::Elastic::ResponseMapper, records: [record]) }

      before do
        # Set the instance variable directly since hit_for accesses @response_mapper
        mocked_relation.instance_variable_set(:@response_mapper, mock_response_mapper)
      end

      context 'with LONG_MAX_VALUE sentinel (ASC null sort)' do
        before do
          allow(mock_response_mapper).to receive(:results).and_return([
            { '_id' => record.id.to_s, 'sort' => [sentinel_max, record.id] }
          ])
        end

        it 'converts sentinel value to nil' do
          expect(mocked_relation.cursor_for(record)).to eq([nil, record.id])
        end
      end

      context 'with LONG_MIN_VALUE sentinel (DESC null sort)' do
        before do
          allow(mock_response_mapper).to receive(:results).and_return([
            { '_id' => record.id.to_s, 'sort' => [sentinel_min, record.id] }
          ])
        end

        it 'converts sentinel value to nil' do
          expect(mocked_relation.cursor_for(record)).to eq([nil, record.id])
        end
      end

      context 'with both values as sentinel values' do
        before do
          allow(mock_response_mapper).to receive(:results).and_return([
            { '_id' => record.id.to_s, 'sort' => [sentinel_max, sentinel_min] }
          ])
        end

        it 'converts both sentinel values to nil' do
          expect(mocked_relation.cursor_for(record)).to eq([nil, nil])
        end
      end
    end
  end

  describe "#to_a" do
    it "returns all the records without sorting" do
      expect(relation.to_a).to eq(all_vulnerabilities)
    end
  end

  describe '#size' do
    it 'returns the total count of records' do
      expect(relation.size).to eq(all_vulnerabilities.count)
    end
  end
end
