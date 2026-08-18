# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ResolveService, feature_category: :vulnerability_management do
  include AccessMatchersGeneric

  before do
    stub_licensed_features(security_dashboard: true)
  end

  let_it_be(:user) { create(:user) }
  let(:comment) { "resolve vulnerability comment" }

  let(:project) { create(:project) } # cannot use let_it_be here: caching causes problems with permission-related tests
  let(:vulnerability) { create(:vulnerability, project: project) }
  let(:state_transition) { create(:vulnerability_state_transition, vulnerability: vulnerability) }
  let(:last_state_transition) { vulnerability.state_transitions.last }
  let(:auto_resolved) { false }
  let(:service) { described_class.new(user, vulnerability, comment, auto_resolved: auto_resolved) }

  subject(:resolve_vulnerability) { service.execute }

  describe 'pre-existing state policy re-evaluation' do
    before do
      project.add_maintainer(user)
    end

    it_behaves_like 'syncs pre-existing state approval policy rules on triage' do
      let(:triaged_project) { project }
      let(:perform_triage) { resolve_vulnerability }
    end
  end

  context 'when vulnerability state is different from the requested state' do
    context 'with an authorized user with proper permissions' do
      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'calls vulnerability statistics utility services in order'

      it_behaves_like 'removes dismissal feedback from associated findings'

      it_behaves_like 'triggering vulnerability webhook event'

      it_behaves_like 'creating state transition record', :resolved

      it 'resolves a vulnerability' do
        freeze_time do
          resolve_vulnerability

          expect(vulnerability.reload).to(
            have_attributes(state: 'resolved', resolved_by: user, resolved_at: be_like_time(Time.current)))
        end
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'resolve_vulnerability' }
        let(:category) { described_class.name }
        subject(:service_action) { resolve_vulnerability }
      end

      context 'when marking a Vulnerability as auto-resolved' do
        let(:auto_resolved) { true }

        it 'sets the auto_resolved mark' do
          resolve_vulnerability

          expect(vulnerability.reload).to(have_attributes(state: 'resolved', auto_resolved: true))
        end
      end

      context 'when resolving a dismissed vulnerability' do
        let(:vulnerability) do
          create(:vulnerability, :dismissed, :with_findings, project: project,
            dismissed_by: create(:user), dismissed_at: 1.day.ago)
        end

        it 'resets dismissed_by and dismissed_at to nil' do
          resolve_vulnerability

          expect(vulnerability.reload).to have_attributes(
            dismissed_by: nil,
            dismissed_at: nil
          )
        end
      end

      context 'when resolving a confirmed vulnerability' do
        let(:vulnerability) do
          create(:vulnerability, :confirmed, :with_findings, project: project,
            confirmed_by: create(:user), confirmed_at: 1.day.ago)
        end

        it 'resets confirmed_by and confirmed_at to nil' do
          resolve_vulnerability

          expect(vulnerability.reload).to have_attributes(
            confirmed_by: nil,
            confirmed_at: nil
          )
        end
      end

      it 'creates note' do
        expect(SystemNoteService).to receive(:change_vulnerability_state).with(vulnerability, user)

        resolve_vulnerability
      end

      it 'updates vulnerability read record with resolved state and auto_resolved flag' do
        vulnerability_read = Vulnerabilities::Read.find_by(vulnerability_id: vulnerability.id) ||
          create(:vulnerability_read, vulnerability: vulnerability, state: 'detected', auto_resolved: false)

        resolve_vulnerability

        vulnerability_read.reload
        expect(vulnerability_read.state).to eq('resolved')
        expect(vulnerability_read.auto_resolved).to eq(auto_resolved)
      end

      context 'when vulnerability is dismissed' do
        let(:vulnerability) { create(:vulnerability, :dismissed, :with_findings, project: project) }

        it_behaves_like 'nullifies dismissal fields from associated vulnerability read'
      end

      context 'when security dashboard feature is disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it 'raises an "access denied" error' do
          expect { resolve_vulnerability }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end
    end
  end

  context 'when vulnerability state is not different from the requested state' do
    let(:vulnerability) { create(:vulnerability, :resolved, :with_findings, project: project) }
    let(:action) { resolve_vulnerability }

    before do
      project.add_maintainer(user)
    end

    it_behaves_like 'does not create state transition for same state'
    it_behaves_like 'not triggering vulnerability webhook event'
  end

  describe 'permissions' do
    context 'when admin mode is enabled', :enable_admin_mode do
      it { expect { resolve_vulnerability }.to be_allowed_for(:admin) }
    end

    context 'when admin mode is disabled' do
      it { expect { resolve_vulnerability }.to be_denied_for(:admin) }
    end

    it { expect { resolve_vulnerability }.to be_allowed_for(:owner).of(project) }
    it { expect { resolve_vulnerability }.to be_allowed_for(:maintainer).of(project) }
    it { expect { resolve_vulnerability }.to be_denied_for(:developer).of(project) }

    it { expect { resolve_vulnerability }.to be_denied_for(:auditor) }
    it { expect { resolve_vulnerability }.to be_denied_for(:reporter).of(project) }
    it { expect { resolve_vulnerability }.to be_denied_for(:guest).of(project) }
    it { expect { resolve_vulnerability }.to be_denied_for(:anonymous) }
  end
end
