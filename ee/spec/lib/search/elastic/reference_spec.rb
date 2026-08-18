# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Reference, feature_category: :global_search do
  let(:instance) { described_class.new }
  let_it_be(:issue) { create(:issue) }
  let(:serialized_issue) { "Issue #{issue.id} #{issue.id} #{issue.es_parent}" }
  let(:serialized_work_item) { "WorkItem|#{issue.id}|#{issue.es_parent}" }

  describe '#serialize' do
    context 'when item is a string' do
      let(:item) { 'some_string' }

      it 'returns the string' do
        expect(described_class.serialize(item)).to eq(item)
      end
    end

    context 'when item is a Search::Elastic::Reference' do
      let(:item) { Search::Elastic::Reference.build(issue, ::Search::Elastic::References::WorkItem) }

      it 'returns the serialized reference' do
        expect(described_class.serialize(item)).to eq(serialized_work_item)
      end
    end

    context 'when item is a Search::Elastic::DocumentReference' do
      let(:item) { Search::Elastic::DocumentReference.new(Issue, issue.id, issue.id, issue.es_parent) }

      it 'returns the serialized document reference' do
        expect(described_class.serialize(item)).to eq(serialized_issue)
      end
    end

    context 'when item is an ApplicationRecord' do
      let(:item) { issue }

      it 'returns the elastic reference of the ApplicationRecord' do
        expect(described_class.serialize(item)).to eq(serialized_work_item)
      end
    end

    context 'when item is an unsupported type' do
      let(:item) { Object.new }

      it 'raises an InvalidError' do
        expect { described_class.serialize(item) }.to raise_error(Search::Elastic::Reference::InvalidError)
      end
    end
  end

  describe '#deserialize' do
    let(:string) { serialized_issue }

    it 'returns an instance of the reference class' do
      expect(Search::Elastic::References::Legacy).to receive(:instantiate).with(string).and_call_original

      expect(described_class.deserialize(string)).to be_a(Search::Elastic::DocumentReference)
    end

    context 'when the serialized string maps to a reference class' do
      it 'instantiates with the reference class' do
        string = 'Legacy|payload'
        expect(Search::Elastic::References::Legacy).to receive(:instantiate).with(string)

        described_class.deserialize(string)
      end
    end
  end

  describe '#preload_database_records' do
    let(:refs) { [described_class.deserialize(serialized_issue)] * 2 }

    it 'calls preload_indexing_data for every klass' do
      expect(Search::Elastic::DocumentReference).to receive(:preload_indexing_data).with(refs)

      described_class.preload_database_records(refs)
    end

    it 'calls preload in batches not to overload the database' do
      stub_const('Search::Elastic::Reference::PRELOAD_BATCH_SIZE', 1)

      expect(Search::Elastic::DocumentReference).to receive(:preload_indexing_data).twice

      described_class.preload_database_records(refs)
    end
  end

  describe '#init' do
    let(:id) { 1 }
    let(:es_id) { 2 }
    let(:es_parent) { 'group_1' }

    it 'returns a WorkItem ref if the klass is WorkItem' do
      ref = described_class.init(WorkItem, id, es_id, es_parent)

      expect(ref).to be_a(Search::Elastic::References::WorkItem)
      expect(ref.klass).to eq('WorkItem')
      expect(ref.identifier).to eq(id)
      expect(ref.routing).to eq(es_parent)
    end

    it 'returns a Vulnerabilities::Read ref if the klass is Vulnerabilities::Read' do
      ref = described_class.init(Vulnerabilities::Read, id, es_id, es_parent)

      expect(ref).to be_a(Search::Elastic::References::Vulnerabilities::Read)
      expect(ref.klass).to eq('Vulnerabilities::Read')
      expect(ref.identifier).to eq(id)
      expect(ref.routing).to eq(es_parent)
    end

    it 'returns a Document Reference if the klass is MergeRequest' do
      ref = described_class.init(MergeRequest, id, es_id, es_parent)

      expect(ref).to be_a(Search::Elastic::DocumentReference)
      expect(ref.klass.to_s).to eq('MergeRequest')
      expect(ref.identifier).to eq(es_id)
      expect(ref.routing).to eq(es_parent)
    end
  end

  describe '.serialize' do
    it 'raises a NotImplementedError' do
      expect { instance.serialize }.to raise_error(NotImplementedError)
    end
  end

  describe '.identifier' do
    it 'raises a NotImplementedError' do
      expect { instance.identifier }.to raise_error(NotImplementedError)
    end
  end

  describe '.routing' do
    it 'defaults to nil' do
      expect(instance.routing).to be_nil
    end
  end

  describe '.operation' do
    it 'raises a NotImplementedError' do
      expect { instance.operation }.to raise_error(NotImplementedError)
    end
  end

  describe '.as_indexed_json' do
    it 'raises a NotImplementedError' do
      expect { instance.as_indexed_json }.to raise_error(NotImplementedError)
    end
  end

  describe '.klass' do
    it 'returns the class name without modules' do
      expect(instance.klass).to eq('Reference')
    end
  end

  describe '.index_name' do
    it 'raises a NotImplementedError' do
      expect { instance.index_name }.to raise_error(NotImplementedError)
    end
  end

  describe '#instantiate' do
    it 'raises a NotImplementedError' do
      expect { described_class.instantiate(anything) }.to raise_error(NotImplementedError)
    end
  end

  describe '#preload_indexing_data' do
    it 'raises a NotImplementedError' do
      expect { described_class.preload_indexing_data(anything) }.to raise_error(NotImplementedError)
    end
  end

  describe '.model_klass' do
    it 'raises a NotImplementedError' do
      expect { described_class.model_klass }.to raise_error(NotImplementedError)
    end
  end
end
