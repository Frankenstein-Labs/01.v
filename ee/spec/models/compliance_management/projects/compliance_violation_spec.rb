# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Projects::ComplianceViolation,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:namespace) }

    it 'belongs to compliance_control' do
      is_expected.to belong_to(:compliance_control)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl')
        .with_foreign_key('compliance_requirements_control_id')
    end

    it 'has many compliance_violation_issues' do
      is_expected.to have_many(:compliance_violation_issues)
        .class_name('ComplianceManagement::Projects::ComplianceViolationIssue')
        .with_foreign_key('project_compliance_violation_id')
    end

    it { is_expected.to have_many(:issues).through(:compliance_violation_issues) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_control) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:audit_event_table_name) }

    describe 'uniqueness validations' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:other_audit_event) { create(:audit_event, :project_event, target_project: project) }
      let_it_be(:other_compliance_control) { create(:compliance_requirements_control, namespace: namespace) }

      context 'when creating a duplicate violation' do
        before do
          create(:project_compliance_violation,
            project: project,
            namespace: namespace,
            compliance_control: compliance_control,
            audit_event_id: audit_event.id,
            audit_event_table_name: :project_audit_events
          )
        end

        subject(:duplicate_violation) do
          build(:project_compliance_violation,
            project: project,
            namespace: namespace,
            compliance_control: compliance_control,
            audit_event_id: audit_event.id,
            audit_event_table_name: :project_audit_events
          )
        end

        it 'is invalid' do
          expect(duplicate_violation).not_to be_valid
          expect(duplicate_violation.errors[:audit_event_id])
            .to include('has already been recorded as a violation for this compliance control')
        end
      end
    end

    describe 'custom validations' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:other_project) { create(:project, namespace: other_namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:other_compliance_control) { create(:compliance_requirements_control, namespace: other_namespace) }
      let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }

      describe '#project_belongs_to_namespace' do
        context 'when project belongs to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: compliance_control,
              audit_event_id: audit_event.id,
              audit_event_table_name: :project_audit_events
            )
          end

          it 'is valid' do
            expect(violation).to be_valid
          end
        end

        context 'when project does not belong to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: other_namespace,
              compliance_control: compliance_control,
              audit_event_id: audit_event.id,
              audit_event_table_name: :project_audit_events
            )
          end

          it 'is invalid' do
            expect(violation).not_to be_valid
            expect(violation.errors[:project]).to include('must belong to the specified namespace')
          end
        end
      end

      describe '#compliance_control_belongs_to_namespace' do
        context 'when compliance control belongs to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: compliance_control,
              audit_event_id: audit_event.id,
              audit_event_table_name: :project_audit_events
            )
          end

          it 'is valid' do
            expect(violation).to be_valid
          end
        end

        context 'when compliance control does not belong to namespace' do
          subject(:violation) do
            build(:project_compliance_violation,
              project: project,
              namespace: namespace,
              compliance_control: other_compliance_control,
              audit_event_id: audit_event.id,
              audit_event_table_name: :project_audit_events
            )
          end

          it 'is invalid' do
            expect(violation).not_to be_valid
            expect(violation.errors[:compliance_control]).to include('must belong to the specified namespace')
          end
        end
      end

      describe '#audit_event_has_valid_entity_association' do
        context 'with Project entity type' do
          context 'when audit event references the project' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event_id: audit_event.id,
                audit_event_table_name: :project_audit_events
              )
            end

            it 'is valid' do
              expect(violation).to be_valid
            end
          end

          context 'when audit event references a different project' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event_id: create(:audit_events_project_audit_event, project_id: other_project.id).id,
                audit_event_table_name: :project_audit_events
              )
            end

            it 'is invalid' do
              expect(violation).not_to be_valid
              expect(violation.errors[:audit_event_id]).to include('must reference the specified project as its entity')
            end
          end
        end

        context 'with Group entity type' do
          context 'when audit event references the namespace' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event_id: create(:audit_events_group_audit_event, group_id: namespace.id).id,
                audit_event_table_name: :group_audit_events
              )
            end

            it 'is valid' do
              expect(violation).to be_valid
            end
          end

          context 'when audit event references a namespace in the hierarchy' do
            let_it_be(:sub_group) { create(:group, parent: namespace) }
            let_it_be(:sub_group_project) { create(:project, namespace: sub_group) }

            subject(:violation) do
              build(:project_compliance_violation,
                project: sub_group_project,
                namespace: sub_group,
                compliance_control: compliance_control,
                audit_event_id: create(:audit_events_group_audit_event, group_id: namespace.id).id,
                audit_event_table_name: :group_audit_events
              )
            end

            it 'is valid' do
              expect(violation).to be_valid
            end
          end

          context 'when audit event references a namespace not in the hierarchy' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event_id: create(:audit_events_group_audit_event, group_id: other_namespace.id).id,
                audit_event_table_name: :group_audit_events
              )
            end

            it 'is invalid' do
              expect(violation).not_to be_valid
              expect(violation.errors[:audit_event_id])
                .to include('must reference the specified namespace as its entity')
            end
          end
        end

        context 'when entity type is not Project or Group' do
          context 'for user audit events' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event_id: create(:audit_events_user_audit_event).id,
                audit_event_table_name: :user_audit_events
              )
            end

            it 'is invalid' do
              expect(violation).not_to be_valid
              expect(violation.errors[:audit_event_id])
                .to include('must be associated with either a Project or Group entity type')
            end
          end

          context 'for instance audit events' do
            subject(:violation) do
              build(:project_compliance_violation,
                project: project,
                namespace: namespace,
                compliance_control: compliance_control,
                audit_event_id: create(:audit_events_instance_audit_event).id,
                audit_event_table_name: :instance_audit_events
              )
            end

            it 'is invalid' do
              expect(violation).not_to be_valid
              expect(violation.errors[:audit_event_id])
                .to include('must be associated with either a Project or Group entity type')
            end
          end
        end
      end

      describe '#validate_audit_event_presence' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:project) { create(:project, namespace: namespace) }
        let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
        let_it_be(:project_audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }

        let(:base_attributes) do
          {
            project: project,
            namespace: namespace,
            compliance_control: compliance_control
          }
        end

        context 'when audit_event_id or audit_event_table_name is blank' do
          it 'skips validation for blank audit_event_id' do
            violation = build(:project_compliance_violation, base_attributes.merge(
              audit_event_id: nil, audit_event_table_name: :project_audit_events
            ))

            violation.valid?
            expect(violation.errors[:audit_event_id]).not_to include(match(/does not exist/))
          end

          it 'skips validation for blank audit_event_table_name' do
            violation = build(:project_compliance_violation, base_attributes.merge(
              audit_event_id: 123, audit_event_table_name: nil
            ))

            violation.valid?
            expect(violation.errors[:audit_event_id]).not_to include(match(/does not exist/))
          end
        end

        context 'when audit event exists' do
          it 'is valid with existing project audit event' do
            violation = build(:project_compliance_violation, base_attributes.merge(
              audit_event_id: project_audit_event.id, audit_event_table_name: :project_audit_events
            ))

            expect(violation).to be_valid
          end
        end

        context 'when audit event does not exist' do
          it 'is invalid with non-existent project audit event' do
            violation = build(:project_compliance_violation, base_attributes.merge(
              audit_event_id: non_existing_record_id, audit_event_table_name: :project_audit_events
            ))

            expect(violation).not_to be_valid
            expect(violation.errors[:audit_event_id])
              .to include('does not exist in project audit events')
          end

          it 'is invalid with wrong scope' do
            violation = build(:project_compliance_violation, base_attributes.merge(
              audit_event_id: project_audit_event.id, audit_event_table_name: :group_audit_events
            ))

            expect(violation).not_to be_valid
            expect(violation.errors[:audit_event_id])
              .to include('does not exist in group audit events')
          end
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(detected: 0, in_review: 1, resolved: 2, dismissed: 3) }

    it 'defines enum' do
      is_expected.to define_enum_for(:audit_event_table_name).with_values(
        project_audit_events: 0,
        group_audit_events: 1,
        user_audit_events: 2,
        instance_audit_events: 3)
    end
  end

  describe '.order_by_created_at_and_id' do
    let_it_be(:violation1) { create(:project_compliance_violation, created_at: 1.day.ago) }
    let_it_be(:violation2) { create(:project_compliance_violation, created_at: 2.days.ago) }
    let_it_be(:violation3) { create(:project_compliance_violation) }

    it 'returns an ActiveRecord::Relation' do
      expect(described_class.order_by_created_at_and_id).to be_a(ActiveRecord::Relation)
    end

    context 'when direction is not provided' do
      it 'sorts by updated_at in ascending order by default' do
        expect(described_class.order_by_created_at_and_id).to eq(
          [
            violation2,
            violation1,
            violation3
          ]
        )
      end
    end

    context 'when direction is desc' do
      it 'sorts in descending order' do
        expect(described_class.order_by_created_at_and_id(:desc)).to eq(
          [
            violation3,
            violation1,
            violation2
          ]
        )
      end
    end

    context 'when direction is invalid' do
      it 'raises error' do
        expect do
          described_class.order_by_created_at_and_id(:invalid)
        end.to raise_error(ArgumentError, /Direction "invalid" is invalid/)
      end
    end
  end

  describe '.including_controls' do
    it 'preloads associations to avoid N+1 queries' do
      create_list(:project_compliance_violation, 3)

      expect do
        described_class.including_controls.each do |v|
          v.compliance_control.compliance_requirement.framework
        end
      end.to make_queries_matching(/SELECT/, 4)
    end
  end

  describe 'scopes' do
    describe '.for_projects' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project1) { create(:project, namespace: namespace) }
      let_it_be(:project2) { create(:project, namespace: namespace) }
      let_it_be(:project3) { create(:project, namespace: namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: project1.id) }
      let_it_be(:audit_event2) { create(:audit_events_project_audit_event, project_id: project2.id) }
      let_it_be(:audit_event3) { create(:audit_events_project_audit_event, project_id: project3.id) }

      let_it_be(:violation1) do
        create(:project_compliance_violation,
          project: project1,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event1.id,
          audit_event_table_name: :project_audit_events
        )
      end

      let_it_be(:violation2) do
        create(:project_compliance_violation,
          project: project2,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event2.id,
          audit_event_table_name: :project_audit_events
        )
      end

      let_it_be(:violation3) do
        create(:project_compliance_violation,
          project: project3,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event3.id,
          audit_event_table_name: :project_audit_events
        )
      end

      it 'returns violations for a single project' do
        expect(described_class.for_projects(project1.id)).to match_array([violation1])
      end

      it 'returns violations for multiple projects' do
        expect(described_class.for_projects([project1.id, project2.id])).to match_array([violation1, violation2])
      end

      it 'returns empty when no matching projects' do
        expect(described_class.for_projects(non_existing_record_id)).to be_empty
      end
    end

    describe '.for_controls' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:control1) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:control2) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:control3) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event2) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event3) { create(:audit_events_project_audit_event, project_id: project.id) }

      let_it_be(:violation1) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: control1,
          audit_event_id: audit_event1.id,
          audit_event_table_name: :project_audit_events
        )
      end

      let_it_be(:violation2) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: control2,
          audit_event_id: audit_event2.id,
          audit_event_table_name: :project_audit_events
        )
      end

      let_it_be(:violation3) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: control3,
          audit_event_id: audit_event3.id,
          audit_event_table_name: :project_audit_events
        )
      end

      it 'returns violations for a single control' do
        expect(described_class.for_controls(control1.id)).to match_array([violation1])
      end

      it 'returns violations for multiple controls' do
        expect(described_class.for_controls([control1.id, control2.id])).to match_array([violation1, violation2])
      end

      it 'returns empty when no matching controls' do
        expect(described_class.for_controls(non_existing_record_id)).to be_empty
      end
    end

    describe '.for_status' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: project.id) }

      let_it_be(:detected_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event1.id,
          audit_event_table_name: :project_audit_events,
          status: :detected
        )
      end

      it 'returns violations with detected status' do
        expect(described_class.for_status(:detected)).to match_array([detected_violation])
      end

      it 'returns violations using integer status value' do
        expect(described_class.for_status(0)).to match_array([detected_violation])
      end
    end

    describe '.created_on_or_before' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event2) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event3) { create(:audit_events_project_audit_event, project_id: project.id) }

      let_it_be(:old_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event1.id,
          audit_event_table_name: :project_audit_events,
          created_at: 5.days.ago
        )
      end

      let_it_be(:mid_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event2.id,
          audit_event_table_name: :project_audit_events,
          created_at: 3.days.ago
        )
      end

      let_it_be(:recent_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event3.id,
          audit_event_table_name: :project_audit_events,
          created_at: 1.day.ago
        )
      end

      it 'returns violations created before the specified date' do
        expect(described_class.created_on_or_before(2.days.ago)).to match_array([old_violation, mid_violation])
      end

      it 'includes violations created on the same day' do
        expect(described_class.created_on_or_before(3.days.ago.to_date)).to include(mid_violation)
      end

      it 'returns empty when no violations created before the date' do
        expect(described_class.created_on_or_before(10.days.ago)).to be_empty
      end
    end

    describe '.created_on_or_after' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
      let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event2) { create(:audit_events_project_audit_event, project_id: project.id) }
      let_it_be(:audit_event3) { create(:audit_events_project_audit_event, project_id: project.id) }

      let_it_be(:old_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event1.id,
          audit_event_table_name: :project_audit_events,
          created_at: 5.days.ago
        )
      end

      let_it_be(:mid_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event2.id,
          audit_event_table_name: :project_audit_events,
          created_at: 3.days.ago
        )
      end

      let_it_be(:recent_violation) do
        create(:project_compliance_violation,
          project: project,
          namespace: namespace,
          compliance_control: compliance_control,
          audit_event_id: audit_event3.id,
          audit_event_table_name: :project_audit_events,
          created_at: 1.day.ago
        )
      end

      it 'returns violations created after the specified date' do
        expect(described_class.created_on_or_after(4.days.ago)).to match_array([mid_violation, recent_violation])
      end

      it 'includes violations created on the same day' do
        expect(described_class.created_on_or_after(3.days.ago.to_date)).to include(mid_violation)
      end

      it 'returns empty when no violations created after the date' do
        expect(described_class.created_on_or_after(Time.current)).to be_empty
      end
    end
  end

  describe '#readable_by?' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
    let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }
    let_it_be(:owner) { create(:user) }
    let_it_be(:regular_user) { create(:user) }

    subject(:violation) do
      create(:project_compliance_violation,
        project: project,
        namespace: namespace,
        compliance_control: compliance_control,
        audit_event_id: audit_event.id,
        audit_event_table_name: :project_audit_events
      )
    end

    before do
      stub_licensed_features(group_level_compliance_violations_report: true,
        project_level_compliance_violations_report: true)
    end

    context 'when user has permission to read compliance violations report' do
      before_all do
        namespace.add_owner(owner)
      end

      it 'returns true' do
        expect(violation.readable_by?(owner)).to be true
      end
    end

    context 'when user does not have permission to read compliance violations report' do
      it 'returns false' do
        expect(violation.readable_by?(regular_user)).to be false
      end
    end

    context 'when user is nil' do
      it 'returns false' do
        expect(violation.readable_by?(nil)).to be false
      end
    end
  end

  describe 'public getter methods' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:compliance_control) { create(:compliance_requirements_control, namespace: namespace) }
    let_it_be(:audit_event) { create(:audit_events_project_audit_event, project_id: project.id) }

    subject(:violation) do
      create(:project_compliance_violation,
        project: project,
        namespace: namespace,
        compliance_control: compliance_control,
        audit_event_id: audit_event.id,
        audit_event_table_name: :project_audit_events
      )
    end

    describe '#name' do
      it 'returns the formatted name with the violation ID' do
        expect(violation.name).to eq("Compliance Violation ##{violation.id}")
      end
    end

    describe '#requirement' do
      it 'returns the requirement' do
        expect(violation.requirement).to eq(compliance_control.compliance_requirement)
      end
    end

    describe '#framework' do
      it 'returns the framework' do
        expect(violation.framework).to eq(compliance_control.compliance_requirement.framework)
      end
    end

    describe '#to_global_id' do
      it 'returns a global id for the violation' do
        expected_gid = Gitlab::GlobalId.as_global_id(
          violation.id,
          model_name: 'ComplianceManagement::Projects::ComplianceViolation'
        )

        expect(violation.to_global_id).to eq(expected_gid)
      end
    end

    describe '#to_ability_name' do
      it 'returns compliance_violations_report for subscription authorization' do
        expect(violation.to_ability_name).to eq('compliance_violations_report')
      end
    end
  end
end
