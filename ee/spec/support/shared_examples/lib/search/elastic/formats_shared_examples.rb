# frozen_string_literal: true

RSpec.shared_examples 'a query formatted for size' do
  it 'does not apply size by default' do
    expect(subject.keys).not_to include(:size)
  end

  context 'when count_only is true in options' do
    let(:options) { base_options.merge(count_only: true) }

    it 'applies size' do
      expect(subject).to include(size: 0)
    end
  end

  context 'when per_page is set in options' do
    let(:options) { base_options.merge(per_page: 100) }

    it 'applies size' do
      expect(subject).to include(size: 100)
    end
  end

  context 'when both count_only and size are set in options' do
    let(:options) { base_options.merge(count_only: true, size: 100) }

    it 'applies a size of 0' do
      expect(subject).to include(size: 0)
    end
  end
end

RSpec.shared_examples 'a query that is paginated' do
  it 'does not apply page by default' do
    expect(subject.keys).not_to include(:from)
  end

  context 'when only page is set in options' do
    let(:options) { base_options.merge(page: 3) }

    it 'does not apply from' do
      expect(subject.keys).not_to include(:from)
    end
  end

  context 'when page and per_page are set in options' do
    let(:options) { base_options.merge(page: 3, per_page: 10) }

    it 'does applies from' do
      expect(subject).to include(from: 20)
    end
  end
end

RSpec.shared_examples 'a query that sets source_fields' do |source_fields = ['id']|
  it 'applies the source field' do
    expect(subject).to include(_source: source_fields)
  end
end
