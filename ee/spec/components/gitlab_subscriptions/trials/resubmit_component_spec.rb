# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::ResubmitComponent, feature_category: :acquisition do
  let(:hidden_fields) do
    {
      field_one: 'field one',
      field_two: 'field two'
    }
  end

  let(:submit_path) { '/some/path' }

  subject(:component) { render_inline(described_class.new(hidden_fields: hidden_fields, submit_path: submit_path)) }

  it 'raises not implemented error' do
    expect { component }.to raise_error NoMethodError
  end
end
