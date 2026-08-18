# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_amazon_q', feature_category: :ai_abstraction_layer do
  let(:feature_available) { true }

  # We use `view.render`, because just `render` throws a "no implicit conversion of nil into String" exception
  # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/53093#note_499060593
  subject(:rendered) { view.render('admin/application_settings/amazon_q') }

  before do
    allow(::Ai::AmazonQ).to receive(:feature_available?).and_return(feature_available)
  end

  context 'when feature available' do
    it 'renders settings' do
      expect(rendered).to have_css('#js-amazon-q-settings')
      expect(rendered).to have_link(
        s_('AmazonQ|View configuration setup'),
        href: edit_admin_application_settings_integration_path(:amazon_q)
      )
    end
  end

  context 'when feature not available' do
    let(:feature_available) { false }

    it 'renders nothing' do
      expect(rendered).to be_nil
    end
  end
end
