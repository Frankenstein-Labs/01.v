# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::Graphql::Aggregations::Issuables::LazyLinksAggregate do
  let(:fake_class_name) { 'Dummy::FakeLazyLinksAggregate' }
  let(:fake_class) do
    Class.new(described_class) do
      def fake_call
        link_class
      end
    end
  end

  before do
    stub_const(fake_class_name, fake_class)
  end

  describe '.link_class' do
    it 'requires implementation on subclasses' do
      expect { Dummy::FakeLazyLinksAggregate.new({}, 99).fake_call }.to raise_error(NotImplementedError)
    end
  end
end
