# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::DetailSanitizer, feature_category: :vulnerability_management do
  let(:dummy_class) { Class.new { include Vulnerabilities::DetailSanitizer } }
  let(:sanitizer) { dummy_class.new }

  describe '#sanitize_detail' do
    subject(:result) { sanitizer.sanitize_detail(detail) }

    context 'when detail has an unknown type' do
      let(:detail) do
        {
          'type' => 'unknown-type',
          'name' => 'safe',
          'thAttr' => { 'onclick' => 'alert(1)' }
        }.with_indifferent_access
      end

      it 'strips unexpected keys keeping only base keys' do
        expect(result).not_to have_key('thAttr')
        expect(result).to include('type' => 'unknown-type', 'name' => 'safe')
      end
    end

    context 'when detail has no type' do
      let(:detail) { { 'field_name' => 'test', 'value' => 'x' }.with_indifferent_access }

      it 'strips keys not in base keys' do
        expect(result).not_to have_key('value')
        expect(result).to include('field_name' => 'test')
      end
    end

    context 'when detail is a text type' do
      let(:detail) do
        { 'type' => 'text', 'value' => 'hello', 'thAttr' => { 'onclick' => 'alert(1)' } }.with_indifferent_access
      end

      it 'strips unexpected keys' do
        expect(result).not_to have_key('thAttr')
      end

      it 'keeps allowed keys' do
        expect(result).to include('type' => 'text', 'value' => 'hello')
      end
    end

    context 'when detail is a url type' do
      let(:detail) do
        {
          'type' => 'url',
          'href' => 'https://example.com',
          'thAttr' => { 'onmouseover' => 'alert(1)' }
        }.with_indifferent_access
      end

      it 'strips unexpected keys' do
        expect(result).not_to have_key('thAttr')
      end

      it 'keeps allowed keys' do
        expect(result).to include('type' => 'url', 'href' => 'https://example.com')
      end
    end

    context 'when detail is a table type' do
      let(:detail) do
        {
          'type' => 'table',
          'header' => [
            {
              'type' => 'text',
              'value' => 'Column',
              'class' => 'js-gfm-input',
              'thAttr' => { 'onmouseover' => 'alert(1)' }
            }
          ],
          'rows' => [
            [{ 'type' => 'text', 'value' => '1', 'thAttr' => { 'onclick' => 'alert(1)' } }]
          ]
        }.with_indifferent_access
      end

      it 'strips unexpected keys from header items' do
        expect(result['header'].first).not_to have_key('class')
        expect(result['header'].first).not_to have_key('thAttr')
      end

      it 'strips unexpected keys from row cells' do
        expect(result['rows'].first.first).not_to have_key('thAttr')
      end

      it 'keeps allowed keys in header items' do
        expect(result['header'].first).to include('type' => 'text', 'value' => 'Column')
      end

      context 'when header contains non-hash items' do
        let(:detail) do
          {
            'type' => 'table',
            'header' => ['Col name 1', 'Col name 2'],
            'rows' => []
          }.with_indifferent_access
        end

        it 'leaves non-hash header items untouched' do
          expect(result['header']).to eq(['Col name 1', 'Col name 2'])
        end
      end

      context 'when header is not an Array' do
        let(:detail) do
          {
            'type' => 'table',
            'header' => 'not an array',
            'rows' => []
          }.with_indifferent_access
        end

        it 'leaves header untouched' do
          expect(result['header']).to eq('not an array')
        end
      end

      context 'when rows is not an Array' do
        let(:detail) do
          {
            'type' => 'table',
            'header' => [],
            'rows' => 'not an array'
          }.with_indifferent_access
        end

        it 'leaves rows untouched' do
          expect(result['rows']).to eq('not an array')
        end
      end

      context 'when rows contains a non-Array row' do
        let(:detail) do
          {
            'type' => 'table',
            'header' => [],
            'rows' => ['not an array row']
          }.with_indifferent_access
        end

        it 'leaves non-array rows untouched' do
          expect(result['rows']).to eq(['not an array row'])
        end
      end
    end

    context 'when detail is a code-flow-node type' do
      let(:detail) do
        {
          'type' => 'code-flow-node',
          'node_type' => 'entry',
          'file_location' => {
            'type' => 'file-location',
            'file_name' => 'app.rb',
            'line_start' => 1,
            'malicious_key' => 'inject'
          },
          'thAttr' => { 'onclick' => 'alert(1)' }
        }.with_indifferent_access
      end

      it 'strips unexpected top-level keys' do
        expect(result).not_to have_key('thAttr')
      end

      it 'strips unexpected keys from nested file_location' do
        expect(result['file_location']).not_to have_key('malicious_key')
      end

      it 'keeps allowed keys in file_location' do
        expect(result['file_location']).to include(
          'type' => 'file-location',
          'file_name' => 'app.rb',
          'line_start' => 1
        )
      end
    end

    context 'when detail is a code-flows type' do
      context 'when items is not an Array' do
        let(:detail) do
          {
            'type' => 'code-flows',
            'items' => 'not an array'
          }.with_indifferent_access
        end

        it 'leaves items untouched' do
          expect(result['items']).to eq('not an array')
        end
      end

      context 'when items contains a non-Array flow' do
        let(:detail) do
          {
            'type' => 'code-flows',
            'items' => ['not an array flow']
          }.with_indifferent_access
        end

        it 'leaves non-array flows untouched' do
          expect(result['items']).to eq(['not an array flow'])
        end
      end
    end

    context 'when detail is a list type' do
      context 'when items is an Array' do
        let(:detail) do
          {
            'type' => 'list',
            'items' => [
              { 'type' => 'url', 'href' => 'https://example.com', 'thAttr' => { 'onclick' => 'alert(1)' } }
            ]
          }.with_indifferent_access
        end

        it 'strips unexpected keys from list items' do
          expect(result['items'].first).not_to have_key('thAttr')
        end

        it 'keeps allowed keys in list items' do
          expect(result['items'].first).to include('type' => 'url', 'href' => 'https://example.com')
        end
      end

      context 'when items is not an Array' do
        let(:detail) do
          { 'type' => 'list', 'items' => 'not an array' }.with_indifferent_access
        end

        it 'leaves items untouched' do
          expect(result['items']).to eq('not an array')
        end
      end
    end
  end
end
