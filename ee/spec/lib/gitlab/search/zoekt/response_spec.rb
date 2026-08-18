# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::Response, feature_category: :global_search do
  let_it_be(:fixtures_path) { 'ee/spec/fixtures/search/zoekt/' }
  let_it_be(:raw_response_success) { File.read Rails.root.join(fixtures_path, 'flightjs_response_success.json') }
  let_it_be(:raw_response_failure) { File.read Rails.root.join(fixtures_path, 'response_failure.json') }

  let(:parsed_response) { Gitlab::Json.safe_parse(raw_response) }
  let(:raw_response) { raw_response_success }
  let(:code) { 200 }

  subject(:zoekt_response) { described_class.new(parsed_response, code: code) }

  describe '.empty' do
    subject(:empty_response) { described_class.empty }

    it 'returns a Response instance' do
      expect(empty_response).to be_a(described_class)
    end

    it 'has the correct result structure' do
      expect(empty_response.parsed_response).to eq(
        'Result' => {
          'FileCount' => 0,
          'FileMatchCount' => 0,
          'LineMatchCount' => 0,
          'MatchCount' => 0,
          'NgramMatches' => 0,
          'TotalFileMatchCount' => 0,
          'TotalLineMatchCount' => 0
        }
      )
    end

    context 'as immutable' do
      it 'creates a new instance each time' do
        empty_response_1 = described_class.empty
        empty_response_2 = described_class.empty

        expect(empty_response_1).not_to be(empty_response_2)
        expect(empty_response_1.parsed_response).to eq(empty_response_2.parsed_response)
      end

      it 'does not affect other instances when modified' do
        empty_response_1 = described_class.empty
        empty_response_2 = described_class.empty

        # Modify one instance's parsed_response
        empty_response_1.parsed_response[:Result][:FileCount] = 999

        # Other instance should remain unchanged
        expect(empty_response_2.file_count).to eq(0)
      end
    end
  end

  describe '#success?' do
    it 'returns true' do
      expect(zoekt_response.success?).to be(true)
    end

    context 'when failed response' do
      let(:raw_response) { raw_response_failure }

      it 'returns false' do
        expect(zoekt_response.success?).to be(false)
      end
    end
  end

  describe '#error_message' do
    it 'returns nil' do
      expect(zoekt_response.error_message).to be_nil
    end

    context 'when failed response' do
      let(:raw_response) { raw_response_failure }
      let(:code) { 400 }

      it 'returns error message' do
        expect(zoekt_response.error_message).to match(/error parsing regexp/)
      end
    end
  end

  describe '#file_count' do
    it 'returns TotalFileMatchCount' do
      expect(zoekt_response.file_count).to eq(150)
    end

    context 'when TotalFileMatchCount is zero' do
      let(:parsed_response) do
        resp = Gitlab::Json.safe_parse(raw_response)
        resp['Result']['TotalFileMatchCount'] = 0
        resp
      end

      it 'falls back to FileMatchCount' do
        expect(zoekt_response.file_count).to eq(3)
      end
    end

    context 'when TotalFileMatchCount is absent' do
      let(:parsed_response) do
        resp = Gitlab::Json.safe_parse(raw_response)
        resp['Result'].delete('TotalFileMatchCount')
        resp
      end

      it 'falls back to FileMatchCount' do
        expect(zoekt_response.file_count).to eq(3)
      end

      context 'when FileMatchCount is absent' do
        let(:parsed_response) do
          resp = Gitlab::Json.safe_parse(raw_response)
          resp['Result'].delete('TotalFileMatchCount')
          resp['Result'].delete('FileMatchCount')
          resp
        end

        it 'falls back to counting files' do
          expect(zoekt_response.file_count).to eq(3)
        end

        context 'when Files is nil' do
          let(:parsed_response) do
            resp = Gitlab::Json.safe_parse(raw_response)
            resp['Result'].delete('TotalFileMatchCount')
            resp['Result'].delete('FileMatchCount')
            resp['Result']['Files'] = nil
            resp
          end

          it 'returns zero' do
            expect(zoekt_response.file_count).to eq(0)
          end
        end
      end
    end
  end

  describe '#match_count' do
    it 'returns TotalLineMatchCount' do
      expect(zoekt_response.match_count).to eq(850)
    end

    context 'when TotalLineMatchCount is zero' do
      let(:parsed_response) do
        resp = Gitlab::Json.safe_parse(raw_response)
        resp['Result']['TotalLineMatchCount'] = 0
        resp
      end

      it 'falls back to LineMatchCount' do
        expect(zoekt_response.match_count).to eq(20)
      end
    end

    context 'when TotalLineMatchCount is absent' do
      let(:parsed_response) do
        resp = Gitlab::Json.safe_parse(raw_response)
        resp['Result'].delete('TotalLineMatchCount')
        resp
      end

      it 'falls back to LineMatchCount' do
        expect(zoekt_response.match_count).to eq(20)
      end

      context 'when LineMatchCount is absent' do
        let(:parsed_response) do
          resp = Gitlab::Json.safe_parse(raw_response)
          resp['Result'].delete('TotalLineMatchCount')
          resp['Result'].delete('LineMatchCount')
          resp
        end

        it 'falls back to counting line matches' do
          expect(zoekt_response.match_count).to eq(20)
        end

        context 'when some files have nil LineMatches' do
          let(:parsed_response) do
            resp = Gitlab::Json.safe_parse(raw_response)
            resp['Result'].delete('TotalLineMatchCount')
            resp['Result'].delete('LineMatchCount')
            resp['Result']['Files'].first['LineMatches'] = nil
            resp
          end

          it 'counts nil LineMatches as zero' do
            expect(zoekt_response.match_count).to eq(9)
          end
        end

        context 'when Files is nil' do
          let(:parsed_response) do
            resp = Gitlab::Json.safe_parse(raw_response)
            resp['Result'].delete('TotalLineMatchCount')
            resp['Result'].delete('LineMatchCount')
            resp['Result']['Files'] = nil
            resp
          end

          it 'returns zero' do
            expect(zoekt_response.match_count).to eq(0)
          end
        end
      end
    end
  end
end
