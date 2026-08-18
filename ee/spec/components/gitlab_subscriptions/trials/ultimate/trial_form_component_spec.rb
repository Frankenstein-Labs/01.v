# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::Ultimate::TrialFormComponent, :aggregate_failures, feature_category: :acquisition do
  it_behaves_like described_class do
    let(:additional_kwargs) { {} }
    let(:extra_namespace_data) { {} }
  end
end
