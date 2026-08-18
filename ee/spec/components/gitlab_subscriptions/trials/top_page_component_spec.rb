# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitlabSubscriptions::Trials::TopPageComponent, :aggregate_failures, feature_category: :acquisition do
  subject(:component) { described_class.new }

  it 'raises NoMethodError when not implemented in subclass' do
    expect { render_inline(component) }.to raise_error(NoMethodError, 'This method must be implemented in a subclass')
  end
end
