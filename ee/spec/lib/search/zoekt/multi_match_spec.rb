# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::MultiMatch, feature_category: :global_search do
  subject(:multi_match) { described_class.new }

  describe '#initialize and read the attributes' do
    context 'when requested_chunk_size is passed' do
      let(:instance) { described_class.new(requested_chunk_size) }

      context 'and it is nil' do
        let(:requested_chunk_size) { nil }

        it 'can initialize an object with the max_chunks_size equals to DEFAULT_REQUESTED_CHUNK_SIZE' do
          expect(instance.instance_variable_get(:@max_chunks_size)).to eq described_class::DEFAULT_REQUESTED_CHUNK_SIZE
        end
      end

      context 'and it is less than MAX_CHUNKS_PER_FILE' do
        let(:requested_chunk_size) { described_class::MAX_CHUNKS_PER_FILE.pred }

        it 'can initialize an instance with the max_chunks_size equals to requested_chunk_size' do
          expect(instance.instance_variable_get(:@max_chunks_size)).to eq requested_chunk_size
        end
      end

      context 'and it is more than MAX_CHUNKS_PER_FILE' do
        let(:requested_chunk_size) { described_class::MAX_CHUNKS_PER_FILE.next }

        it 'can initialize an instance with the max_chunks_size equals to MAX_CHUNKS_PER_FILE' do
          expect(instance.instance_variable_get(:@max_chunks_size)).to eq described_class::MAX_CHUNKS_PER_FILE
        end
      end
    end

    context 'when requested_chunk_size is not passed' do
      let(:instance) { described_class.new }

      it 'can initialize an object with the max_chunks_size equals to default max_chunks_size' do
        expect(instance.instance_variable_get(:@max_chunks_size)).to eq described_class::DEFAULT_REQUESTED_CHUNK_SIZE
      end
    end
  end

  describe '#blobs_for_project' do
    let_it_be(:project) { create(:project) }
    let(:result) do
      { project_id: project.id, content: 'foo', line: 5, path: 'bar', match_count_total: 0, match_count: 0,
        chunks: [] }
    end

    it 'instantiates Search::FoundMultiLineBlob with the correct values' do
      out = multi_match.blobs_for_project(result, project, 'main')
      expect(out).to have_attributes(
        path: 'bar', chunks: [], project_path: project.full_path,
        file_url: Gitlab::Routing.url_helpers.project_blob_url(project, File.join('main', result[:path])),
        blame_url: Gitlab::Routing.url_helpers.project_blame_url(project, File.join('main', result[:path])),
        match_count_total: 0,
        match_count: 0
      )
    end
  end

  describe '#zoekt_extract_result_pages_multi_match' do
    let(:per_page) { 20 }
    let(:page_limit) { 10 }
    let(:fixtures_path) { 'ee/spec/fixtures/search/zoekt/' }
    let(:raw_response) { File.read Rails.root.join(fixtures_path, 'flightjs_response_success.json') }
    let(:response) { ::Gitlab::Search::Zoekt::Response.new(::Gitlab::Json.parse(raw_response), code: 200) }
    let(:parsed_response_result_first) { response.parsed_response[:Result][:Files][0] }
    let(:file_count) { response.file_count }
    let(:expected_extracted_result) do
      json_result = File.read Rails.root.join(fixtures_path, extracted_result_path)
      ::Gitlab::Json.parse(json_result).deep_symbolize_keys.transform_keys { |key| key.to_s.to_i }
    end

    subject(:extracted_result) { multi_match.zoekt_extract_result_pages_multi_match(response, per_page, page_limit) }

    context 'when per_page is less than the total number of files in the response' do
      let(:per_page) { 2 }
      let(:extracted_result_path) { 'extracted_full_result_in_2_pages.json' }

      it 'extract all results in 2 pages' do
        expect(extracted_result).to eq expected_extracted_result
      end

      context 'when page_limit is less than the total number of pages in the response' do
        let(:page_limit) { 1 }
        let(:extracted_result_path) { 'extracted_partial_result_in_1_page.json' }

        it 'extract results until the page limit is hit' do
          expect(extracted_result).to eq expected_extracted_result
        end
      end
    end

    context 'when per_page is greater than or equal to total number of files in the response' do
      let(:extracted_result_path) { 'extracted_full_result_in_1_page.json' }

      it 'extract all results in a single page' do
        expect(extracted_result).to eq expected_extracted_result
      end
    end

    context 'when response contains non utf-8 characters' do
      let(:raw_response) { File.read Rails.root.join(fixtures_path, 'non_utf8_characters_raw_response.json') }

      it 'does not raise any error' do
        expect { extracted_result }.not_to raise_error
        expect(extracted_result[0].first[:chunks][0][:lines][0][:text]).to eq "GIT_AUTHOR_NAME=\"Áéí óú\" &&"
      end
    end

    context 'when match is in middle and chunk contains no newlines' do
      let(:raw_response) { File.read Rails.root.join(fixtures_path, 'response_match_in_middle_no_newlines.json') }
      let(:extracted_result_path) { 'extracted_result_match_in_middle.json' }

      it 'extract results with correct line numbers' do
        expect(extracted_result).to eq expected_extracted_result
      end
    end

    context 'when match is on the first line' do
      let(:raw_response) { File.read Rails.root.join(fixtures_path, 'response_match_on_first_line.json') }
      let(:extracted_result_path) { 'extracted_result_match_on_first_line.json' }

      it 'extract results with correct line numbers' do
        expect(extracted_result).to eq expected_extracted_result
      end
    end
  end
end
