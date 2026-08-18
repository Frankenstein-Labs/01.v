# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCapHelper, feature_category: :seat_cost_management do
  describe '#over_limit_body_text' do
    it 'has expected text' do
      result = helper.over_limit_body_text('_namespace_name_')

      expect(result).to have_text(s_('FreeUserCap|You have exceeded your limit of'))
      expect(result).to have_text('_namespace_name_')
    end
  end

  describe '#over_limit_body_secondary_text' do
    let(:trial_duration) { 30 }

    it 'has expected text' do
      result = helper.over_limit_body_secondary_text('_trial_url_', '_upgrade_url_', trial_duration)

      expect(result).to have_text(s_('FreeUserCap|To remove the'))
      expect(result).to have_text(s_('FreeUserCap|start a free 30-day trial'))
      expect(result).to have_text(s_('FreeUserCap|You can also'))
    end

    context 'with html tags' do
      it 'has html tags' do
        result = helper.over_limit_body_secondary_text('_trial_url_', '_upgrade_url_', trial_duration)

        expect(result).to include('<a')
        expect(result).to include('</a>')
      end
    end

    context 'without html tags' do
      it 'has no html tags' do
        result = helper.over_limit_body_secondary_text('_trial_url_', '_upgrade_url_', trial_duration, html_tags: false)

        expect(result).not_to include('<a')
        expect(result).not_to include('</a>')
      end
    end
  end

  describe '#over_limit_title' do
    it 'has expected text' do
      expect(helper.over_limit_title).to have_text(s_("FreeUserCap|You've exceeded your user limit"))
    end
  end
end
