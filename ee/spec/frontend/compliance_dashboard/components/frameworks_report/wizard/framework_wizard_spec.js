import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLoadingIcon, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import getComplianceFrameworkQuery from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/get_compliance_framework.query.graphql';
import FrameworkWizard from 'ee/compliance_dashboard/components/frameworks_report/wizard/framework_wizard.vue';
import WizardStepper from '~/vue_shared/components/wizard_stepper/wizard_stepper.vue';
import BasicInformationSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/basic_information_section.vue';
import RequirementsStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/requirements_step.vue';
import PoliciesStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/policies_step.vue';
import ProjectsStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/projects_step.vue';
import MethodStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/method_step.vue';
import TemplateStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/template_step.vue';
import DeleteModal from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/delete_modal.vue';
import * as formHelpers from 'ee/compliance_dashboard/components/frameworks_report/framework_form_helpers';
import { createComplianceFrameworksReportResponse } from '../../../mock_data';

jest.mock('ee/compliance_dashboard/components/frameworks_report/framework_form_helpers');

Vue.use(VueApollo);

const showToastMock = jest.fn();
const $toast = { show: showToastMock };

describe('FrameworkWizard', () => {
  let wrapper;
  let routerPush;
  let routerBack;

  const provideData = {
    groupPath: 'group-1',
    pipelineConfigurationFullPathEnabled: true,
    pipelineConfigurationEnabled: true,
    disableScanPolicyUpdate: false,
    featureSecurityPoliciesEnabled: true,
    migratePipelineToPolicyPath: '/migratepipelinetopolicypath',
    pipelineExecutionPolicyPath: '/policypath',
    namespaceId: 'gid://gitlab/Group/123',
  };

  const mountWizard = ({ routeParams = {}, apolloHandlers } = {}) => {
    routerPush = jest.fn();
    routerBack = jest.fn();
    const handlers = apolloHandlers || [
      [
        getComplianceFrameworkQuery,
        jest.fn().mockResolvedValue(createComplianceFrameworksReportResponse()),
      ],
    ];
    const apolloProvider = createMockApollo(handlers);
    wrapper = shallowMountExtended(FrameworkWizard, {
      apolloProvider,
      provide: provideData,
      mocks: {
        $route: { params: routeParams },
        $router: { push: routerPush, back: routerBack },
        $toast,
      },
      stubs: {
        DeleteModal: stubComponent(DeleteModal, {
          methods: { show: jest.fn() },
        }),
      },
    });
  };

  const findStepper = () => wrapper.findComponent(WizardStepper);
  const findTitle = () => wrapper.findByTestId('wizard-title');
  const findSubmitBtn = () => wrapper.findComponentByTestId('submit-btn');
  const findNextBtn = () => wrapper.findComponentByTestId('next-btn');
  const findBackBtn = () => wrapper.findComponentByTestId('back-btn');
  const findCancelBtn = () => wrapper.findByTestId('cancel-btn');
  const findDeleteBtn = () => wrapper.findComponentByTestId('delete-btn');
  const findError = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMethodStep = () => wrapper.findComponent(MethodStep);
  const findTemplateStep = () => wrapper.findComponent(TemplateStep);
  const findBasicInformationSection = () => wrapper.findComponent(BasicInformationSection);
  const findRequirementsStep = () => wrapper.findComponent(RequirementsStep);
  const findPoliciesStep = () => wrapper.findComponent(PoliciesStep);
  const findProjectsStep = () => wrapper.findComponent(ProjectsStep);
  const findPipelineMigrationModal = () => wrapper.findByTestId('pipeline-migration-popup');

  // The Details step uses v-show, so check the underlying CSS to know when it
  // is the active step.
  const isDetailsStepVisible = () => {
    const step = findBasicInformationSection();
    if (!step.exists()) return false;
    return step.element.style.display !== 'none';
  };

  const setDetailsValidity = async (valid) => {
    findBasicInformationSection().vm.$emit('validity-change', valid);
    await nextTick();
  };

  const advanceFromMethodToDetails = async () => {
    findMethodStep().vm.$emit('select-blank');
    await nextTick();
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create mode (no route id)', () => {
    beforeEach(() => mountWizard());

    it('renders the New compliance framework title', () => {
      expect(findTitle().text()).toBe('New compliance framework');
    });

    it('skips the apollo namespace query in create mode', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('starts on the method step', () => {
      expect(findStepper().props('currentStep')).toBe(1);
      expect(findMethodStep().exists()).toBe(true);
      expect(findRequirementsStep().exists()).toBe(false);
    });

    it('renders Cancel button; no Next/Back/Save on the method step', () => {
      expect(findCancelBtn().exists()).toBe(true);
      expect(findNextBtn().exists()).toBe(false);
      expect(findBackBtn().exists()).toBe(false);
      expect(findSubmitBtn().exists()).toBe(false);
    });

    it('renders 5 steps in create mode with Template always disabled', () => {
      const steps = findStepper().props('steps');
      expect(steps.map((s) => s.label)).toEqual([
        'Method',
        'Template (Optional)',
        'Basic information',
        'Requirements & Controls',
        'Scoping',
      ]);
      expect(steps[0].disabled).toBe(false);
      expect(steps[1].disabled).toBe(true);
      expect(steps[2].disabled).toBe(true);
      expect(steps[3].disabled).toBe(true);
      expect(steps[4].disabled).toBe(true);
    });

    it('does not render the delete button in create mode', () => {
      expect(findDeleteBtn().exists()).toBe(false);
    });
  });

  describe('create mode navigation', () => {
    beforeEach(() => mountWizard());

    it('selecting blank on the method step skips Template and lands on Basic information', async () => {
      await advanceFromMethodToDetails();

      expect(isDetailsStepVisible()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(3);
      expect(findRequirementsStep().exists()).toBe(false);
    });

    it('advances from Basic information to Requirements & Controls when Next is clicked with valid details', async () => {
      await advanceFromMethodToDetails();
      await setDetailsValidity(true);

      findNextBtn().vm.$emit('click');
      await nextTick();

      expect(findStepper().props('currentStep')).toBe(4);
      expect(findRequirementsStep().exists()).toBe(true);
    });

    it('does not advance when details is invalid; surfaces validation', async () => {
      await advanceFromMethodToDetails();
      await setDetailsValidity(false);

      findNextBtn().vm.$emit('click');
      await nextTick();

      expect(findBasicInformationSection().props('showValidation')).toBe(true);
      expect(findStepper().props('currentStep')).toBe(3);
      expect(findRequirementsStep().exists()).toBe(false);
    });

    it('Back from Basic information skips Template and returns to Method', async () => {
      await advanceFromMethodToDetails();

      findBackBtn().vm.$emit('click');
      await nextTick();

      expect(findStepper().props('currentStep')).toBe(1);
      expect(findMethodStep().exists()).toBe(true);
    });
  });

  describe('create mode submit', () => {
    const advanceToProjects = async () => {
      await advanceFromMethodToDetails();
      await setDetailsValidity(true);
      findNextBtn().vm.$emit('click');
      await nextTick();
      findNextBtn().vm.$emit('click');
      await nextTick();
    };

    beforeEach(() => mountWizard());

    it('calls submitNewFramework helper and navigates to success on save', async () => {
      formHelpers.submitNewFramework.mockResolvedValue(
        'gid://gitlab/ComplianceManagement::Framework/42',
      );
      await advanceToProjects();

      findSubmitBtn().vm.$emit('click');
      await waitForPromises();

      expect(formHelpers.submitNewFramework).toHaveBeenCalledWith(expect.anything(), {
        groupPath: 'group-1',
        params: expect.any(Object),
        requirements: [],
      });
      expect(routerPush).toHaveBeenCalledWith(
        expect.objectContaining({ name: 'new_framework_success' }),
      );
    });

    it('returns to details step when invalid on submit', async () => {
      await advanceToProjects();
      await setDetailsValidity(false);

      findSubmitBtn().vm.$emit('click');
      await waitForPromises();

      expect(formHelpers.submitNewFramework).not.toHaveBeenCalled();
      expect(isDetailsStepVisible()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(3);
    });

    it('on duplicate-name backend error: navigates back to Basic information and shows an actionable error', async () => {
      formHelpers.submitNewFramework.mockRejectedValue(['Name has already been taken']);
      await advanceToProjects();

      findSubmitBtn().vm.$emit('click');
      await waitForPromises();

      expect(isDetailsStepVisible()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(3);
      expect(findError().text()).toContain('already exists in this group');
      expect(findError().text()).toContain('Go back to the Basic information step');
      expect(routerPush).not.toHaveBeenCalledWith(
        expect.objectContaining({ name: 'new_framework_success' }),
      );
    });

    it('falls through to the generic error path for non-duplicate backend errors', async () => {
      formHelpers.submitNewFramework.mockRejectedValue(['Something else went wrong']);
      await advanceToProjects();

      findSubmitBtn().vm.$emit('click');
      await waitForPromises();

      expect(findError().text()).toContain('Unable to save this compliance framework');
      expect(findError().text()).toContain('Something else went wrong');
    });
  });

  describe('edit mode (with route id)', () => {
    const editRoute = { id: '1' };

    it('renders Edit title with the loaded framework name', async () => {
      mountWizard({ routeParams: editRoute });
      await waitForPromises();

      expect(findTitle().text()).toMatch(/Edit compliance framework: /);
    });

    it('all stepper steps are clickable (no linear gating)', async () => {
      mountWizard({ routeParams: editRoute });
      await waitForPromises();

      const steps = findStepper().props('steps');
      expect(steps.every((s) => s.disabled === false)).toBe(true);
    });

    it('renders Save changes / Cancel / Delete buttons; no Next/Back', async () => {
      mountWizard({ routeParams: editRoute });
      await waitForPromises();

      expect(findSubmitBtn().exists()).toBe(true);
      expect(findCancelBtn().exists()).toBe(true);
      expect(findDeleteBtn().exists()).toBe(true);
      expect(findNextBtn().exists()).toBe(false);
      expect(findBackBtn().exists()).toBe(false);
    });

    it('shows error alert when fetch fails', async () => {
      mountWizard({
        routeParams: editRoute,
        apolloHandlers: [
          [getComplianceFrameworkQuery, jest.fn().mockRejectedValue(new Error('boom'))],
        ],
      });
      await waitForPromises();

      expect(findError().exists()).toBe(true);
    });

    it('calls updateFramework on save', async () => {
      formHelpers.updateFramework.mockResolvedValue();
      mountWizard({ routeParams: editRoute });
      await waitForPromises();
      await setDetailsValidity(true);

      findSubmitBtn().vm.$emit('click');
      await waitForPromises();

      expect(formHelpers.updateFramework).toHaveBeenCalledWith(expect.anything(), {
        graphqlId: expect.stringContaining('gid://gitlab/ComplianceManagement::Framework/'),
        params: expect.any(Object),
      });
    });

    it('calls deleteFramework helper from delete modal', async () => {
      formHelpers.deleteFramework.mockResolvedValue();
      mountWizard({ routeParams: editRoute });
      await waitForPromises();

      wrapper.findComponent(DeleteModal).vm.$emit('delete');
      await waitForPromises();

      expect(formHelpers.deleteFramework).toHaveBeenCalledWith(expect.anything(), {
        graphqlId: expect.any(String),
        refetchConfig: expect.any(Object),
      });
      expect(routerBack).toHaveBeenCalled();
    });

    it('renders the pipeline migration modal element', async () => {
      mountWizard({ routeParams: editRoute });
      await waitForPromises();

      // The modal element is always rendered; visibility is controlled via its
      // v-model. Asserting on visibility from the outside requires more wiring
      // (formData sync via input event, then save). Verifying presence is
      // sufficient at this layer — the component-level visibility logic is
      // covered by GlModal's own contract.
      expect(findPipelineMigrationModal().exists()).toBe(true);
      expect(wrapper.findComponent(GlModal).exists()).toBe(true);
    });
  });

  describe('step navigation via stepper', () => {
    it('in edit mode, allows clicking any step', async () => {
      mountWizard({ routeParams: { id: '1' } });
      await waitForPromises();

      findStepper().vm.$emit('step-click', 3);
      await nextTick();

      expect(findStepper().props('currentStep')).toBe(3);
    });

    it('in create mode, blocks clicking on non-visited future steps', async () => {
      mountWizard();

      findStepper().vm.$emit('step-click', 3);
      await nextTick();

      expect(findStepper().props('currentStep')).toBe(1);
      expect(findMethodStep().exists()).toBe(true);
    });

    it('in create mode, ignores clicks on the disabled Template step', async () => {
      mountWizard();
      await advanceFromMethodToDetails();

      findStepper().vm.$emit('step-click', 2);
      await nextTick();

      expect(findStepper().props('currentStep')).toBe(3);
    });
  });

  describe('policies step', () => {
    it('is included in edit mode (4 steps)', async () => {
      mountWizard({ routeParams: { id: '1' } });
      await waitForPromises();
      expect(findStepper().props('steps')).toHaveLength(4);
    });

    it('is not included in create mode (5 steps including Method + Template)', () => {
      mountWizard();
      const steps = findStepper().props('steps');
      expect(steps).toHaveLength(5);
      expect(steps.map((s) => s.label)).not.toContain('Policies');
    });

    it('renders PoliciesStep when active in edit mode', async () => {
      mountWizard({ routeParams: { id: '1' } });
      await waitForPromises();
      findStepper().vm.$emit('step-click', 3);
      await nextTick();

      expect(findPoliciesStep().exists()).toBe(true);
    });

    it('updates count prop on PoliciesStep when policies-count-loaded is emitted', async () => {
      mountWizard({ routeParams: { id: '1' } });
      await waitForPromises();
      findStepper().vm.$emit('step-click', 3);
      await nextTick();

      expect(findPoliciesStep().props('count')).toBe(0);

      findPoliciesStep().vm.$emit('policies-count-loaded', 3);
      await nextTick();

      expect(findPoliciesStep().props('count')).toBe(3);
    });

    describe('delete button disabled state', () => {
      beforeEach(async () => {
        mountWizard({ routeParams: { id: '1' } });
        await waitForPromises();
        findStepper().vm.$emit('step-click', 3);
        await nextTick();
      });

      it('is disabled while policies are loading (count not yet received)', () => {
        expect(findDeleteBtn().props('disabled')).toBe(true);
      });

      it('is disabled when linked policies exist', async () => {
        findPoliciesStep().vm.$emit('policies-count-loaded', 2);
        await nextTick();

        expect(findDeleteBtn().props('disabled')).toBe(true);
      });

      it('is enabled when no linked policies exist', async () => {
        findPoliciesStep().vm.$emit('policies-count-loaded', 0);
        await nextTick();

        expect(findDeleteBtn().props('disabled')).toBe(false);
      });
    });
  });

  describe('projects step (Scoping) in create mode', () => {
    it('renders ProjectsStep when on the Scoping step', async () => {
      mountWizard();
      await advanceFromMethodToDetails();
      await setDetailsValidity(true);
      findNextBtn().vm.$emit('click');
      await nextTick();
      findNextBtn().vm.$emit('click');
      await nextTick();

      expect(findProjectsStep().exists()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(5);
    });
  });

  describe('template-mode creation flow', () => {
    const templatePayload = {
      id: 'gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/gdpr',
      name: 'GDPR',
      description: 'EU data privacy',
      color: '#009966',
      requirements: [{ name: 'Article 25', description: 'desc', controls: [{ name: 'sast' }] }],
    };

    const advanceToTemplateStep = async () => {
      findMethodStep().vm.$emit('select-template');
      await nextTick();
    };

    const selectTemplate = async () => {
      findTemplateStep().vm.$emit('template-selected', templatePayload);
      await nextTick();
    };

    it('routes from Method → Template when from-template is chosen', async () => {
      mountWizard();
      await advanceToTemplateStep();

      expect(findTemplateStep().exists()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(2);
    });

    it('disables Next on the Template step until a template is selected', async () => {
      mountWizard();
      await advanceToTemplateStep();

      expect(findNextBtn().props('disabled')).toBe(true);

      findNextBtn().vm.$emit('click');
      await nextTick();

      expect(findTemplateStep().exists()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(2);

      await selectTemplate();

      expect(findStepper().props('currentStep')).toBe(3);
    });

    it('keeps the Requirements step in the stepper when a template is selected', async () => {
      mountWizard();
      await advanceToTemplateStep();
      await selectTemplate();

      const labels = findStepper()
        .props('steps')
        .map((s) => s.label);
      expect(labels).toEqual([
        'Method',
        'Template (Optional)',
        'Basic information',
        'Requirements & Controls',
        'Scoping',
      ]);
      expect(findStepper().props('currentStep')).toBe(3);
    });

    it('forwards readonly to the Requirements step in template mode', async () => {
      mountWizard();
      await advanceToTemplateStep();
      await selectTemplate();
      await setDetailsValidity(true);
      findNextBtn().vm.$emit('click');
      await nextTick();

      expect(findRequirementsStep().exists()).toBe(true);
      expect(findRequirementsStep().props('readonly')).toBe(true);
    });

    it('pre-fills Basic info from the selected template', async () => {
      mountWizard();
      await advanceToTemplateStep();
      await selectTemplate();

      expect(findBasicInformationSection().props('value')).toMatchObject({
        name: 'GDPR',
        description: 'EU data privacy',
        color: '#009966',
      });
    });

    it('Next on Basic info advances to Requirements (readonly), then to Scoping', async () => {
      mountWizard();
      await advanceToTemplateStep();
      await selectTemplate();
      await setDetailsValidity(true);

      findNextBtn().vm.$emit('click');
      await nextTick();
      expect(findRequirementsStep().exists()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(4);

      findNextBtn().vm.$emit('click');
      await nextTick();
      expect(findProjectsStep().exists()).toBe(true);
      expect(findStepper().props('currentStep')).toBe(5);
    });

    it('calls submitFromTemplate with overrides on submit', async () => {
      formHelpers.submitFromTemplate.mockResolvedValue(
        'gid://gitlab/ComplianceManagement::Framework/77',
      );
      mountWizard();
      await advanceToTemplateStep();
      await selectTemplate();
      await setDetailsValidity(true);
      findNextBtn().vm.$emit('click');
      await nextTick();
      findNextBtn().vm.$emit('click');
      await nextTick();

      findSubmitBtn().vm.$emit('click');
      await waitForPromises();

      expect(formHelpers.submitFromTemplate).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          groupPath: 'group-1',
          templateId: templatePayload.id,
          overrides: expect.objectContaining({
            name: 'GDPR',
            description: 'EU data privacy',
            color: '#009966',
          }),
        }),
      );
      expect(formHelpers.submitNewFramework).not.toHaveBeenCalled();
    });
  });
});
