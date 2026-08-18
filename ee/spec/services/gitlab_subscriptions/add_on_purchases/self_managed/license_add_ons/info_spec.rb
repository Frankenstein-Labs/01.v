# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::LicenseAddOns::Info,
  feature_category: :"add-on_provisioning" do
  let(:quantity) { 10 }
  let(:started_on) { Date.current - 2.days }
  let(:expires_on) { Date.current + 7.days }
  let(:purchase_xid) { 'C-12345678' }
  let(:trial) { false }

  describe '#initialize' do
    subject(:pack) do
      described_class.new(**attributes)
    end

    let(:attributes) do
      {
        quantity: quantity,
        started_on: started_on,
        expires_on: expires_on,
        purchase_xid: purchase_xid,
        trial: trial
      }
    end

    it 'initializes with quantity, started_at, expires_on, purchase_xid, and trial' do
      expect(pack).to have_attributes(
        quantity: quantity,
        started_on: started_on,
        expires_on: expires_on,
        purchase_xid: purchase_xid,
        trial: trial
      )
    end

    context 'when quantity is not an integer' do
      let(:attributes) do
        super().merge(quantity: quantity.to_s)
      end

      it 'converts quantity to an integer' do
        expect(pack.quantity).to eq(quantity.to_i)
      end
    end

    context 'when started_on is a string' do
      let(:attributes) do
        super().merge(started_on: started_on.to_s)
      end

      it 'converts started_on to a date' do
        expect(pack.started_on).to eq(started_on.to_date)
      end
    end

    context 'when started_on cannot be converted to a date' do
      let(:attributes) do
        super().merge(started_on: 'invalid')
      end

      it 'returns nil for started_on' do
        expect(pack.started_on).to be_nil
      end
    end

    context 'when expires_on is a string' do
      let(:attributes) do
        super().merge(expires_on: expires_on.to_s)
      end

      it 'converts expires_on to a date' do
        expect(pack.expires_on).to eq(expires_on.to_date)
      end
    end

    context 'when expires_on cannot be converted to a date' do
      let(:attributes) do
        super().merge(expires_on: 'invalid')
      end

      it 'returns nil for expires_on' do
        expect(pack.expires_on).to be_nil
      end
    end

    context 'when trial is true' do
      let(:attributes) do
        super().merge(trial: true)
      end

      it 'sets trial to true' do
        expect(pack.trial).to be(true)
      end
    end

    context 'when trial is not given' do
      let(:attributes) do
        super().except(:trial)
      end

      it 'defaults to false for trial' do
        expect(pack.trial).to be(false)
      end
    end
  end

  describe '#active?' do
    subject(:active?) { described_class.new(**attributes).active? }

    let(:attributes) do
      {
        quantity: quantity,
        started_on: started_on,
        expires_on: expires_on,
        purchase_xid: purchase_xid,
        trial: trial
      }
    end

    context 'when started_on is blank' do
      let(:started_on) { nil }

      it { is_expected.to be(false) }
    end

    context 'when expires_on is blank' do
      let(:expires_on) { nil }

      it { is_expected.to be(false) }
    end

    context 'when started_on is today' do
      let(:started_on) { Date.current }

      it { is_expected.to be(true) }
    end

    context 'when started_on is in the future' do
      let(:started_on) { Date.current + 1.day }

      it { is_expected.to be(false) }
    end

    context 'when expires_on is in the past' do
      let(:expires_on) { Date.current - 1.day }

      it { is_expected.to be(false) }
    end

    context 'when expires_on is today' do
      let(:expires_on) { Date.current }

      it { is_expected.to be(false) }
    end

    it { is_expected.to be(true) }
  end
end
