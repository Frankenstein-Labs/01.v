# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Pagination::ElasticConnection, feature_category: :global_search do
  let(:context) { instance_double(GraphQL::Query::Context, schema: GitlabSchema) }
  let(:all_nodes) { instance_double(Search::Elastic::Relation) }
  let(:arguments) { {} }
  let(:connection_options) { { context: context }.merge(arguments) }

  subject(:connection) { described_class.new(all_nodes, **connection_options) }

  it_behaves_like 'a connection with collection methods'

  describe '#nodes' do
    subject(:paged_nodes) { connection.nodes }

    context 'when the given cursor is malformed' do
      let(:before_cursor) { Base64.urlsafe_encode64('{[}]') }
      let(:arguments) { { before: before_cursor } }

      before do
        allow(all_nodes).to receive(:first).and_return([1, 2, 3])
      end

      it 'raises an ArgumentError' do
        expect { paged_nodes }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    context 'when the before and after provided at the same time' do
      let(:arguments) { { before: 'foo', after: 'foo' } }

      it 'raises ArgumentError' do
        expect { paged_nodes }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    describe 'before' do
      let(:before_cursor) { Base64.urlsafe_encode64(%w[a b].to_json) }

      before do
        allow(all_nodes).to receive(:before)
      end

      describe 'first' do
        let(:arguments) { { before: before_cursor, first: 2 } }

        before do
          allow(all_nodes).to receive(:first).and_return([1, 2, 3])
        end

        it 'returns the records' do
          expect(paged_nodes).to eq([1, 2])

          expect(all_nodes).to have_received(:before).with('a', 'b').ordered
          expect(all_nodes).to have_received(:first).with(3).ordered
        end
      end

      describe 'last' do
        let(:arguments) { { before: before_cursor, last: 2 } }

        before do
          allow(all_nodes).to receive(:last).and_return([4, 5, 6])
        end

        it 'returns the records' do
          expect(paged_nodes).to eq([5, 6])

          expect(all_nodes).to have_received(:before).with('a', 'b').ordered
          expect(all_nodes).to have_received(:last).with(3).ordered
        end
      end
    end

    describe 'after' do
      let(:after_cursor) { Base64.urlsafe_encode64(%w[a b].to_json) }

      before do
        allow(all_nodes).to receive(:after)
      end

      describe 'first' do
        let(:arguments) { { after: after_cursor, first: 2 } }

        before do
          allow(all_nodes).to receive(:first).and_return([1, 2, 3])
        end

        it 'returns the records' do
          expect(paged_nodes).to eq([1, 2])

          expect(all_nodes).to have_received(:after).with('a', 'b').ordered
          expect(all_nodes).to have_received(:first).with(3).ordered
        end
      end

      describe 'last' do
        let(:arguments) { { after: after_cursor, last: 2 } }

        before do
          allow(all_nodes).to receive(:last).and_return([4, 5, 6])
        end

        it 'returns the records' do
          expect(paged_nodes).to eq([5, 6])

          expect(all_nodes).to have_received(:after).with('a', 'b').ordered
          expect(all_nodes).to have_received(:last).with(3).ordered
        end
      end
    end
  end

  describe '#has_next_page' do
    subject { connection.has_next_page }

    context 'when the `before` is provided' do
      let(:arguments) { { before: 'foo' } }

      it { is_expected.to be_truthy }
    end

    context 'when the `before` is not provided' do
      context 'when the `first` argument is provided' do
        let(:arguments) { { first: 2 } }

        context 'when the relation returns more than requested amount of records' do
          before do
            allow(all_nodes).to receive(:first).and_return([1, 2, 3])
          end

          it { is_expected.to be_truthy }
        end

        context 'when the relation returns less than or equal to requested amount records' do
          before do
            allow(all_nodes).to receive(:first).and_return([1, 2])
          end

          it { is_expected.to be_falsey }
        end
      end

      context 'when the `last` argument is provided' do
        let(:arguments) { { last: 2 } }

        before do
          allow(all_nodes).to receive(:last).and_return([1, 2, 3])
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe 'has_previous_page' do
    subject { connection.has_previous_page }

    context 'when the `after` is provided' do
      let(:arguments) { { after: 'foo' } }

      it { is_expected.to be_truthy }
    end

    context 'when the `after` is not provided' do
      context 'when the `first` argument is provided' do
        let(:arguments) { { first: 2 } }

        before do
          allow(all_nodes).to receive(:first).and_return([1, 2, 3])
        end

        it { is_expected.to be_falsey }
      end

      context 'when the `last` argument is provided' do
        let(:arguments) { { last: 2 } }

        context 'when the relation returns more than requested amount of records' do
          before do
            allow(all_nodes).to receive(:last).and_return([1, 2, 3])
          end

          it { is_expected.to be_truthy }
        end

        context 'when the relation returns less than or equal to requested amount records' do
          before do
            allow(all_nodes).to receive(:last).and_return([1, 2])
          end

          it { is_expected.to be_falsey }
        end
      end
    end
  end

  describe '#cursor_for' do
    subject(:cursor) { connection.cursor_for('foo') }

    before do
      allow(all_nodes).to receive(:cursor_for).with('foo').and_return('bar')
    end

    it 'returns the Base64 encoded cursor' do
      expect(cursor).to eq('ImJhciI')
    end
  end
end
