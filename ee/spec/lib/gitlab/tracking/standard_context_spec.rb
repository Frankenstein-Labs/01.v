# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::StandardContext, feature_category: :service_ping do
  let(:snowplow_context) { subject.to_context }
  let_it_be(:organization) { create(:organization) }

  describe '#to_context' do
    let(:user) { build_stubbed(:user) }
    let(:namespace) { create(:namespace) }
    let(:instance_id) { SecureRandom.uuid }
    let(:json_data) { snowplow_context.to_json[:data] }

    before do
      allow(Gitlab::GlobalAnonymousId).to receive(:instance_id).and_return(instance_id)
      stub_current_organization(organization)
    end

    subject do
      described_class.new(user: user)
    end

    it 'includes the instance_id' do
      expect(json_data[:instance_id]).to eq(instance_id)
    end

    context 'on .com', :saas do
      it 'sets the realm to saas' do
        expect(json_data[:realm]).to eq('saas')
      end

      it 'sets the deployment_type to .com' do
        expect(json_data[:deployment_type]).to eq('.com')
      end

      context 'when user is nil' do
        let(:user) { nil }

        it 'sets is_gitlab_team_member to nil' do
          expect(json_data[:is_gitlab_team_member]).to be_nil
        end
      end

      context 'with GitLab team member' do
        before do
          allow(Gitlab::Com).to receive(:gitlab_com_group_member?).with(user.id).and_return(true)
        end

        it 'sets is_gitlab_team_member to true' do
          expect(json_data[:is_gitlab_team_member]).to be(true)
        end
      end

      context 'with non GitLab team member' do
        before do
          allow(Gitlab::Com).to receive(:gitlab_com_group_member?).with(user.id).and_return(false)
        end

        it 'sets is_gitlab_team_member to false' do
          expect(json_data[:is_gitlab_team_member]).to be(false)
        end
      end

      it 'hold the original user id value' do
        expect(json_data[:user_id]).to eq(user.id)
      end

      describe 'plan' do
        context 'when no namespace sent' do
          it 'returns license plan' do
            expect(json_data[:plan]).to be_nil
          end
        end

        context 'when namespace sent' do
          subject { described_class.new(user: user, namespace: namespace) }

          it 'returns namespace\'s plan' do
            expect(json_data[:plan]).to eq(namespace.actual_plan_name)
          end
        end
      end
    end

    context 'when on self-managed' do
      it 'sets the realm to self-managed' do
        expect(json_data[:realm]).to eq(::CloudConnector::GITLAB_REALM_SELF_MANAGED)
      end

      it 'sets the deployment_type to self-managed' do
        expect(json_data[:deployment_type]).to eq(::CloudConnector::GITLAB_REALM_SELF_MANAGED)
      end

      it 'hashes user_id' do
        expect(json_data[:user_id]).to eq(Gitlab::CryptoHelper.sha256(user.id))
      end

      describe 'plan' do
        context 'when instance has a license' do
          it 'returns license\'s plan' do
            create(:license, plan: ::License::PREMIUM_PLAN)

            expect(json_data[:plan]).to eq(::License::PREMIUM_PLAN)
          end
        end

        context 'when instance has default license' do
          it 'returns starter plan' do
            expect(json_data[:plan]).to eq(::License::STARTER_PLAN)
          end
        end

        context 'when instance has no license' do
          it 'returns free plan' do
            ::License.delete_all

            expect(json_data[:plan]).to eq('free')
          end
        end
      end
    end
  end
end
