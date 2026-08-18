# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::NamespaceAddOnPurchasesFinder, feature_category: :plan_provisioning do
  describe '#execute' do
    let_it_be(:namespace) { create(:group) }

    subject(:execute) { described_class.new(namespace, add_on: :duo_pro).execute }

    context 'when add_on is not available' do
      it { is_expected.to be_empty }
    end

    context 'when add_on is available' do
      let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

      context 'with non trial add_on_purchase' do
        context 'with active add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: namespace)
          end

          context 'with duo_pro default values of non trial and active' do
            it { is_expected.to match_array([add_on_purchase]) }
          end

          context 'when a namespace_id is provided' do
            subject(:execute) { described_class.new(namespace.id, add_on: :duo_pro).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, trial: true).execute }

            it { is_expected.to be_empty }
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end

        context 'with expired add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :expired, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to be_empty }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, trial: true).execute }

            it { is_expected.to be_empty }
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end

        context 'with duo_core add_on' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active, :duo_core, namespace: namespace)
          end

          subject(:execute) { described_class.new(namespace, add_on: :duo_core).execute }

          it { is_expected.to match_array([add_on_purchase]) }
        end

        context 'with duo_enterprise add_on' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active, :duo_enterprise, namespace: namespace)
          end

          subject(:execute) { described_class.new(namespace, add_on: :duo_enterprise).execute }

          it { is_expected.to match_array([add_on_purchase]) }
        end

        context 'with Duo add-ons' do
          subject(:execute) { described_class.new(namespace, add_on: :duo).execute }

          it 'returns available Duo Pro add-on purchase' do
            add_on_purchase = create(:gitlab_subscription_add_on_purchase, add_on: add_on, namespace: namespace)

            expect(execute).to match_array([add_on_purchase])
          end

          it 'returns available Duo Enterprise add-on purchase' do
            add_on_purchase = create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)

            expect(execute).to match_array([add_on_purchase])
          end
        end
      end

      context 'with trial add_on_purchase' do
        context 'with active add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active_trial, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to match_array([add_on_purchase]) }
          end

          context 'when a namespace_id is provided' do
            subject(:execute) { described_class.new(namespace.id, add_on: :duo_pro).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, trial: true).execute }

            it { is_expected.to match_array([add_on_purchase]) }

            context 'when filtering by any active state' do
              subject(:execute) { described_class.new(namespace, add_on: :duo_pro, only_active: false).execute }

              it { is_expected.to match_array([add_on_purchase]) }
            end
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end

        context 'with expired add_on purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :expired_trial, add_on: add_on, namespace: namespace)
          end

          context 'with default values of non trial and active' do
            it { is_expected.to be_empty }
          end

          context 'when filtering by trial' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, trial: true).execute }

            it { is_expected.to be_empty }

            context 'when filtering by any active state' do
              subject(:execute) do
                described_class.new(namespace, add_on: :duo_pro, trial: true, only_active: false).execute
              end

              it { is_expected.to match_array([add_on_purchase]) }
            end
          end

          context 'when filtering by any active state' do
            subject(:execute) { described_class.new(namespace, add_on: :duo_pro, only_active: false).execute }

            it { is_expected.to match_array([add_on_purchase]) }
          end
        end
      end
    end

    context 'with invalid add_on' do
      subject(:execute) { described_class.new(namespace, add_on: :invalid_add_on).execute }

      it 'raises an error' do
        expect { execute }.to raise_error(ArgumentError)
      end
    end
  end
end
