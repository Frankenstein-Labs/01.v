# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConfirmService, feature_category: :vulnerability_management do
  include AccessMatchersGeneric

  before do
    stub_licensed_features(security_dashboard: true)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:comment) { "It's really there, I swear." }

  let(:project) { create(:project) } # cannot use let_it_be here: caching causes problems with permission-related tests
  let(:vulnerability) { create(:vulnerability, :with_findings, project: project) }
  let(:state_transition) { create(:vulnerability_state_transition, vulnerability: vulnerability) }
  let(:service) { described_class.new(user, vulnerability, comment) }
  let(:created_state_transition) { ::Vulnerabilities::StateTransition.last }

  subject(:confirm_vulnerability) { service.execute }

  context 'with an authorized user with proper permissions' do
    before do
      project.add_maintainer(user)
    end

    context 'when vulnerability state is different from the requested state' do
      it_behaves_like 'calls vulnerability statistics utility services in order'

      it_behaves_like 'removes dismissal feedback from associated findings'

      it_behaves_like 'triggering vulnerability webhook event'

      it_behaves_like 'creating state transition record', :confirmed

      it 'confirms a vulnerability' do
        freeze_time do
          confirm_vulnerability

          expect(vulnerability.reload).to(
            have_attributes(
              state: 'confirmed',
              confirmed_by: user,
              confirmed_at: be_like_time(Time.current)
            )
          )
        end
      end

      context 'when confirming a dismissed vulnerability' do
        let(:vulnerability) do
          create(:vulnerability, :dismissed, :with_findings, project: project,
            dismissed_by: create(:user), dismissed_at: 1.day.ago)
        end

        it 'resets dismissed_by and dismissed_at to nil' do
          freeze_time do
            confirm_vulnerability

            expect(vulnerability.reload).to have_attributes(
              dismissed_by: nil,
              dismissed_at: nil
            )
          end
        end
      end

      context 'when confirming a resolved vulnerability' do
        let(:vulnerability) do
          create(:vulnerability, :resolved, :with_findings, project: project,
            resolved_by: create(:user), resolved_at: 1.day.ago)
        end

        it 'resets resolved_by and resolved_at to nil' do
          freeze_time do
            confirm_vulnerability

            expect(vulnerability.reload).to have_attributes(
              resolved_by: nil,
              resolved_at: nil
            )
          end
        end
      end

      context 'when confirming an auto-resolved vulnerability' do
        let(:vulnerability) do
          create(:vulnerability, :with_findings, project: project, auto_resolved: true)
        end

        it 'sets auto_resolved to false' do
          confirm_vulnerability

          expect(vulnerability.reload.auto_resolved).to be false
        end
      end

      it 'creates note' do
        expect(SystemNoteService).to receive(:change_vulnerability_state).with(vulnerability, user)

        confirm_vulnerability
      end

      it_behaves_like 'calls Vulnerabilities::Findings::RiskScoreCalculationService'

      context 'when vulnerability is dismissed' do
        let(:vulnerability) { create(:vulnerability, :dismissed, :with_findings, project: project) }

        it_behaves_like 'nullifies dismissal fields from associated vulnerability read'
      end

      context 'when security dashboard feature is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it 'raises an "access denied" error' do
          expect { confirm_vulnerability }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end
  end

  context 'when vulnerability state is not different from the requested state' do
    let(:vulnerability) { create(:vulnerability, :confirmed, :with_findings, project: project) }
    let(:action) { confirm_vulnerability }

    before do
      project.add_maintainer(user)
    end

    it_behaves_like 'does not create state transition for same state'
    it_behaves_like 'not triggering vulnerability webhook event'
  end

  describe 'permissions' do
    context 'when admin mode is enabled', :enable_admin_mode do
      it { expect { confirm_vulnerability }.to be_allowed_for(:admin) }
    end

    context 'when admin mode is disabled' do
      it { expect { confirm_vulnerability }.to be_denied_for(:admin) }
    end

    it { expect { confirm_vulnerability }.to be_allowed_for(:owner).of(project) }
    it { expect { confirm_vulnerability }.to be_allowed_for(:maintainer).of(project) }
    it { expect { confirm_vulnerability }.to be_denied_for(:developer).of(project) }

    it { expect { confirm_vulnerability }.to be_denied_for(:auditor) }
    it { expect { confirm_vulnerability }.to be_denied_for(:reporter).of(project) }
    it { expect { confirm_vulnerability }.to be_denied_for(:guest).of(project) }
    it { expect { confirm_vulnerability }.to be_denied_for(:anonymous) }
  end
end
