# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Pagination::Keyset::SimpleOrderBuilder do
  context 'when ordering by a CASE expression and id' do
    let(:scope) do
      Vulnerability.order(
        Vulnerability.report_types
          .sort
          .to_h
          .values
          .each
          .with_index
          .reduce(Arel::Nodes::Case.new(Vulnerability.arel_table[:report_type])) do |node, (value, index)|
            node.when(value).then(index)
          end.asc
      )
    end

    subject(:result) { described_class.build(scope) }

    it 'does not raise error' do
      expect { result }.not_to raise_error
    end

    it 'does not support this ordering' do
      _, success = result

      expect(success).to be(false)
    end
  end
end
