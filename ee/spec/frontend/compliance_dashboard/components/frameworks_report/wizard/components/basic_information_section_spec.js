import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { GlAccordionItem } from '@gitlab/ui';
import * as Utils from 'ee/groups/settings/compliance_frameworks/utils';
import BasicInformationSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/basic_information_section.vue';
import complianceFrameworkNameCheckQuery from 'ee/compliance_dashboard/components/frameworks_report/wizard/graphql/compliance_framework_name_check.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('Basic information section', () => {
  Vue.use(VueRouter);
  let wrapper;
  const fakeFramework = {
    id: '1',
    name: 'Foo',
    description: 'Bar',
    pipelineConfigurationFullPath: null,
    color: null,
  };

  const defaultProvides = {
    migratePipelineToPolicyPath: '/migratepipelinetopolicypath',
    pipelineConfigurationFullPathEnabled: true,
    pipelineConfigurationEnabled: true,
    pipelineExecutionPolicyPath: '/policypath',
    groupPath: 'group-path',
  };

  const buildNameCheckResponse = (nodes = []) => ({
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        complianceFrameworks: {
          nodes,
        },
      },
    },
  });

  const invalidFeedback = (input) =>
    input.closest('[role=group].is-invalid')?.querySelector('.invalid-feedback').textContent ?? '';

  const router = new VueRouter();

  const createComponent = (props, provides, { nameCheckHandler } = {}) => {
    const handler = nameCheckHandler || jest.fn().mockResolvedValue(buildNameCheckResponse());
    const apolloProvider = createMockApollo([[complianceFrameworkNameCheckQuery, handler]]);
    wrapper = mountExtended(BasicInformationSection, {
      apolloProvider,
      provide: {
        ...defaultProvides,
        ...provides,
      },
      propsData: {
        value: fakeFramework,
        ...props,
      },
      stubs: {
        ColorPicker: true,
      },
      router,
    });
    return handler;
  };
  const findMaintenanceAlert = () => wrapper.findComponentByTestId('maintenance-mode-alert');
  const findMigrationActionButton = () => wrapper.findComponentByTestId('migrate-action-button');
  const findPipelineInput = () => wrapper.findComponentByTestId('pipeline-configuration-input');
  const findDisabledPipelineInput = () =>
    wrapper.findComponentByTestId('disabled-pipeline-configuration-input');
  const findDisabledPipelineInputGroup = () =>
    wrapper.findComponentByTestId('disabled-pipeline-configuration-input-group');
  const findDisabledPipelineInputPopover = () =>
    wrapper.findComponentByTestId('disabled-pipeline-configuration-input-popover');

  beforeEach(() => {
    createComponent();
  });

  it.each([['Name'], ['Description']])('has valid state initially', (fieldName) => {
    const input = wrapper.findByLabelText(fieldName);
    expect(invalidFeedback(input.element)).toBe('');
  });

  it.each([['Name'], ['Description']])(
    'validates required state for field %s when showValidation is true',
    async (fieldName) => {
      createComponent({ showValidation: true });
      const input = wrapper.findByLabelText(fieldName);
      await input.setValue('');

      expect(invalidFeedback(input.element)).toContain('is required');
    },
  );

  it.each([['default'], ['dEfAuLt'], ['Default']])(
    'rejects %s as framework name when showValidation is true',
    async (name) => {
      createComponent({ showValidation: true });
      const input = wrapper.findByLabelText('Name');
      await input.setValue(name);

      expect(invalidFeedback(input.element)).toContain('is a reserved word');
    },
  );

  describe('duplicate name validation', () => {
    const findValidityEvents = () => wrapper.emitted('validity-change') ?? [];
    const lastValidity = () => {
      const events = findValidityEvents();
      return events[events.length - 1]?.[0];
    };

    it('does not query on mount when name is empty', () => {
      const handler = createComponent({ value: { ...fakeFramework, name: '' } });
      expect(handler).not.toHaveBeenCalled();
    });

    it('queries on mount when name is pre-populated (e.g. from template selection)', async () => {
      const handler = createComponent({ value: { ...fakeFramework, id: null, name: 'Templated' } });
      await waitForPromises();
      expect(handler).toHaveBeenCalledWith({ fullPath: 'group-path', search: 'Templated' });
    });

    it('flags a pre-populated template name on mount if it duplicates an existing framework', async () => {
      const handler = jest
        .fn()
        .mockResolvedValue(
          buildNameCheckResponse([
            { id: 'gid://gitlab/ComplianceFramework/99', name: 'Templated' },
          ]),
        );
      createComponent(
        { value: { ...fakeFramework, id: null, name: 'Templated' } },
        {},
        { nameCheckHandler: handler },
      );
      await waitForPromises();

      expect(invalidFeedback(wrapper.findByLabelText('Name').element)).toContain('already exists');
    });

    it('does not query on mount for a reserved pre-populated name', () => {
      const handler = createComponent({ value: { ...fakeFramework, name: 'default' } });
      expect(handler).not.toHaveBeenCalled();
    });

    it('queries the server on blur with the current name', async () => {
      const handler = createComponent({ value: { ...fakeFramework, name: 'Existing' } });
      const input = wrapper.findByLabelText('Name');

      await input.trigger('blur');
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({ fullPath: 'group-path', search: 'Existing' });
    });

    it('flags the name as invalid when an exact-match framework exists', async () => {
      const handler = jest
        .fn()
        .mockResolvedValue(
          buildNameCheckResponse([{ id: 'gid://gitlab/ComplianceFramework/99', name: 'Existing' }]),
        );
      createComponent(
        { value: { ...fakeFramework, id: null, name: 'Existing' } },
        {},
        { nameCheckHandler: handler },
      );

      await wrapper.findByLabelText('Name').trigger('blur');
      await waitForPromises();

      expect(invalidFeedback(wrapper.findByLabelText('Name').element)).toContain('already exists');
      expect(lastValidity()).toBe(false);
    });

    it('case-sensitive match: does not flag when only case differs', async () => {
      const handler = jest
        .fn()
        .mockResolvedValue(
          buildNameCheckResponse([{ id: 'gid://gitlab/ComplianceFramework/99', name: 'EXISTING' }]),
        );
      createComponent(
        { value: { ...fakeFramework, id: null, name: 'Existing' } },
        {},
        { nameCheckHandler: handler },
      );

      await wrapper.findByLabelText('Name').trigger('blur');
      await waitForPromises();

      expect(invalidFeedback(wrapper.findByLabelText('Name').element)).toBe('');
    });

    it('does not flag the current framework as a duplicate of itself (edit mode)', async () => {
      const ownId = 'gid://gitlab/ComplianceFramework/1';
      const handler = jest
        .fn()
        .mockResolvedValue(buildNameCheckResponse([{ id: ownId, name: 'Foo' }]));
      createComponent(
        { value: { ...fakeFramework, id: ownId, name: 'Foo' } },
        {},
        { nameCheckHandler: handler },
      );

      await wrapper.findByLabelText('Name').trigger('blur');
      await waitForPromises();

      expect(invalidFeedback(wrapper.findByLabelText('Name').element)).toBe('');
    });

    it('clears the duplicate error as the user starts typing again', async () => {
      const handler = jest
        .fn()
        .mockResolvedValue(
          buildNameCheckResponse([{ id: 'gid://gitlab/ComplianceFramework/99', name: 'Existing' }]),
        );
      createComponent(
        { value: { ...fakeFramework, id: null, name: 'Existing' } },
        {},
        { nameCheckHandler: handler },
      );

      const input = wrapper.findByLabelText('Name');
      await input.trigger('blur');
      await waitForPromises();
      expect(invalidFeedback(input.element)).toContain('already exists');

      await input.setValue('Existing-edited');
      await nextTick();

      expect(invalidFeedback(wrapper.findByLabelText('Name').element)).toBe('');
    });

    it('skips the query for reserved names', async () => {
      const handler = createComponent({ value: { ...fakeFramework, name: 'default' } });
      await wrapper.findByLabelText('Name').trigger('blur');
      await waitForPromises();
      expect(handler).not.toHaveBeenCalled();
    });

    it('skips the query when the name input is disabled (inherited framework)', async () => {
      const handler = createComponent({ isInherited: true });
      await wrapper.findByLabelText('Name').trigger('blur');
      await waitForPromises();
      expect(handler).not.toHaveBeenCalled();
    });

    it('ignores stale responses when the user blurs again with a different name', async () => {
      let resolveFirst;
      const firstResponse = new Promise((resolve) => {
        resolveFirst = resolve;
      });
      const handler = jest
        .fn()
        .mockImplementationOnce(() => firstResponse)
        .mockResolvedValueOnce(buildNameCheckResponse());

      createComponent(
        { value: { ...fakeFramework, id: null, name: 'Old' } },
        {},
        { nameCheckHandler: handler },
      );

      const input = wrapper.findByLabelText('Name');
      await input.trigger('blur');
      await input.setValue('New');
      await input.trigger('blur');
      await waitForPromises();

      // First (stale) request resolves last with a duplicate hit — must be ignored.
      resolveFirst(
        buildNameCheckResponse([{ id: 'gid://gitlab/ComplianceFramework/99', name: 'Old' }]),
      );
      await waitForPromises();

      expect(invalidFeedback(wrapper.findByLabelText('Name').element)).toBe('');
    });
  });

  it.each`
    pipelineConfigurationFullPath | message
    ${'foo.yml@bar/baz'}          | ${'Configuration not found'}
    ${'foobar'}                   | ${'Invalid format'}
  `(
    'sets the correct invalid message for pipeline when showValidation is true',
    async ({ pipelineConfigurationFullPath, message }) => {
      jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);
      createComponent({
        showValidation: true,
        value: { ...fakeFramework, pipelineConfigurationFullPath: 'initial/path.yml' },
      });

      const pipelineInput = findPipelineInput();
      await pipelineInput.setValue(pipelineConfigurationFullPath);
      await waitForPromises();

      expect(invalidFeedback(pipelineInput.element)).toBe(message);
    },
  );

  describe('pipeline editing section', () => {
    it('hides the accordion when there is no pipeline configuration path', () => {
      createComponent({
        value: { ...fakeFramework, pipelineConfigurationFullPath: '' },
      });

      const accordionItem = wrapper.findComponent(GlAccordionItem);
      expect(accordionItem.exists()).toBe(false);
    });

    it('expands the section when there is a pipeline configuration path', () => {
      createComponent({
        value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' },
      });

      const accordionItem = wrapper.findComponent(GlAccordionItem);
      expect(accordionItem.props('visible')).toBe(true);
    });

    describe('when pipelineConfigurationEnabled is true', () => {
      beforeEach(() => {
        createComponent(
          { value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' } },
          { pipelineConfigurationEnabled: true },
        );
      });

      it('shows the enabled pipeline configuration input', () => {
        expect(findPipelineInput().exists()).toBe(true);
        expect(findDisabledPipelineInput().exists()).toBe(false);
      });

      it('shows the maintenance mode alert', () => {
        expect(findMaintenanceAlert().exists()).toBe(true);
      });

      it('hides the entire accordion when pipelineConfigurationFullPath is null', () => {
        createComponent(
          { value: { ...fakeFramework, pipelineConfigurationFullPath: null } },
          { pipelineConfigurationEnabled: true },
        );

        expect(wrapper.findComponent(GlAccordionItem).exists()).toBe(false);
        expect(findPipelineInput().exists()).toBe(false);
        expect(findDisabledPipelineInput().exists()).toBe(false);
      });

      it('hides the entire accordion when pipelineConfigurationFullPath is empty', () => {
        createComponent(
          { value: { ...fakeFramework, pipelineConfigurationFullPath: '' } },
          { pipelineConfigurationEnabled: true },
        );

        expect(wrapper.findComponent(GlAccordionItem).exists()).toBe(false);
        expect(findPipelineInput().exists()).toBe(false);
        expect(findDisabledPipelineInput().exists()).toBe(false);
      });

      it('shows pipeline configuration input when pipelineConfigurationFullPath has a value', () => {
        createComponent(
          { value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' } },
          { pipelineConfigurationEnabled: true },
        );

        expect(findPipelineInput().exists()).toBe(true);
      });
    });

    describe('when pipelineConfigurationEnabled is false', () => {
      beforeEach(() => {
        createComponent(
          { value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' } },
          { pipelineConfigurationEnabled: false },
        );
      });

      it('shows the disabled pipeline configuration input inside accordion', () => {
        expect(findDisabledPipelineInput().exists()).toBe(true);
        expect(findPipelineInput().exists()).toBe(false);
      });

      it('shows the disabled input group with description', () => {
        const inputGroup = findDisabledPipelineInputGroup();
        expect(inputGroup.exists()).toBe(true);
        expect(inputGroup.text()).toContain('path/file.y[a]ml@group-name/project-name');
      });

      it('shows the popover explaining why input is disabled', () => {
        const popover = findDisabledPipelineInputPopover();
        expect(popover.exists()).toBe(true);
        expect(popover.props('title')).toBe('Requires Ultimate subscription');
      });

      it('does not show the maintenance mode alert', () => {
        expect(findMaintenanceAlert().exists()).toBe(false);
      });
    });
  });

  describe('maintenance mode alert', () => {
    it('renders message about suggested migration when hasMigratedPipeline is false', async () => {
      createComponent({
        value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' },
      });

      const maintenanceAlert = findMaintenanceAlert();
      const actionButton = findMigrationActionButton();

      expect(maintenanceAlert.exists()).toBe(true);
      expect(maintenanceAlert.text()).toContain('Compliance pipelines are deprecated');

      expect(actionButton.text()).toContain('Migrate pipeline to a policy');

      jest.spyOn(Utils, 'fetchPipelineConfigurationFileExists').mockReturnValue(false);
      const pipelineYAMLPath = 'file.yaml@group/project';
      const pipelineInput = findPipelineInput();
      await pipelineInput.setValue(pipelineYAMLPath);
      await waitForPromises();

      expect(actionButton.text()).toContain('Migrate pipeline to a policy');
      const urlParams = new URLSearchParams(actionButton.attributes('href').split('?')[1]);
      expect(urlParams.get('path')).toBe(pipelineYAMLPath);
      expect(urlParams.get('compliance_framework_name')).toBe(fakeFramework.name);
      expect(urlParams.get('compliance_framework_id')).toBe(fakeFramework.id.toString());
    });

    it('renders message about completing migration when hasMigratedPipeline is true and we have previous pipeline', () => {
      createComponent({
        hasMigratedPipeline: true,
        value: { ...fakeFramework, pipelineConfigurationFullPath: 'foo.yml@bar/baz' },
      });

      const maintenanceAlert = findMaintenanceAlert();
      const actionButton = findMigrationActionButton();

      expect(maintenanceAlert.exists()).toBe(true);
      expect(actionButton.exists()).toBe(false);

      expect(maintenanceAlert.text()).toContain(
        `This compliance framework's compliance pipeline has been migrated to a pipeline execution policy`,
      );
    });

    it('does not render the accordion when hasMigratedPipeline is true but we do not have previous pipeline', () => {
      createComponent({
        hasMigratedPipeline: true,
        value: { ...fakeFramework, pipelineConfigurationFullPath: '' },
      });

      expect(wrapper.findComponent(GlAccordionItem).exists()).toBe(false);
      expect(findMaintenanceAlert().exists()).toBe(false);
    });
  });

  describe('CSP framework behavior', () => {
    describe('when framework is inherited', () => {
      beforeEach(() => {
        createComponent({
          isInherited: true,
          value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' },
        });
      });

      it('disables the name input', () => {
        const nameInput = wrapper.findByLabelText('Name');
        expect(nameInput.attributes('disabled')).toBeDefined();
      });

      it('disables the description input', () => {
        const descriptionInput = wrapper.findByLabelText('Description');
        expect(descriptionInput.attributes('disabled')).toBeDefined();
      });

      it('disables the pipeline configuration input', () => {
        const pipelineInput = wrapper.find('[data-testid="pipeline-configuration-input"]');
        expect(pipelineInput.attributes('disabled')).toBeDefined();
      });

      it('disables the default checkbox', () => {
        const defaultCheckbox = wrapper.find('input[name="default"]');
        expect(defaultCheckbox.attributes('disabled')).toBeDefined();
      });

      it('shows readonly color input as disabled', () => {
        const colorDisplayGroup = wrapper.find('[data-testid="color-display-group"]');
        const colorInput = colorDisplayGroup.find('input');

        expect(colorInput.attributes('disabled')).toBeDefined();
        expect(colorInput.attributes('readonly')).toBeDefined();
      });
    });

    describe('when framework is not inherited', () => {
      beforeEach(() => {
        createComponent({ isInherited: false });
      });

      it('does not disable the name input', () => {
        const nameInput = wrapper.findByLabelText('Name');
        expect(nameInput.attributes('disabled')).toBeUndefined();
      });

      it('does not disable the description input', () => {
        const descriptionInput = wrapper.findByLabelText('Description');
        expect(descriptionInput.attributes('disabled')).toBeUndefined();
      });

      it('does not disable the default checkbox', () => {
        const defaultCheckbox = wrapper.find('input[name="default"]');
        expect(defaultCheckbox.attributes('disabled')).toBeUndefined();
      });

      it('does not apply pipeline configuration disabled state', () => {
        createComponent({
          isInherited: false,
          value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' },
        });

        const pipelineInput = findPipelineInput();
        if (pipelineInput.exists()) {
          expect(pipelineInput.attributes('disabled')).toBeUndefined();
        }
      });

      it('shows the color picker and hides readonly color display', () => {
        const colorPicker = wrapper.findComponent({ name: 'ColorPicker' });
        const colorDisplayGroup = wrapper.find('[data-testid="color-display-group"]');

        expect(colorPicker.exists()).toBe(true);
        expect(colorDisplayGroup.exists()).toBe(false);
      });
    });

    describe('when isInherited prop is not provided', () => {
      beforeEach(() => {
        createComponent({
          value: { ...fakeFramework, pipelineConfigurationFullPath: 'some/path.yml' },
        });
      });

      it('defaults to non-inherited behavior', () => {
        const nameInput = wrapper.findByLabelText('Name');
        const descriptionInput = wrapper.findByLabelText('Description');
        const pipelineInput = findPipelineInput();

        expect(nameInput.attributes('disabled')).toBeUndefined();
        expect(descriptionInput.attributes('disabled')).toBeUndefined();
        expect(pipelineInput.attributes('disabled')).toBeUndefined();
      });
    });
  });
});
