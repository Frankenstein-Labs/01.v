# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::PipeAbuseDetector, feature_category: :global_search do
  describe '#abusive?' do
    let(:search_type) { 'zoekt' }
    let(:regex) { true }
    let(:params) { ActionController::Parameters.new(search: search, regex: regex) }
    let(:search_params) { Search::Params.new(params) }

    subject(:abuse_detector) { described_class.new(search_type, search_params) }

    context 'when params is nil' do
      let(:search_params) { nil }

      it 'returns false' do
        expect(abuse_detector.abusive?).to be false
      end
    end

    context 'when search term is blank' do
      let(:search) { '' }
      let(:search_type) { 'zoekt' }

      it 'returns false' do
        expect(abuse_detector.abusive?).to be false
      end
    end

    context 'when search_type is zoekt' do
      context 'when search mode is regex' do
        context 'when search term is pipe abusive' do
          let(:search) { 'foo|x' }

          it 'checks for pipe abuse detection and return true' do
            allow_next_instance_of(Gitlab::Search::AbuseDetection) do |instance|
              allow(instance).to receive(:abusive_pipes?).and_return(true)
            end

            expect(abuse_detector.abusive?).to be true
          end
        end

        context 'when search term is not pipe abusive' do
          let(:search) { 'foo|bar' }

          it 'checks for pipe abuse detection and return true' do
            allow_next_instance_of(Gitlab::Search::AbuseDetection) do |instance|
              allow(instance).to receive(:abusive_pipes?).and_return(false)
            end
            expect(abuse_detector.abusive?).to be false
          end
        end
      end

      context 'when search mode is exact' do
        let(:regex) { false }
        let(:search) { 'foo|r' }

        it 'does not checks for pipe abuse detection and return false' do
          expect_next_instance_of(Gitlab::Search::AbuseDetection) do |instance|
            expect(instance).not_to receive(:abusive_pipes?)
          end

          expect(abuse_detector.abusive?).to be false
        end
      end
    end
  end
end
