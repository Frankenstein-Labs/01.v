# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::TrialFormComponent, feature_category: :acquisition do
  let(:user) { build(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

  subject(:component) { render_inline(described_class.new(user: user)) && page }

  describe 'rendering' do
    it 'renders the trial form heading' do
      is_expected.to have_content(_('Start your free Ultimate trial!'))
    end

    it 'renders the form element' do
      is_expected.to have_css('#js-start-trial-form')
    end

    it 'renders the trial link' do
      is_expected.to have_link _('GitLab.com'), href: promo_url(path: '/free-trial', query: { hosted: 'self-managed' })
    end

    it 'includes the com link tracking event' do
      is_expected.to trigger_internal_events('sm_trial_create_form_com_click').on_click
    end
  end

  describe 'form data' do
    it 'includes user data in the form' do
      form_data = parsed_form_data

      expect(form_data['userData']).to eq(
        'firstName' => user.first_name,
        'lastName' => user.last_name,
        'emailAddress' => user.email
      )
    end

    it 'includes the correct submit path' do
      form_data = parsed_form_data

      expect(form_data['submitPath']).to eq(self_managed_trials_path)
    end
  end

  private

  def parsed_form_data
    form_element = component.find('#js-start-trial-form')
    form_data = form_element['data-view-model']
    ::Gitlab::Json.safe_parse(form_data)
  end
end
