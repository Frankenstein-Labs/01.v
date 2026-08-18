# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::Dast::Profiles::UpdateService, :dynamic_analysis,
  feature_category: :dynamic_application_security_testing do
  include LooseForeignKeysHelper
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:old_tags) { [create(:ci_tag, name: 'ruby'), create(:ci_tag, name: 'postgres')] }
  let_it_be_with_reload(:dast_profile) { create(:dast_profile, project: project, branch_name: 'orphaned-branch', tags: old_tags) }
  let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
  let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }
  let_it_be(:plan_limits) { create(:plan_limits, :default_plan) }
  let_it_be(:scheduler_owner) { create(:user, name: 'Scheduler Owner') }

  let_it_be(:new_tags) { [create(:ci_tag, name: 'rails'), create(:ci_tag, name: 'docker')] }
  let_it_be(:new_tag_list) { new_tags.map(&:name) }

  let(:default_params) do
    {
      name: SecureRandom.hex,
      description: SecureRandom.hex,
      branch_name: 'orphaned-branch',
      dast_profile: dast_profile,
      dast_site_profile_id: dast_site_profile.id,
      dast_scanner_profile_id: dast_scanner_profile.id
    }
  end

  let(:params) { default_params }

  subject do
    described_class.new(
      project: project,
      current_user: user,
      params: params
    ).execute
  end

  describe 'execute', :clean_gitlab_redis_shared_state do
    context 'when on demand scan licensed feature is not available' do
      it 'communicates failure' do
        stub_licensed_features(security_on_demand_scans: false)

        aggregate_failures do
          expect(subject.status).to eq(:error)
          expect(subject.message).to eq('You are not authorized to update this profile')
        end
      end
    end

    context 'when the feature is enabled' do
      before do
        stub_licensed_features(security_on_demand_scans: true)
      end

      context 'when the user cannot run a DAST scan' do
        it 'communicates failure' do
          aggregate_failures do
            expect(subject.status).to eq(:error)
            expect(subject.message).to eq('You are not authorized to update this profile')
          end
        end
      end

      context 'when the user cannot push to the branch associated with a DAST scan' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: 'master', authorize_user_to_push: nil, authorize_user_to_merge: nil) }
        let_it_be_with_reload(:dast_profile) { create(:dast_profile, project: project, branch_name: 'master', tags: old_tags) }

        let(:params) do
          {
            name: SecureRandom.hex,
            description: SecureRandom.hex,
            branch_name: 'master',
            dast_profile: dast_profile,
            dast_site_profile_id: dast_site_profile.id,
            dast_scanner_profile_id: dast_scanner_profile.id
          }
        end

        it 'communicates failure' do
          project.add_members([user, scheduler_owner], :developer)

          aggregate_failures do
            expect(subject.status).to eq(:error)
            expect(subject.message).to eq('You are not authorized to update this profile')
          end
        end

        context 'when user is a Security Manager' do
          let(:user) { create(:user) }

          before do
            project.add_security_manager(user)
          end

          it 'updates the dast_profile', :aggregate_failures do
            expect(subject.status).to eq(:success)

            updated_dast_profile = subject.payload[:dast_profile]
            expect(updated_dast_profile.description).to eq(params[:description])
          end
        end
      end

      context 'when the user can run a DAST scan' do
        before_all do
          project.add_members([user, scheduler_owner], :developer)
        end

        context 'without dast_profile_schedule param' do
          it 'communicates success' do
            expect(subject.status).to eq(:success)
          end

          it 'updates the dast_profile' do
            updated_dast_profile = subject.payload[:dast_profile].reload

            aggregate_failures do
              expect(updated_dast_profile.dast_site_profile.id).to eq(params[:dast_site_profile_id])
              expect(updated_dast_profile.dast_scanner_profile.id).to eq(params[:dast_scanner_profile_id])
              expect(updated_dast_profile.name).to eq(params[:name])
              expect(updated_dast_profile.description).to eq(params[:description])
            end
          end

          it 'does not try to create or update the dast_profile_schedule' do
            subject

            expect { subject }.not_to change { dast_profile.reload.dast_profile_schedule }.from(nil)
          end

          it 'ignores the dast_profile_schedule' do
            subject

            expect(params[:dast_profile]).not_to receive(:dast_profile_schedule)
          end
        end

        context 'with dast_profile_schedule param' do
          let_it_be(:time_zone) { Time.zone.tzinfo.name }

          let(:params) do
            default_params.merge(
              dast_profile_schedule: {
                active: false,
                starts_at: Time.zone.now + 10.days,
                timezone: time_zone,
                cadence: { unit: 'month', duration: 1 }
              }
            )
          end

          context 'when associated schedule is not present' do
            before do
              expect(dast_profile.dast_profile_schedule).to be_nil
            end

            it 'creates a new schedule' do
              aggregate_failures do
                expect { subject }.to change { Dast::ProfileSchedule.count }.by(1)
              end
            end

            it 'returns the success status' do
              expect(subject.status).to eq(:success)
            end

            it 'audits the creation' do
              expect { subject }.to change {
                AuditEventReader.where("details LIKE ?", "%dast_profile_schedule_create%").count
              }.by(1)
            end
          end

          context 'when associated schedule is present' do
            let_it_be_with_reload(:dast_profile_schedule) { create(:dast_profile_schedule, project: project, dast_profile: dast_profile, owner: scheduler_owner) }

            shared_examples 'audits the owner change' do
              it 'audits the owner change', :sidekiq_inline do
                subject

                messages = AuditEventReader.where(target_id: dast_profile.dast_profile_schedule.id).pluck(:details).pluck(:custom_message)
                old_owner = User.find_by(id: scheduler_owner.id)
                expect(messages).to include("Changed DAST profile schedule user_id from #{old_owner&.id || 'nil'} to #{user.id}")
              end
            end

            it 'updates the dast profile schedule' do
              subject

              aggregate_failures do
                expect(dast_profile_schedule.active).to eq(params[:dast_profile_schedule][:active])
                expect(dast_profile_schedule.starts_at.to_i).to eq(params[:dast_profile_schedule][:starts_at].to_i)
                expect(dast_profile_schedule.timezone).to eq(params[:dast_profile_schedule][:timezone])
                expect(dast_profile_schedule.cadence).to eq(params[:dast_profile_schedule][:cadence].stringify_keys)
              end
            end

            it 'creates the audit event' do
              expect { subject }.to change { AuditEventReader.where(target_id: dast_profile.dast_profile_schedule.id).count }
            end

            context 'when the owner is valid' do
              it 'does not updates the schedule owner' do
                subject

                expect(dast_profile_schedule.user_id).to eq(scheduler_owner.id)
              end
            end

            context 'when the owner was deleted' do
              before do
                dast_profile_schedule.owner.delete
                process_loose_foreign_key_deletions(record: user)
                dast_profile_schedule.reload
              end

              it 'updates the schedule owner' do
                subject

                expect(dast_profile_schedule.reload.user_id).to eq(user.id)
              end

              include_examples 'audits the owner change'
            end

            context 'when the owner permission was downgraded' do
              before do
                project.add_guest(scheduler_owner)
              end

              it 'updates the schedule owner' do
                subject

                expect(dast_profile_schedule.user_id).to eq(user.id)
              end

              include_examples 'audits the owner change'
            end

            context 'when the owner was removed from the project' do
              before do
                project.team.truncate
                project.add_developer(user)
              end

              it 'updates the schedule owner', :sidekiq_inline do
                subject

                expect(dast_profile_schedule.user_id).to eq(user.id)
              end

              include_examples 'audits the owner change'
            end
          end
        end

        it 'audits the update', :aggregate_failures do
          old_profile_attrs = {
            description: dast_profile.description,
            name: dast_profile.name,
            scanner_profile_name: dast_profile.dast_scanner_profile.name,
            site_profile_name: dast_profile.dast_site_profile.name
          }

          subject

          new_profile = dast_profile.reload
          audit_events = AuditEventReader.where(author_id: user.id)

          audit_events.each do |event|
            expect(event.author).to eq(user)
            expect(event.entity).to eq(project)
            expect(event.target_id).to eq(new_profile.id)
            expect(event.target_type).to eq('Dast::Profile')
            expect(event.target_details).to eq(new_profile.name)
          end

          messages = audit_events.map(&:details).pluck(:custom_message)
          expected_messages = [
            "Changed DAST profile dast_scanner_profile from #{old_profile_attrs[:scanner_profile_name]} to #{dast_scanner_profile.name}",
            "Changed DAST profile dast_site_profile from #{old_profile_attrs[:site_profile_name]} to #{dast_site_profile.name}",
            "Changed DAST profile name from #{old_profile_attrs[:name]} to #{new_profile.name}",
            "Changed DAST profile description from #{old_profile_attrs[:description]} to #{new_profile.description}"
          ]
          expect(messages).to match_array(expected_messages)
        end

        context 'when param run_after_update: true' do
          let(:params) { default_params.merge(run_after_update: true) }

          it_behaves_like 'it delegates scan creation to another service' do
            let(:delegated_params) { hash_including(dast_profile: dast_profile) }
          end

          it 'creates a ci_pipeline' do
            expect { subject }.to change { Ci::Pipeline.count }.by(1)
          end
        end

        context 'when dast_profile param is missing' do
          let(:params) { {} }

          it 'communicates failure' do
            aggregate_failures do
              expect(subject.status).to eq(:error)
              expect(subject.message).to eq('Profile parameter missing')
            end
          end
        end

        context 'with tag_list param' do
          let(:params) { default_params.merge(tag_list: new_tag_list) }

          it 'updates the tags' do
            subject

            expect(dast_profile.tags).to match_array(new_tags)
          end

          context 'when there is a invalid tag' do
            let(:new_tag_list) { %w[invalid_tag] }

            it 'returns an error status' do
              expect(subject.status).to eq(:error)
            end

            it 'populates message' do
              expect(subject.message).to eq('Invalid tags')
            end
          end
        end
      end
    end
  end
end
