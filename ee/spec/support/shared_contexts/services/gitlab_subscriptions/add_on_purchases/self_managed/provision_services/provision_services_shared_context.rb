# frozen_string_literal: true

RSpec.shared_context 'with provision services common setup' do
  subject(:provision_service) { described_class.new }

  let_it_be(:organization, freeze: false) { create(:organization) }
  let_it_be(:started_at, freeze: false) { Date.current }

  let(:add_ons) { [] }
  let(:quantity) { 1 }
  let(:trial) { false }
  let(:namespace) { nil }
  let(:purchase_xid) { '123456789' }

  before do
    create_current_license(
      cloud_licensing_enabled: true,
      restrictions: {
        add_on_products: add_on_products(
          add_ons: add_ons,
          started_at: started_at,
          quantity: quantity,
          purchase_xid: purchase_xid,
          trial: trial
        ),
        subscription_name: 'A-S00000001'
      }
    )
  end

  def add_on_products(**params)
    add_ons.index_with({}) do
      [
        {
          "quantity" => params[:quantity],
          "started_on" => params[:started_at].to_s,
          "expires_on" => (params[:started_at] + 1.year).to_s,
          "purchase_xid" => params[:purchase_xid],
          "trial" => params[:trial]
        }
      ]
    end
  end
end
