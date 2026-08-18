# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Vulnerabilities::DetailsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  describe '.with_field_name' do
    subject { described_class.with_field_name(items) }

    context 'when there are no items' do
      let(:items) { nil }

      it { is_expected.to eq([]) }
    end

    context 'when there are items with field name' do
      let(:items) do
        {
          field: {
            value: :x
          },
          field_2: {
            value: :y
          }
        }
      end

      it { is_expected.to eq([{ value: :x, field_name: :field }, { value: :y, field_name: :field_2 }]) }
    end
  end

  describe '#resolve' do
    subject { resolve(described_class, obj: object, args: {}, ctx: {}) }

    context 'when object is from database' do
      let(:object) { double(finding_details: finding_details) }

      context 'when there are no items in finding details' do
        let(:finding_details) { nil }

        it { is_expected.to eq([]) }
      end

      context 'when there are items in finding details' do
        let(:finding_details) do
          {
            field: {
              type: 'text',
              value: :x
            },
            field_2: {
              type: 'text',
              value: :y
            }
          }
        end

        it { is_expected.to match_array([{ 'field_name' => 'field', 'type' => 'text', 'value' => :x }, { 'field_name' => 'field_2', 'type' => 'text', 'value' => :y }]) }
      end

      context 'when a table detail contains malicious keys in header items' do
        subject(:details) { resolve(described_class, obj: object, args: {}, ctx: {}) }

        let(:finding_details) do
          {
            'table_1' => {
              'type' => 'table',
              'header' => [
                {
                  'type' => 'text',
                  'value' => 'Column',
                  'class' => 'js-gfm-input',
                  'thAttr' => { 'onmouseover' => 'alert(document.cookie)' }
                }
              ],
              'rows' => [
                [{ 'type' => 'text', 'value' => '1', 'thAttr' => { 'onclick' => 'alert(1)' } }]
              ]
            }
          }
        end

        it 'strips unexpected keys from header items' do
          table = details.first
          expect(table['header'].first).not_to have_key('class')
          expect(table['header'].first).not_to have_key('thAttr')
        end

        it 'strips unexpected keys from row cells' do
          table = details.first
          expect(table['rows'].first.first).not_to have_key('thAttr')
        end
      end
    end

    context 'when object is from artifact' do
      let(:object) { { 'details' => details } }

      context 'when there are no items in details' do
        let(:details) { nil }

        it { is_expected.to eq([]) }
      end

      context 'when there are items in details' do
        let(:details) do
          {
            field: {
              type: 'text',
              value: :a
            },
            field_2: {
              type: 'text',
              value: :b
            }
          }
        end

        it { is_expected.to match_array([{ 'field_name' => 'field', 'type' => 'text', 'value' => :a }, { 'field_name' => 'field_2', 'type' => 'text', 'value' => :b }]) }
      end
    end

    context 'when finding is secret_redacted' do
      let_it_be(:project) { create(:project) }
      let_it_be(:vulnerability) do
        create(:vulnerability, :with_finding, report_type: :secret_detection, project: project)
      end

      let_it_be(:rep_info) do
        create(:vulnerability_representation_information, vulnerability: vulnerability, removed_from_code: true)
      end

      let(:object) { vulnerability }

      it { is_expected.to eq([]) }
    end
  end
end
