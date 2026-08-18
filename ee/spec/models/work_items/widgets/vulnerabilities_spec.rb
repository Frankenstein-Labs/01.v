# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Vulnerabilities, feature_category: :vulnerability_management do
  let_it_be(:work_item) { create(:work_item, :issue) }

  describe '#related_vulnerabilities' do
    subject { described_class.new(work_item).related_vulnerabilities }

    it { is_expected.to eq(work_item.related_vulnerabilities) }
  end
end
