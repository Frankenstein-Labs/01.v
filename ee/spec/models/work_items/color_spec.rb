# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Color, feature_category: :portfolio_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace).inverse_of(:work_items_colors) }
    it { is_expected.to belong_to(:work_item).with_foreign_key('issue_id').inverse_of(:color) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:color) }
  end

  it 'ensures to use work_item namespace' do
    work_item = create(:work_item)
    date_source = described_class.new(work_item: work_item)

    date_source.valid?

    expect(date_source.namespace).to eq(work_item.namespace)
  end

  describe 'COLOR_HEX_TO_NAME' do
    it 'stays in sync with EPIC_COLORS in the frontend constants' do
      js_path = Rails.root.join('app/assets/javascripts/work_items/constants.js')
      js_content = File.read(js_path)

      frontend_entries = js_content.scan(/'(#[0-9a-f]{6})':\s*s__\('WorkItem\|([^']+)'\)/)
      frontend_map = frontend_entries.to_h

      expect(described_class::COLOR_HEX_TO_NAME).to eq(frontend_map),
        "COLOR_HEX_TO_NAME is out of sync with EPIC_COLORS in #{js_path}. " \
          "Please update the Ruby constant to match the frontend."
    end
  end

  describe '#text_color' do
    using RSpec::Parameterized::TableSyntax

    where(:epic_color, :expected_text_color) do
      WorkItems::Color::DEFAULT_COLOR | ::Gitlab::Color.of('#FFFFFF')
      ::Gitlab::Color.of('#FFFFFF') | ::Gitlab::Color.of('#1F1E24')
      ::Gitlab::Color.of('#000000') | ::Gitlab::Color.of('#FFFFFF')
    end

    with_them do
      it 'returns correct text color' do
        color = build(:color, color: epic_color)

        expect(color.text_color).to be_color(expected_text_color)
      end
    end
  end
end
