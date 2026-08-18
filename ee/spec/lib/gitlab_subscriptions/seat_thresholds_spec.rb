# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe GitlabSubscriptions::SeatThresholds, feature_category: :seat_cost_management do
  describe '.threshold_reached?' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.threshold_reached?(seats_total: seats_total, seats_used: seats_used) }

    context 'when seats_total is nil' do
      let(:seats_total) { nil }
      let(:seats_used) { 5 }

      it { is_expected.to be false }
    end

    context 'when seats_used is nil' do
      let(:seats_total) { 10 }
      let(:seats_used) { nil }

      it { is_expected.to be false }
    end

    context 'when seats_total is 0' do
      let(:seats_total) { 0 }
      let(:seats_used) { 0 }

      it { is_expected.to be true }
    end

    context 'with tier boundary values' do
      where(:seats_total, :seats_used, :expected_result, :description) do
        # Boundary: 0-1 (edge cases in 0-15 tier, threshold: 1 seat)
        0   | 0   | true  | '0 seats, 0 used (at capacity)'
        1   | 0   | true  | '1 seat, 0 used (1 remaining = at threshold)'
        1   | 1   | true  | '1 seat, 1 used (at capacity)'
        2   | 1   | true  | '2 seats, 1 used (1 remaining = at threshold)'
        2   | 2   | true  | '2 seats, 2 used (at capacity)'

        # Boundary: 15 (last in 0-15 tier, threshold: 1 seat)
        15  | 14  | true  | '15 seats at threshold (1 remaining)'
        15  | 13  | false | '15 seats below threshold (2 remaining)'

        # Boundary: 15 (last in 0-15 tier, threshold: 1 seat)
        15  | 14  | true  | '15 seats at threshold (1 remaining)'
        15  | 13  | false | '15 seats below threshold (2 remaining)'

        # Boundary: 16 (first in 16-25 tier, threshold: 2 seats)
        16  | 14  | true  | '16 seats at threshold (2 remaining)'
        16  | 13  | false | '16 seats below threshold (3 remaining)'

        # Boundary: 25 (last in 16-25 tier, threshold: 2 seats)
        25  | 23  | true  | '25 seats at threshold (2 remaining)'
        25  | 22  | false | '25 seats below threshold (3 remaining)'

        # Boundary: 26 (first in 26-99 tier, threshold: 10%)
        26  | 24  | true  | '26 seats at threshold (2 remaining = 7.7%)'
        26  | 22  | false | '26 seats below threshold (4 remaining = 15.4%)'

        # Boundary: 99 (last in 26-99 tier, threshold: 10%)
        99  | 90  | true  | '99 seats at threshold (9 remaining = 9.1%)'
        99  | 88  | false | '99 seats below threshold (11 remaining = 11.1%)'

        # Boundary: 100 (first in 100-999 tier, threshold: 8%)
        100 | 92  | true  | '100 seats at threshold (8 remaining = 8%)'
        100 | 91  | false | '100 seats below threshold (9 remaining = 9%)'

        # Boundary: 999 (last in 100-999 tier, threshold: 8%)
        999 | 920 | true  | '999 seats at threshold (79 remaining = 7.9%)'
        999 | 910 | false | '999 seats below threshold (89 remaining = 8.9%)'

        # Boundary: 1000 (first in 1000+ tier, threshold: 5%)
        1000 | 950 | true  | '1000 seats at threshold (50 remaining = 5%)'
        1000 | 949 | false | '1000 seats below threshold (51 remaining = 5.1%)'
      end

      with_them do
        it "returns #{params[:expected_result]} for #{params[:description]}" do
          is_expected.to eq(expected_result)
        end
      end
    end
  end

  describe '.small_subscription?' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.small_subscription?(seats_total) }

    where(:seats_total, :expected_result) do
      nil | false
      0   | true
      1   | true
      2   | true
      3   | false
      10  | false
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end
end
