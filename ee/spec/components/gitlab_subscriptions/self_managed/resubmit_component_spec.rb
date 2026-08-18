# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::ResubmitComponent, feature_category: :acquisition do
  it_behaves_like 'resubmit component'

  describe 'event tracking' do
    let(:hidden_fields) { { field_one: 'value' } }
    let(:submit_path) { '/some/path' }

    subject(:component) { render_inline(described_class.new(hidden_fields: hidden_fields, submit_path: submit_path)) }

    it 'includes the resubmit button tracking event' do
      expect(component).to have_selector('[data-event-tracking]')
      expect(component).to trigger_internal_events('sm_trial_create_form_resubmit_click').on_click
    end
  end
end
