# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::Base,
  :aggregate_failures, feature_category: :"add-on_provisioning" do
  describe 'attribute methods' do
    subject(:add_on_license) { dummy_add_on_license_class.new(restrictions) }

    let(:add_on_license_base) { described_class.new(restrictions) }
    let!(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    let(:dummy_add_on_license_class) do
      Class.new(described_class) do
        def name
          :code_suggestions
        end

        def name_in_license
          :duo_pro
        end
      end
    end

    let(:start_date) { Date.current }
    let(:end_date) { start_date + 1.year }
    let(:trial) { false }
    let(:restrictions) do
      {
        add_on_products: {
          "duo_pro" => [
            {
              "quantity" => quantity,
              "started_on" => start_date.to_s,
              "expires_on" => end_date.to_s,
              "purchase_xid" => "C-0000001",
              "trial" => trial
            }
          ]
        }
      }
    end

    let(:quantity) { 1 }

    describe "#quantity" do
      it { expect { add_on_license_base.quantity }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.quantity).to eq quantity }
    end

    describe "license add-on behaviour" do
      include_examples "license add-on attributes", add_on_name: "duo_pro"
    end

    describe "#active?" do
      it { expect { add_on_license_base.active? }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license).to be_active }

      context "with quantity zero" do
        let(:quantity) { 0 }

        it { expect(add_on_license).not_to be_active }
      end
    end

    describe "#add_on" do
      it { expect { add_on_license_base.add_on }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.add_on).to eq(add_on) }

      context "without existing add-on" do
        let(:add_on) { nil }

        it "creates add-on" do
          expect { add_on_license.add_on }.to change { GitlabSubscriptions::AddOn.count }.from(0).to(1)
          expect(GitlabSubscriptions::AddOn.first).to be_code_suggestions
        end
      end
    end

    describe "#starts_at" do
      it { expect { add_on_license_base.starts_at }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.starts_at).to eq(start_date) }

      context 'without add-on info' do
        let(:restrictions) do
          { add_on_products: {} }
        end

        it { expect(add_on_license.starts_at).to be_nil }
      end
    end

    describe "#expires_on" do
      it { expect { add_on_license_base.expires_on }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.expires_on).to eq(end_date) }

      context 'without add-on info' do
        let(:restrictions) do
          { add_on_products: {} }
        end

        it { expect(add_on_license.expires_on).to be_nil }
      end
    end

    describe "#purchase_xid" do
      it { expect { add_on_license_base.purchase_xid }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license.purchase_xid).to eq("C-0000001") }

      context 'without add-on info' do
        let(:restrictions) do
          { add_on_products: {} }
        end

        it { expect(add_on_license.purchase_xid).to be_nil }
      end
    end

    describe "#trial?" do
      let(:trial) { true }

      it { expect { add_on_license_base.trial? }.to raise_error described_class::MethodNotImplementedError }

      it { expect(add_on_license).to be_trial }

      context 'without add-on info' do
        let(:restrictions) do
          { add_on_products: {} }
        end

        it { expect(add_on_license).not_to be_trial }
      end
    end
  end
end
