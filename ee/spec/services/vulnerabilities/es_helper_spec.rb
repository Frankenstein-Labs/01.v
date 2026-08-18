# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::EsHelper, feature_category: :vulnerability_management do
  describe '.sync_elasticsearch' do
    subject { described_class.sync_elasticsearch(ids) }

    let_it_be(:vulnerability_1) { create(:vulnerability, :with_read) }
    let_it_be(:vulnerability_2) { create(:vulnerability, :with_read) }
    let(:ids) { [vulnerability_1.id, vulnerability_2.id] }

    it_behaves_like 'it syncs vulnerabilities with ES',
      -> { [vulnerability_1, vulnerability_2].map { |v| v.vulnerability_read.id } }

    context 'when ids exceed the batch size' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it_behaves_like 'it syncs vulnerabilities with ES', -> { [vulnerability_1.vulnerability_read.id] }
      it_behaves_like 'it syncs vulnerabilities with ES', -> { [vulnerability_2.vulnerability_read.id] }
    end

    context 'when ids contain nil values' do
      let(:ids) { [vulnerability_1.id, nil] }

      it_behaves_like 'it syncs vulnerabilities with ES', -> { [vulnerability_1.vulnerability_read.id] }
    end

    context 'when ids contain duplicates' do
      let(:ids) { [vulnerability_1.id, vulnerability_1.id, vulnerability_2.id] }

      it_behaves_like 'it syncs vulnerabilities with ES',
        -> { [vulnerability_1, vulnerability_2].map { |v| v.vulnerability_read.id } }
    end

    context 'when ids are empty' do
      let(:ids) { [] }

      it_behaves_like 'does not sync with ES when no vulnerabilities'
    end
  end
end
