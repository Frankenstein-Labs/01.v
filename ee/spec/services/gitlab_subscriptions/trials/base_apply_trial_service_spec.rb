# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::BaseApplyTrialService, feature_category: :acquisition do
  let(:apply_trial_params) do
    {
      uid: 'uid',
      trial_user_information: 'trial_user_information'
    }
  end

  subject(:execute) do
    described_class.execute(apply_trial_params)
  end

  it 'raises NoMethodError when valid_to_generate_trial? is not implemented' do
    expect { execute }.to raise_error(NoMethodError, 'Subclasses must implement valid_to_generate_trial? method')
  end

  it 'raises NoMethodError when execute_trial_request is not implemented' do
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:valid_to_generate_trial?).and_return(true)
    end

    expect { execute }.to raise_error(NoMethodError, 'Subclasses must implement execute_trial_request method')
  end

  it 'raises NoMethodError when add_on_purchase_finder is not implemented' do
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive_messages(
        valid_to_generate_trial?: true,
        execute_trial_request: { success: true },
        namespace: build(:namespace)
      )
    end

    expect { execute }.to raise_error(NoMethodError, 'Subclasses must implement add_on_purchase_finder method')
  end
end
