# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::DuoEnterprise,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  subject(:add_on_license) { described_class.new(restrictions) }

  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
  let(:restrictions) do
    start_date = Date.current

    {
      add_on_products: {
        "duo_enterprise" => [
          {
            "quantity" => 1,
            "started_on" => start_date.to_s,
            "expires_on" => (start_date + 1.year).to_s,
            "purchase_xid" => "C-0000001",
            "trial" => false
          }
        ]
      }
    }
  end

  include_examples "license add-on attributes", add_on_name: "duo_enterprise"

  describe "#add_on" do
    it { expect(add_on_license.add_on).to eq add_on }
  end
end
