# frozen_string_literal: true

RSpec.shared_examples 'call runner to handle the provision of add-ons' do
  it 'calls the runner to handle the provision of add-ons' do
    expect_next_instance_of(
      GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::AddOns
    ) do |runner|
      expect(runner).to receive(:execute).once.and_call_original
    end

    subject
  end
end

RSpec.shared_examples 'provision service have empty success response' do
  it 'returns a success' do
    expect(result[:status]).to eq(:success)
    expect(result[:add_on_purchase]).to eq(nil)
  end
end

RSpec.shared_examples 'provision service handles error' do |service_class|
  it 'logs and returns an error' do
    allow_next_instance_of(service_class) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'Something went wrong'))
    end

    expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
    expect(result[:status]).to eq(:error)
    expect(result[:message]).to eq('Error syncing subscription add-on purchases. Message: Something went wrong')
  end
end

RSpec.shared_examples 'provision service expires add-on purchase' do
  context 'with existing add-on purchase' do
    let(:expires_on) { Date.current + 3.months }
    let(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        namespace: namespace,
        add_on: add_on,
        started_at: Date.current,
        expires_on: expires_on
      )
    end

    it 'does not call any service to create or update an add-on purchase' do
      expect(GitlabSubscriptions::AddOnPurchases::CreateService).not_to receive(:new)
      expect(GitlabSubscriptions::AddOnPurchases::UpdateService).not_to receive(:new)

      result
    end

    context 'when the expiration fails' do
      it_behaves_like 'provision service handles error', GitlabSubscriptions::AddOnPurchases::SelfManaged::ExpireService
    end

    it 'expires the existing add-on purchase' do
      expect do
        result
        add_on_purchase.reload
      end.to change { add_on_purchase.expires_on }.from(expires_on).to(Date.yesterday)
    end

    it_behaves_like 'provision service have empty success response'
  end

  context 'without existing add-on purchase' do
    it 'does not call any of the services to update an add-on purchase' do
      expect(GitlabSubscriptions::AddOnPurchases::CreateService).not_to receive(:new)
      expect(GitlabSubscriptions::AddOnPurchases::UpdateService).not_to receive(:new)
      expect(GitlabSubscriptions::AddOnPurchases::SelfManaged::ExpireService).not_to receive(:new)

      result
    end

    it_behaves_like 'provision service have empty success response'
  end
end

RSpec.shared_examples 'provision service updates the existing add-on purchase' do
  it 'updates the existing add-on purchase' do
    expect(GitlabSubscriptions::AddOnPurchases::UpdateService).to receive(:new)
      .with(
        namespace,
        add_on,
        {
          add_on_purchase: add_on_purchase,
          quantity: quantity,
          started_on: starts_at,
          expires_on: starts_at + 1.year,
          purchase_xid: purchase_xid,
          trial: false
        }
      ).and_call_original

    expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

    expect(result[:status]).to eq(:success)
    expect(result[:add_on_purchase]).to have_attributes(
      id: add_on_purchase.id,
      started_at: starts_at,
      expires_on: starts_at + 1.year,
      quantity: quantity,
      purchase_xid: purchase_xid,
      trial: false
    )
  end
end

RSpec.shared_examples 'provision service creates add-on purchase' do
  it 'creates a new add-on purchase' do
    expect(GitlabSubscriptions::AddOnPurchases::CreateService).to receive(:new).with(
      namespace,
      add_on,
      {
        add_on_purchase: nil,
        quantity: quantity,
        started_on: starts_at,
        expires_on: starts_at + 1.year,
        purchase_xid: purchase_xid,
        trial: false
      }
    ).and_call_original

    expect { result }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

    expect(result[:status]).to eq(:success)
    expect(result[:add_on_purchase].add_on.name).to eq('code_suggestions')
    expect(result[:add_on_purchase]).to have_attributes(
      started_at: starts_at,
      expires_on: starts_at + 1.year,
      quantity: quantity,
      purchase_xid: purchase_xid,
      trial: false
    )
  end
end

RSpec.shared_examples 'delegates add_on params to license_add_on' do
  it { is_expected.to delegate_method(:add_on).to(:license_add_on) }
  it { is_expected.to delegate_method(:quantity).to(:license_add_on) }
  it { is_expected.to delegate_method(:starts_at).to(:license_add_on) }
  it { is_expected.to delegate_method(:expires_on).to(:license_add_on) }
  it { is_expected.to delegate_method(:purchase_xid).to(:license_add_on) }
end
