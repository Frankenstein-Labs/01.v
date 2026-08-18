# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro::AdvantagesListComponent, :aggregate_failures, feature_category: :acquisition do
  let(:page_scope) { page }

  subject(:component) { render_inline(described_class.new) && page_scope }

  context 'when rendering advantages' do
    it 'displays check icons for all advantages' do
      expect(has_testid?('check-circle-icon', context: component, count: 6)).to be true
    end

    it 'displays advantage start text' do
      is_expected.to have_content(
        s_('DuoProTrial|Code completion and code generation with Code Suggestions')
      )
    end

    it 'displays advantage end text' do
      is_expected.to have_content(
        s_('DuoProTrial|Organizational user controls')
      )
    end
  end
end
