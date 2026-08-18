# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::DeploymentEntity, feature_category: :deployment_management do
  let(:deployment) { build_stubbed(:deployment) }

  subject { described_class.new(deployment).as_json }

  it 'exposes id' do
    expect(subject).to include(:id)
  end

  it 'exposes iid' do
    expect(subject).to include(:iid)
  end

  it 'exposes deployable name' do
    expect(subject).to include(:deployable)
    expect(subject[:deployable]).to include(:name)
  end
end
