# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::TaskStatus, feature_category: :global_search do
  include_context 'with Elasticsearch task status response context'

  let(:helper) { ::Search::Elastic::Helper.default }

  before do
    allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
    allow(helper).to receive(:task_status).and_return(response)
  end

  describe '.completed?' do
    subject(:completed) { described_class.new(task_id: 1).completed? }

    context 'when task is completed' do
      let(:response) { successful_response }

      it { is_expected.to be(true) }
    end

    context 'when task is not completed' do
      let(:response) { not_completed_response }

      it { is_expected.to be(false) }
    end
  end

  describe '.totals_match?' do
    subject(:totals_match) { described_class.new(task_id: 1).totals_match? }

    context 'when total equals sum of created, updated, and deleted' do
      let(:response) { successful_response }

      it { is_expected.to be(true) }
    end

    context 'when expected keys are not present' do
      let(:response) { not_found_response }

      it { is_expected.to be(false) }
    end

    context 'when total does not equal sum of created, updated, and deleted' do
      let(:response) { error_response }

      it { is_expected.to be(false) }
    end
  end

  describe '.error?' do
    subject(:error) { described_class.new(task_id: 1).error? }

    context 'when an error is not returned' do
      let(:response) { successful_response }

      it { is_expected.to be(false) }
    end

    context 'when an error is returned' do
      let(:response) { error_response }

      it { is_expected.to be(true) }
    end
  end
end
