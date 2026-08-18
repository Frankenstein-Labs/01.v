# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:cleanup:duo_add_on_purchase_upgrade', :silence_stdout, type: :task, feature_category: :"add-on_provisioning" do
  let(:namespace) { create(:namespace) }
  let(:namespace_id_arg) { namespace.id }
  let(:run) { run_rake_task('gitlab:cleanup:duo_add_on_purchase_upgrade', namespace_id_arg) }

  before do
    Rake.application.rake_require 'tasks/gitlab/gitlab_subscriptions/cleanup_duo_add_on_purchase_upgrade'
  end

  context 'when the namespace ID is blank' do
    let(:namespace_id_arg) { '' }

    it 'aborts and prints an error message' do
      expect { run }.to raise_error(ArgumentError).with_message('Namespace ID is required')
    end
  end

  context 'when the namespace does not exist' do
    let(:namespace_id_arg) { 'unknown' }

    it 'aborts and prints an error message' do
      expect { run }.to raise_error(ArgumentError).with_message('Namespace does not exist')
    end
  end

  context 'when there is no add-on purchases' do
    it 'aborts and prints an error message' do
      expect { run }.to raise_error(ArgumentError).with_message(
        "Expected both Duo add-ons. Duo Pro ID: , Duo Enterprise ID: "
      )
    end
  end

  context 'when there is only the Duo Enterprise add-on purchases' do
    it 'aborts and prints an error message' do
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)

      expect { run }.to raise_error(ArgumentError).with_message(
        "Expected both Duo add-ons. Duo Pro ID: , Duo Enterprise ID: #{add_on_purchase.id}"
      )
    end
  end

  context 'when there is only the Duo Pro add-on purchases' do
    it 'aborts and prints an error message' do
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)

      expect { run }.to raise_error(ArgumentError).with_message(
        "Expected both Duo add-ons. Duo Pro ID: #{add_on_purchase.id}, Duo Enterprise ID: "
      )
    end
  end

  context 'when there are a Duo Pro and a Duo Enterprise add-on purchases' do
    let!(:duo_pro_add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
    end

    let!(:duo_enterprise_add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
    end

    it 'prints information' do
      expected_output = <<~OUTPUT
        Successfully destroyed the Duo Enterprise add-on purchase
        Successfully upgraded Duo Pro to Duo Enterprise
        Cleanup finished 🎉
      OUTPUT

      expect { run }.to output(expected_output).to_stdout
    end

    it 'successfully destroys the Duo Enterprise add-on purchase' do
      expect { run }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(-1)

      expect { duo_pro_add_on_purchase.reload }.not_to raise_error
      expect { duo_enterprise_add_on_purchase.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'successfully upgrades the Duo Pro add-on purchase to Duo Enterprise' do
      run

      expect(duo_pro_add_on_purchase.reload.add_on).to be_duo_enterprise
    end
  end
end
