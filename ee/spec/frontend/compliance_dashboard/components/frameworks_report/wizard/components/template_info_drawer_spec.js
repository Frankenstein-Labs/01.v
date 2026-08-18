import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlDrawer } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TemplateInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/template_info_drawer.vue';
import complianceRequirementControlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';

Vue.use(VueApollo);

describe('TemplateInfoDrawer', () => {
  let wrapper;

  const gitlabControls = [
    { id: 'scanner_sast_running', name: 'SAST running', expression: null },
    { id: 'scanner_dep_scanning_running', name: 'Dependency scanning running', expression: null },
  ];

  const controlsHandler = jest.fn().mockResolvedValue({
    data: { complianceRequirementControls: { controlExpressions: gitlabControls } },
  });

  const template = {
    id: 'gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/gdpr',
    name: 'GDPR',
    description: 'EU data privacy',
    color: '#009966',
    requirements: [
      {
        name: 'Article 25',
        description: 'desc',
        controls: [
          { name: 'scanner_sast_running', control_type: 'internal' },
          { name: 'scanner_dep_scanning_running', control_type: 'internal' },
        ],
      },
      { name: 'Article 32', description: 'sec', controls: [] },
    ],
  };

  const createComponent = ({ templateProp = template } = {}) => {
    const apolloProvider = createMockApollo([
      [complianceRequirementControlsQuery, controlsHandler],
    ]);
    wrapper = mountExtended(TemplateInfoDrawer, {
      apolloProvider,
      propsData: { template: templateProp },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findUseBtn = () => wrapper.findByTestId('drawer-use-template-btn');
  const findRequirementsCount = () => wrapper.findByTestId('drawer-requirements-count');

  it('is closed when no template is provided', () => {
    createComponent({ templateProp: null });
    expect(findDrawer().props('open')).toBe(false);
  });

  it('opens with the template name and description when a template is provided', () => {
    createComponent();
    expect(findDrawer().props('open')).toBe(true);
    expect(wrapper.findByTestId('drawer-template-name').text()).toBe('GDPR');
    expect(wrapper.findByTestId('drawer-template-description').text()).toContain('EU data privacy');
  });

  it('shows the requirements count', () => {
    createComponent();
    expect(findRequirementsCount().text()).toBe('2');
  });

  it('emits use-template with the template payload when Use template is clicked', async () => {
    createComponent();
    await findUseBtn().trigger('click');
    expect(wrapper.emitted('use-template')).toEqual([[template]]);
  });

  it('emits close when the drawer is closed', async () => {
    createComponent();
    await findDrawer().vm.$emit('close');
    expect(wrapper.emitted('close')).toEqual([[]]);
  });

  it('renders human-readable display values for each control', async () => {
    createComponent();
    await waitForPromises();
    await nextTick();

    const text = wrapper.text();
    expect(text).toContain('SAST running');
    expect(text).toContain('Dependency scanning running');
    expect(text).not.toContain('scanner_sast_running');
  });
});
