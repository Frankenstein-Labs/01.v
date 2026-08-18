# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Quota, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project) }
  let_it_be_with_refind(:security_statistics) { create(:project_security_statistics, project: project) }

  let(:quota) { described_class.new(project) }

  describe '#validate!' do
    let(:max_number_of_vulnerabilities) { 2 }
    let(:mock_redis) { instance_double(Redis, set: true, del: true) }

    subject(:validate!) { quota.validate! }

    before do
      security_statistics.update!(vulnerability_count: vulnerability_count)

      stub_application_setting(max_number_of_vulnerabilities_per_project: max_number_of_vulnerabilities)

      allow(Gitlab::Redis::SharedState).to receive(:with).and_yield(mock_redis)
    end

    context 'when the project does not have more vulnerabilities than the limit' do
      let(:vulnerability_count) { max_number_of_vulnerabilities - 1 }

      it { is_expected.to be_truthy }

      it 'does not set the status on redis' do
        validate!

        expect(mock_redis).not_to have_received(:set)
      end
    end

    context 'when the project has more vulnerabilities than the limit' do
      let(:vulnerability_count) { max_number_of_vulnerabilities }

      it { is_expected.to be_falsey }

      it 'sets the status on redis' do
        validate!

        expect(mock_redis).to have_received(:set).with("projects:#{project.id}:vulnerability_quota:over_usage", true)
      end

      context 'when the FF is disabled' do
        before do
          stub_feature_flags(limit_number_of_vulnerabilities_per_project: false)
        end

        it { is_expected.to be_truthy }

        it 'does not set the status on redis' do
          validate!

          expect(mock_redis).not_to have_received(:set)
        end
      end
    end
  end

  describe '#allowance' do
    subject { quota.allowance }

    where(:project_setting, :ancestor_setting, :application_setting, :expected_value) do
      3   | 2   | 1   | 3
      nil | 2   | 1   | 2
      nil | nil | 1   | 1
      nil | nil | nil | Float::INFINITY
    end

    with_them do
      before do
        project.project_setting.update!(max_number_of_vulnerabilities: project_setting)
        project.root_ancestor.namespace_limit.update!(max_number_of_vulnerabilities_per_project: ancestor_setting)
        stub_application_setting(max_number_of_vulnerabilities_per_project: application_setting)
      end

      it { is_expected.to eq(expected_value) }
    end
  end

  describe '#critical?' do
    subject { quota.critical? }

    where(:vulnerability_count, :critical?) do
      0  | false
      95 | false
      96 | true
    end

    with_them do
      before do
        stub_application_setting(max_number_of_vulnerabilities_per_project: 100)

        security_statistics.update!(vulnerability_count: vulnerability_count)
      end

      it { is_expected.to eq(critical?) }
    end

    context 'when the FF is disabled' do
      where(:vulnerability_count, :critical?) do
        0  | false
        95 | false
        96 | false
      end

      with_them do
        before do
          stub_feature_flags(limit_number_of_vulnerabilities_per_project: false)

          stub_application_setting(max_number_of_vulnerabilities_per_project: 100)

          security_statistics.update!(vulnerability_count: vulnerability_count)
        end

        it { is_expected.to eq(critical?) }
      end
    end
  end

  describe '#full?' do
    subject { quota.full? }

    where(:vulnerability_count, :full?) do
      96  | false
      100 | true
      101 | true
    end

    with_them do
      before do
        stub_application_setting(max_number_of_vulnerabilities_per_project: 100)

        security_statistics.update!(vulnerability_count: vulnerability_count)
      end

      it { is_expected.to eq(full?) }
    end

    context 'when the FF is disabled' do
      where(:vulnerability_count, :full?) do
        96  | false
        100 | false
        101 | false
      end

      with_them do
        before do
          stub_feature_flags(limit_number_of_vulnerabilities_per_project: false)

          stub_application_setting(max_number_of_vulnerabilities_per_project: 100)

          security_statistics.update!(vulnerability_count: vulnerability_count)
        end

        it { is_expected.to eq(full?) }
      end
    end
  end

  describe '#exceeded?' do
    let(:mock_redis) { instance_double(Redis) }

    subject { quota.exceeded? }

    before do
      redis_key = "projects:#{project.id}:vulnerability_quota:over_usage"

      allow(mock_redis).to receive(:exists?).with(redis_key).and_return(data_exists_on_redis?)
      allow(Gitlab::Redis::SharedState).to receive(:with).and_yield(mock_redis)
    end

    context 'when there is no data on redis' do
      let(:data_exists_on_redis?) { false }

      it { is_expected.to be_falsey }
    end

    context 'when there is data on redis' do
      let(:data_exists_on_redis?) { true }

      it { is_expected.to be_truthy }

      context 'when the FF is disabled' do
        before do
          stub_feature_flags(limit_number_of_vulnerabilities_per_project: false)
        end

        it { is_expected.to be_falsey }
      end
    end
  end
end
