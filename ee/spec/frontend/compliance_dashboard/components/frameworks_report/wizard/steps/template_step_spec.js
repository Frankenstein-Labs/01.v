import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TemplateStep from 'ee/compliance_dashboard/components/frameworks_report/wizard/steps/template_step.vue';
import TemplateInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/template_info_drawer.vue';
import complianceFrameworkTemplatesQuery from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/compliance_framework_templates.query.graphql';

Vue.use(VueApollo);

describe('TemplateStep', () => {
  let wrapper;

  const gdprJson = JSON.stringify({
    name: 'GDPR',
    requirements: [
      {
        name: 'Article 25',
        description: 'desc',
        controls: [{ name: 'sast', control_type: 'internal' }],
      },
    ],
  });

  const templates = [
    {
      id: 'gid://gitlab/ComplianceManagement::Frameworks::TemplateRegistry::Template/gdpr',
      templateVersion: 1,
      name: 'GDPR',
      description: 'EU data privacy',
      color: '#009966',
      json: gdprJson,
    },
  ];

  const successHandler = jest
    .fn()
    .mockResolvedValue({ data: { complianceFrameworkTemplates: templates } });
  const emptyHandler = jest.fn().mockResolvedValue({ data: { complianceFrameworkTemplates: [] } });
  const errorHandler = jest.fn().mockRejectedValue(new Error('boom'));

  const createComponent = (handler = successHandler) => {
    const apolloProvider = createMockApollo([[complianceFrameworkTemplatesQuery, handler]]);
    wrapper = shallowMountExtended(TemplateStep, { apolloProvider });
  };

  const findCard = (id) => wrapper.findByTestId(`template-${id}`);
  const findUseTemplateBtn = (id) => findCard(id).findComponent('[data-testid="use-template-btn"]');
  const findViewDetailsBtn = (id) => findCard(id).findComponent('[data-testid="view-details-btn"]');
  const findDrawer = () => wrapper.findComponent(TemplateInfoDrawer);
  const findEmpty = () => wrapper.findByTestId('template-step-empty');
  const findError = () => wrapper.findByTestId('template-step-error');

  const expectedSelectedPayload = {
    id: templates[0].id,
    name: 'GDPR',
    description: 'EU data privacy',
    color: '#009966',
    requirements: [
      {
        name: 'Article 25',
        description: 'desc',
        controls: [{ name: 'sast', control_type: 'internal' }],
      },
    ],
  };

  it('shows a loading spinner while fetching', () => {
    createComponent();
    expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
  });

  it('renders a card for each template once loaded', async () => {
    createComponent();
    await waitForPromises();

    const card = findCard(templates[0].id);
    expect(card.exists()).toBe(true);
    expect(card.text()).toContain('GDPR');
    expect(card.text()).toContain('EU data privacy');
  });

  it('renders requirements and controls counts as badges parsed from the template JSON', async () => {
    createComponent();
    await waitForPromises();

    expect(wrapper.findByTestId('requirements-badge').text()).toContain('1 requirement');
    expect(wrapper.findByTestId('controls-badge').text()).toContain('1 control');
  });

  it('emits template-selected with parsed requirements when Use template is clicked', async () => {
    createComponent();
    await waitForPromises();

    findUseTemplateBtn(templates[0].id).vm.$emit('click');

    expect(wrapper.emitted('template-selected')).toEqual([[expectedSelectedPayload]]);
  });

  it('does not emit template-selected when the card body is clicked', async () => {
    createComponent();
    await waitForPromises();

    await findCard(templates[0].id).trigger('click');

    expect(wrapper.emitted('template-selected')).toBeUndefined();
  });

  describe('View details drawer', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('starts with the drawer closed (no template passed)', () => {
      expect(findDrawer().props('template')).toBeNull();
    });

    it('opens the drawer for the picked template when View details is clicked', async () => {
      findViewDetailsBtn(templates[0].id).vm.$emit('click');
      await Vue.nextTick();

      expect(findDrawer().props('template')).toMatchObject({
        id: templates[0].id,
        name: 'GDPR',
      });
    });

    it('closes the drawer when the drawer emits close', async () => {
      findViewDetailsBtn(templates[0].id).vm.$emit('click');
      await Vue.nextTick();
      findDrawer().vm.$emit('close');
      await Vue.nextTick();

      expect(findDrawer().props('template')).toBeNull();
    });

    it('emits template-selected and closes the drawer when use-template is fired from drawer', async () => {
      findViewDetailsBtn(templates[0].id).vm.$emit('click');
      await Vue.nextTick();
      findDrawer().vm.$emit('use-template', { ...expectedSelectedPayload });
      await Vue.nextTick();

      expect(wrapper.emitted('template-selected')).toEqual([[expectedSelectedPayload]]);
      expect(findDrawer().props('template')).toBeNull();
    });
  });

  it('renders an empty state when no templates are returned', async () => {
    createComponent(emptyHandler);
    await waitForPromises();

    expect(findEmpty().exists()).toBe(true);
  });

  it('renders an error alert when the query fails', async () => {
    createComponent(errorHandler);
    await waitForPromises();

    expect(findError().exists()).toBe(true);
    expect(wrapper.findComponent(GlAlert).props('variant')).toBe('danger');
  });
});
