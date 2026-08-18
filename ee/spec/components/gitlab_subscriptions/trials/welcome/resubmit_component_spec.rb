# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::Welcome::ResubmitComponent, feature_category: :acquisition do
  it_behaves_like 'resubmit component'
  it_behaves_like 'resubmit component with data attributes'

  describe 'component-specific behavior' do
    let(:hidden_fields) do
      {
        field_one: 'field one',
        field_two: 'field two'
      }
    end

    let(:submit_path) { '/some/path' }

    subject(:component) do
      render_inline(described_class.new(hidden_fields: hidden_fields, submit_path: submit_path)) && page
    end

    it 'renders form with put method' do
      expect(component).to have_css('form[method="post"]')
      expect(component).to have_css('input[name="_method"][value="put"]', visible: :hidden)
    end

    it 'applies extra top classes to content container' do
      expected_classes = %w[gl-p-8 gl-bg-subtle gl-rounded-t-lg gl-border]
      selector = ".gl-max-w-62.gl-mx-auto.gl-text-center.#{expected_classes.join('.')}"
      expect(component).to have_css(selector)
    end
  end
end
