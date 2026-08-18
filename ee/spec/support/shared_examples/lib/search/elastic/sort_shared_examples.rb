# frozen_string_literal: true

RSpec.shared_examples 'a sorted query' do
  it 'does not sort by default' do
    expect(subject).to include(sort: {})
  end

  context 'when sort option is provided' do
    let(:options) { base_options.merge(order_by: 'created_at', sort: 'asc') }

    it 'applies the sort' do
      expect(subject).to include(sort: { created_at: { order: 'asc' } })
    end
  end
end
