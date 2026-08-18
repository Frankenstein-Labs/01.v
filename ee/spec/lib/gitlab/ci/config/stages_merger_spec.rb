# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::StagesMerger, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  subject(:injected_stages) { described_class.inject(wrap_stages(project_stages), injected_policy_stages) }

  let(:project_stages) { %w[build test deploy] }

  context 'with valid stages' do
    where(:project_stages, :policy_stages, :result) do
      %w[build test deploy] | %w[policy-test] | %w[build test deploy policy-test]
      %w[build test deploy] | %w[policy-test test] | %w[build policy-test test deploy]
      %w[build test deploy] | %w[build policy-test test] | %w[build policy-test test deploy]
      %w[build test deploy] | %w[build policy-test] | %w[build test deploy policy-test]
      %w[build test deploy] | %w[policy-test build test] | %w[policy-test build test deploy]
      %w[test post-test deploy] | %w[test policy-test deploy] | %w[test post-test policy-test deploy]
      %w[compile check
        publish] | %w[build test policy-test deploy] | %w[compile check publish build test policy-test deploy]
      %w[compile check
        publish] | %w[compile build check test policy-test deploy
          publish] | %w[compile build check test policy-test deploy publish]
      %w[build test
        deploy] | %w[policy-build policy-test
          policy-deploy] | %w[build test deploy policy-build policy-test policy-deploy]
    end

    with_them do
      let(:injected_policy_stages) { [wrap_stages(policy_stages)] }

      it 'inserts custom stages based on their dependencies' do
        expect(injected_stages).to eq(wrap_stages(result))
      end
    end

    context 'with multiple policies' do
      where(:policy1, :policy2, :result) do
        %w[build policy-build test] | %w[build test policy-test deploy] | %w[build policy-build test policy-test deploy]
        %w[build policy-build test] | %w[test deploy policy-deploy] | %w[build policy-build test deploy policy-deploy]
        %w[build policy-test test] | %w[build policy-compile test] | %w[build policy-test policy-compile test deploy]
        %w[policy1-test] | %w[policy2-test] | %w[build test deploy policy1-test policy2-test]
        %w[security-scan] | %w[compliance-check] | %w[build test deploy security-scan compliance-check]
      end

      with_them do
        let(:injected_policy_stages) { [wrap_stages(policy1), wrap_stages(policy2)] }

        it 'inserts custom stages in order from all policies based on their dependencies' do
          expect(injected_stages).to eq(wrap_stages(result))
        end
      end
    end
  end

  context 'when there are cyclic dependencies within injected stages' do
    let(:injected_policy_stages) do
      [
        wrap_stages(%w[test deploy]),
        wrap_stages(%w[deploy test])
      ]
    end

    it 'raises an error' do
      expect { injected_stages }
        .to raise_error(described_class::InvalidStageConditionError, /Cyclic dependencies/)
    end
  end

  context 'when there are cyclic dependencies with project config' do
    let(:project_stages) { %w[deploy build test] }
    let(:injected_policy_stages) { [wrap_stages(%w[build test policy-test deploy])] }

    it 'raises an error' do
      expect { injected_stages }
        .to raise_error(described_class::InvalidStageConditionError, /Cyclic dependencies/)
    end
  end

  context 'with original_stages_last strategy' do
    subject(:injected_stages) do
      described_class.inject(wrap_stages(project_stages), injected_policy_stages, strategy: :original_stages_last)
    end

    context 'with valid stages' do
      where(:project_stages, :policy_stages, :result) do
        # When policy has no common stages with project stages, new stages come after .pre (first common)
        %w[build test deploy] | %w[policy-test] | %w[policy-test build test deploy]
        # When policy has common stages, new stages come after first common stage (.pre)
        %w[build test deploy] | %w[policy-test test] | %w[policy-test build test deploy]
        %w[build test deploy] | %w[build policy-test test] | %w[build policy-test test deploy]
        %w[build test deploy] | %w[build policy-test] | %w[build policy-test test deploy]
        # When policy starts with new stage, it comes after .pre
        %w[build test deploy] | %w[policy-test build test] | %w[policy-test build test deploy]
        # New stages after first common come before remaining original stages
        %w[test post-test deploy] | %w[test policy-test deploy] | %w[test policy-test post-test deploy]
        # When no common stages with project, all new stages come after .pre
        %w[compile check
          publish] | %w[build test policy-test deploy] | %w[build test policy-test deploy compile check publish]
        # Mixed common and new stages - new stages positioned after first common (.pre)
        %w[compile check
          publish] | %w[compile build check test policy-test deploy
            publish] | %w[compile build check test policy-test deploy publish]
        # Use case: policy stages come before project stages (security/compliance first)
        %w[build test
          deploy] | %w[policy-build policy-test
            policy-deploy] | %w[policy-build policy-test policy-deploy build test deploy]
        %w[compile verify
          publish] | %w[first-stage build] | %w[first-stage build compile verify publish]
        # Use case: security and compliance checks before project stages
        %w[build test
          deploy] | %w[security-scan compliance-check build test
            deploy] | %w[security-scan compliance-check build test deploy]
      end

      with_them do
        let(:injected_policy_stages) { [wrap_stages(policy_stages)] }

        it 'inserts custom stages after first common stage based on their dependencies' do
          expect(injected_stages).to eq(wrap_stages(result))
        end
      end

      context 'with multiple policies' do
        where(:policy1, :policy2, :result) do
          # Multiple policies with new stages after first common
          %w[build policy-build
            test] | %w[build test policy-test deploy] | %w[build policy-build test policy-test deploy]
          # This case creates cycles, so let's use a simpler case
          %w[build policy-build test] | %w[policy-deploy] | %w[build policy-build test policy-deploy deploy]
          %w[build policy-test test] | %w[build policy-compile test] | %w[build policy-test policy-compile test deploy]
          # Policies with no common stages come after .pre
          %w[policy1-test] | %w[policy2-test] | %w[policy1-test policy2-test build test deploy]
          # Use case: multiple security policies with different stages
          %w[security-scan] | %w[compliance-check] | %w[security-scan compliance-check build test deploy]
          %w[policy-build policy-test
            policy-deploy] | %w[policy-test] | %w[policy-build policy-test policy-deploy build test deploy]
        end

        with_them do
          let(:injected_policy_stages) { [wrap_stages(policy1), wrap_stages(policy2)] }

          it 'inserts custom stages from all policies after first common stage' do
            expect(injected_stages).to eq(wrap_stages(result))
          end
        end
      end
    end

    context 'when there are cyclic dependencies within injected stages' do
      let(:injected_policy_stages) do
        [
          wrap_stages(%w[test deploy]),
          wrap_stages(%w[deploy test])
        ]
      end

      it 'raises an error' do
        expect { injected_stages }
          .to raise_error(described_class::InvalidStageConditionError, /Cyclic dependencies/)
      end
    end

    context 'when there are cyclic dependencies with project config' do
      let(:project_stages) { %w[deploy build test] }
      let(:injected_policy_stages) { [wrap_stages(%w[build test policy-test deploy])] }

      it 'raises an error' do
        expect { injected_stages }
          .to raise_error(described_class::InvalidStageConditionError, /Cyclic dependencies/)
      end
    end
  end

  private

  def wrap_stages(stages)
    ['.pipeline-policy-pre', '.pre', *stages, '.post', '.pipeline-policy-post']
  end
end
