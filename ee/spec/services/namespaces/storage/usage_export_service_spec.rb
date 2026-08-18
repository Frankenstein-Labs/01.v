# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::UsageExportService, :saas, feature_category: :consumables_cost_management do
  describe '.execute' do
    it 'creates an instance and calls execute' do
      user = build(:user)

      expect_next_instance_of(described_class, 'free', user) do |export_service|
        expect(export_service).to receive(:execute)
      end

      described_class.execute('free', user)
    end
  end

  describe '#execute' do
    let(:plan) { 'free' }

    subject(:result) { described_class.new(plan, user).execute }

    context 'when the user is allowed to export the data', :enable_admin_mode do
      let_it_be(:user) { create(:admin) }
      let_it_be(:premium_group) { create(:group_with_plan, :with_root_storage_statistics, plan: :premium_plan) }
      let_it_be_with_reload(:free_group) { create(:group, :with_root_storage_statistics) }
      let_it_be_with_reload(:root_statistics) { free_group.root_storage_statistics }
      let_it_be_with_reload(:limit) do
        create(
          :namespace_limit,
          namespace: free_group,
          additional_purchased_storage_size: 1024,
          pre_enforcement_notification_at: Date.today
        )
      end

      context 'when successful' do
        let(:csv) { CSV.parse(result.payload, headers: true) }
        let(:row) { csv.first }

        context 'with a free plan' do
          it 'returns the csv data' do
            expect(csv.headers).to contain_exactly(
              'Namespace ID',
              'Total Storage (B)',
              'Purchased Storage (B)',
              'Free Storage Consumed (B)',
              'First Notified'
            )

            expect(row[0]).to eq free_group.id.to_s
            expect(row[1]).to eq root_statistics.storage_size.to_s
            expect(row[2]).to eq 1024.megabytes.to_s
            expect(row[3]).to eq "0"
            expect(row[4]).to eq limit.pre_enforcement_notification_at.to_s
          end

          it 'only returns free plan namespace data' do
            expect(csv.size).to eq 1
            expect(csv.first['Namespace ID']).to eq free_group.id.to_s
          end

          context 'with free storage consumed' do
            using RSpec::Parameterized::TableSyntax

            where(:storage_size, :additional_purchased_storage_size, :free_storage_consumed) do
              2048 | 1024 | 1024
              1024 | 0    | 1024
              1024 | 1024 | 0
              1024 | 2048 | 0
              0    | 2048 | 0
            end

            with_them do
              before do
                root_statistics.update!(storage_size: storage_size.megabytes)
                limit.update!(additional_purchased_storage_size: additional_purchased_storage_size)
              end

              it 'returns the expected result' do
                expect(row[0]).to eq free_group.id.to_s
                expect(row[1]).to eq storage_size.megabytes.to_s
                expect(row[2]).to eq additional_purchased_storage_size.megabytes.to_s
                expect(row[3]).to eq free_storage_consumed.megabytes.to_s
                expect(row[4]).to eq limit.pre_enforcement_notification_at.to_s
              end
            end
          end
        end

        context 'with any other plan' do
          let(:plan) { 'premium' }

          it 'returns no namespace data' do
            expect(csv.size).to eq 0
          end
        end
      end

      context 'when unsuccessful' do
        it 'returns an error' do
          expect(CsvBuilder).to receive(:new).and_raise(PG::QueryCanceled)
          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

          expect(result).to be_error
          expect(result.message).to eq('Failed to generate storage export')
        end
      end
    end

    context 'when the user is not allowed to export the data' do
      let(:user) { create(:user) }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Insufficient permissions to generate storage export')
      end
    end
  end
end
