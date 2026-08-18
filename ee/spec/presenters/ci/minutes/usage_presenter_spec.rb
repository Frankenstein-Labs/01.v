# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::UsagePresenter, feature_category: :hosted_runners do
  include ::Ci::MinutesHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:namespace) do
    create(:group, namespace_statistics: create(:namespace_statistics))
  end

  let(:usage) { Ci::Minutes::Usage.new(namespace) }
  let(:quota_enabled?) { true }
  let(:namespace_root?) { true }
  let(:any_project_with_shared_runners_enabled?) { true }
  let(:minutes_used) { 0 }
  let(:shared_runners_minutes_limit) { 100 }
  let(:extra_shared_runners_minutes_limit) { nil }

  subject(:presenter) { described_class.new(usage) }

  before do
    allow(usage).to receive(:quota_enabled?).and_return(quota_enabled?)
    allow(namespace).to receive(:root?).and_return(namespace_root?)
    allow(namespace).to receive(:any_project_with_shared_runners_enabled?)
      .and_return(any_project_with_shared_runners_enabled?)
    namespace.shared_runners_minutes_limit = shared_runners_minutes_limit
    namespace.extra_shared_runners_minutes_limit = extra_shared_runners_minutes_limit
    set_ci_minutes_used(namespace, minutes_used)
  end

  describe 'Monthly usage' do
    context 'when instance runners are disabled' do
      let(:any_project_with_shared_runners_enabled?) { false }

      describe '#monthly_minutes_label' do
        it 'returns not supported label with no usage' do
          label = presenter.monthly_minutes_label

          expect(label.text).to eq "0 / Not supported"
          expect(label.css_class).to eq "gl-text-success"
        end
      end

      describe '#monthly_minutes_limit_text' do
        subject { presenter.monthly_minutes_limit_text }

        it { is_expected.to eq "Not supported" }
      end
    end

    context 'when quota is disabled' do
      let(:quota_enabled?) { false }

      context 'when minutes are not used' do
        describe '#monthly_minutes_label' do
          it 'returns unlimited label with no usage' do
            label = presenter.monthly_minutes_label

            expect(label.text).to eq "0 / Unlimited"
            expect(label.css_class).to eq ""
          end
        end

        describe '#monthly_percent_used' do
          subject { presenter.monthly_percent_used }

          it { is_expected.to eq 0 }
        end
      end

      context 'when minutes are used' do
        let(:minutes_used) { 20 }

        it 'returns unlimited label with usage' do
          label = presenter.monthly_minutes_label

          expect(label.text).to eq "20 / Unlimited"
          expect(label.css_class).to eq ""
        end

        describe '#monthly_percent_used' do
          subject { presenter.monthly_percent_used }

          it { is_expected.to eq 0 }
        end
      end

      describe '#monthly_minutes_limit_text' do
        subject { presenter.monthly_minutes_limit_text }

        it { is_expected.to eq "Unlimited" }
      end
    end

    context 'when quota is applied' do
      context 'when minutes are not all used' do
        let(:minutes_used) { 30 }

        it 'returns label with under usage' do
          label = presenter.monthly_minutes_label

          expect(label.text).to eq "30 / 100"
          expect(label.css_class).to eq 'gl-text-success'
        end

        describe '#monthly_minutes_used' do
          subject { presenter.monthly_minutes_used }

          it { is_expected.to eq 30 }
        end

        describe '#monthly_minutes_limit_text' do
          subject { presenter.monthly_minutes_limit_text }

          it { is_expected.to eq 100 }
        end

        describe '#monthly_percent_used' do
          subject { presenter.monthly_percent_used }

          it { is_expected.to eq 30 }
        end
      end

      context 'when minutes are all used' do
        let(:minutes_used) { 101 }

        it 'returns label with over quota' do
          label = presenter.monthly_minutes_label

          expect(label.text).to eq "101 / 100"
          expect(label.css_class).to eq 'gl-text-danger'
        end

        describe '#monthly_minutes_used' do
          subject { presenter.monthly_minutes_used }

          it { is_expected.to eq 101 }
        end

        describe '#monthly_percent_used' do
          subject { presenter.monthly_percent_used }

          it { is_expected.to eq 101 }
        end
      end
    end
  end

  describe 'Purchased minutes' do
    context 'when limit enabled' do
      context 'when extra minutes have been purchased' do
        let(:extra_shared_runners_minutes_limit) { 100 }

        context 'when all monthly minutes are used and some purchased minutes are used' do
          let(:minutes_used) { 150 }

          describe '#purchased_minutes_label' do
            it 'returns label with under quota' do
              label = presenter.purchased_minutes_label

              expect(label.text).to eq "50 / 100"
              expect(label.css_class).to eq "gl-text-success"
            end
          end

          describe '#purchased_minutes_used' do
            subject { presenter.purchased_minutes_used }

            it { is_expected.to eq 50 }
          end

          describe '#purchased_percent_used' do
            subject { presenter.purchased_percent_used }

            it { is_expected.to eq 50 }
          end
        end

        context 'when all monthly and all purchased minutes have been used' do
          let(:minutes_used) { 201 }

          describe '#purchased_minutes_label' do
            it 'returns label with over quota' do
              label = presenter.purchased_minutes_label

              expect(label.text).to eq "101 / 100"
              expect(label.css_class).to eq "gl-text-danger"
            end
          end

          describe '#purchased_minutes_used' do
            subject { presenter.purchased_minutes_used }

            it { is_expected.to eq 101 }
          end

          describe '#purchased_percent_used' do
            subject { presenter.purchased_percent_used }

            it { is_expected.to eq 101 }
          end
        end

        context 'when not all monthly minutes have been used' do
          let(:minutes_used) { 90 }

          describe '#purchased_minutes_label' do
            it 'returns label with no usage' do
              label = presenter.purchased_minutes_label

              expect(label.text).to eq "0 / 100"
              expect(label.css_class).to eq "gl-text-success"
            end
          end

          describe '#purchased_minutes_used' do
            subject { presenter.purchased_minutes_used }

            it { is_expected.to eq 0 }
          end

          describe '#purchased_percent_used' do
            subject { presenter.purchased_percent_used }

            it { is_expected.to eq 0 }
          end
        end
      end

      context 'when no extra minutes have been purchased' do
        context 'when all monthly minutes have been used' do
          let(:minutes_used) { 201 }

          describe '#purchased_minutes_label' do
            it 'returns label without usage' do
              label = presenter.purchased_minutes_label

              expect(label.text).to eq "0 / 0"
              expect(label.css_class).to eq "gl-text-success"
            end
          end

          describe '#purchased_minutes_used' do
            subject { presenter.purchased_minutes_used }

            it { is_expected.to eq 0 }
          end

          describe '#purchased_percent_used' do
            subject { presenter.purchased_percent_used }

            it { is_expected.to eq 0 }
          end
        end

        context 'when not all monthly minutes have been used' do
          let(:minutes_used) { 90 }

          describe '#purchased_minutes_label' do
            it 'returns label with no usage' do
              label = presenter.purchased_minutes_label

              expect(label.text).to eq "0 / 0"
              expect(label.css_class).to eq "gl-text-success"
            end
          end

          describe '#purchased_minutes_used' do
            subject { presenter.purchased_minutes_used }

            it { is_expected.to eq 0 }
          end

          describe '#purchased_percent_used' do
            subject { presenter.purchased_percent_used }

            it { is_expected.to eq 0 }
          end
        end
      end
    end
  end

  describe '#any_project_enabled?' do
    subject { presenter.send(:any_project_enabled?) }

    context 'when namespace has any project with shared runners enabled' do
      let(:any_project_with_shared_runners_enabled?) { true }

      it { is_expected.to be true }
    end

    context 'when namespace has no projects with shared runners enabled' do
      let(:any_project_with_shared_runners_enabled?) { false }

      it { is_expected.to be false }
    end

    it 'does not trigger additional queries when called multiple times' do
      # memoizes the result
      presenter.any_project_enabled?

      # count
      actual = ActiveRecord::QueryRecorder.new do
        presenter.any_project_enabled?
      end

      expect(actual.count).to eq(0)
    end
  end

  describe '#display_minutes_available_data?' do
    subject { presenter.send(:display_minutes_available_data?) }

    context 'when the namespace is root and it has a project with shared runners enabled and quota is enabled' do
      let(:namespace_root?) { true }
      let(:any_project_with_shared_runners_enabled?) { true }
      let(:quota_enabled?) { true }

      it { is_expected.to be true }
    end

    context 'when the namespace is not root' do
      let(:namespace_root?) { false }

      it { is_expected.to be false }
    end

    context 'when no projects have instance runners enabled' do
      let(:any_project_with_shared_runners_enabled?) { false }

      it { is_expected.to be false }
    end

    context 'when the quota is disabled' do
      let(:quota_enabled?) { false }

      it { is_expected.to be false }
    end
  end

  describe '#display_shared_runners_data?' do
    subject { presenter.send(:display_shared_runners_data?) }

    context 'when the namespace is root and it has a project with shared runners enabled' do
      it { is_expected.to be_truthy }
    end

    context 'when the namespace is not root' do
      let(:namespace_root?) { false }

      it { is_expected.to be_falsey }
    end

    context 'when the namespaces has no project with shared runners enabled' do
      let(:any_project_with_shared_runners_enabled?) { false }

      it { is_expected.to be_falsey }
    end
  end
end
