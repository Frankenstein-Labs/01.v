# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterprise::AdvantagesListComponent, :aggregate_failures, feature_category: :acquisition do
  let(:page_scope) { page }

  subject(:component) { render_inline(described_class.new) && page_scope }

  context 'when rendering advantages' do
    it 'displays check icons for all advantages' do
      expect(has_testid?('check-circle-icon', context: component, count: 5)).to be true
    end

    it 'displays advantage start text' do
      is_expected.to have_content(
        s_('DuoEnterpriseTrial|Stay on top of regulatory requirements')
      )
    end

    it 'displays advantage end text' do
      is_expected.to have_content(
        s_('DuoEnterpriseTrial|Maintain control and keep your data safe')
      )
    end
  end
end
