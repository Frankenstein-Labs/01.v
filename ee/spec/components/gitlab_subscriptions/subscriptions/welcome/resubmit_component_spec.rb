# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Subscriptions::Welcome::ResubmitComponent, :aggregate_failures, feature_category: :acquisition do
  let(:hidden_fields) { { first_name: 'John', last_name: 'Doe', company_name: 'test' } }
  let(:submit_path) { '/submit' }

  before do
    render_inline(described_class.new(hidden_fields: hidden_fields, submit_path: submit_path))
  end

  subject(:component) { page }

  it 'renders the registration unsuccessful heading' do
    is_expected.to have_content(_('Registration unsuccessful'))
  end

  it 'renders the resubmit description' do
    is_expected.to have_content(
      _("We're sorry, your registration could not be completed. Please resubmit below to complete your setup.")
    )
  end

  it 'renders the resubmit form with correct action' do
    form = component.find('form[data-testid="premium-resubmit-form"]')

    expect(form['action']).to eq(submit_path)
  end

  it 'renders hidden fields' do
    hidden_fields.each do |field, value|
      expect(component).to have_css("input[type='hidden'][name='#{field}'][value='#{value}']", visible: :hidden)
    end
  end

  it 'renders the resubmit button' do
    is_expected.to have_button(_('Resubmit request'))
  end
end
