import { GlForm, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';

import AiCatalogMcpServerForm from 'ee/ai/catalog/components/ai_catalog_mcp_server_form.vue';

describe('AiCatalogMcpServerForm', () => {
  let wrapper;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.find('#mcp-server-name');
  const findDescriptionTextarea = () => wrapper.find('#mcp-server-description');
  const findUrlInput = () => wrapper.find('#mcp-server-url');
  const findHomepageUrlInput = () => wrapper.find('#mcp-server-homepage-url');
  const findTransportSelect = () => wrapper.find('#mcp-server-transport');
  const findAuthTypeSelect = () => wrapper.find('#mcp-server-auth-type');
  const findOAuthClientIdInput = () => wrapper.find('#mcp-server-oauth-client-id');
  const findOAuthClientSecretInput = () => wrapper.find('#mcp-server-oauth-client-secret');
  const findSubmitButton = () => wrapper.findComponent(GlButton);

  const defaultProps = {
    isLoading: false,
    errors: [],
  };

  const initialValues = {
    name: 'Test Server',
    description: 'Test description',
    url: 'https://example.com/mcp',
    homepageUrl: 'https://example.com',
    authType: 'OAUTH',
    oauthClientId: 'client-id',
    oauthClientSecret: 'client-secret',
  };

  const createComponent = (props = {}, routeParams = {}) => {
    wrapper = shallowMountExtended(AiCatalogMcpServerForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $route: { params: routeParams },
      },
      stubs: {
        GlForm,
        FormGroup: {
          props: ['field', 'fieldValue'],
          template: '<div><slot :state="true" :blur="() => {}"></slot></div>',
          methods: {
            validate() {
              // Return false if field value is empty
              return Boolean(this.fieldValue);
            },
          },
        },
      },
    });
  };

  describe('when creating a new MCP server', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form with correct attributes', () => {
      expect(findSubmitButton().text()).toBe('Create MCP server');
      expect(findTransportSelect().attributes('disabled')).toBeDefined();
      expect(findNameInput().attributes('placeholder')).toBe('Atlassian, Google Cloud');
      expect(findDescriptionTextarea().attributes('placeholder')).toBe(
        'This MCP server has tools for finding, creating, and updating objects in...',
      );
      expect(findUrlInput().attributes('type')).toBe('url');
      expect(findHomepageUrlInput().attributes('type')).toBe('url');
      expect(findSubmitButton().classes()).toContain('js-no-auto-disable');
    });
  });

  describe('when auth type is OAuth', () => {
    beforeEach(() => {
      createComponent({
        initialValues: { ...initialValues, authType: 'OAUTH' },
      });
    });

    it('renders OAuth fields', () => {
      expect(findOAuthClientIdInput().exists()).toBe(true);
      expect(findOAuthClientSecretInput().exists()).toBe(true);
    });
  });

  describe('when auth type is NO_AUTH', () => {
    beforeEach(() => {
      createComponent({
        initialValues: { ...initialValues, authType: 'NO_AUTH' },
      });
    });

    it('does not render OAuth fields', () => {
      expect(findOAuthClientIdInput().exists()).toBe(false);
      expect(findOAuthClientSecretInput().exists()).toBe(false);
    });
  });

  describe('form submission', () => {
    beforeEach(() => {
      createComponent({ initialValues });
    });

    it('emits submit event with form data', async () => {
      await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toMatchObject({
        name: initialValues.name,
        description: initialValues.description,
        url: initialValues.url,
        homepageUrl: initialValues.homepageUrl,
        transport: 'HTTP',
        authType: initialValues.authType,
      });
    });
  });

  describe('error handling', () => {
    const errors = ['Error 1', 'Error 2'];

    beforeEach(() => {
      createComponent({ errors });
    });

    it('renders error alert with errors', () => {
      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().props('errors')).toEqual(errors);
    });

    it('emits dismiss-errors event when alert is dismissed', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({ isLoading: true, initialValues });
    });

    it('disables all inputs when loading', () => {
      expect(findNameInput().attributes('disabled')).toBeDefined();
      expect(findDescriptionTextarea().attributes('disabled')).toBeDefined();
      expect(findUrlInput().attributes('disabled')).toBeDefined();
      expect(findHomepageUrlInput().attributes('disabled')).toBeDefined();
      expect(findAuthTypeSelect().attributes('disabled')).toBeDefined();
    });

    it('shows loading state on submit button', () => {
      expect(findSubmitButton().props('loading')).toBe(true);
    });
  });

  describe('validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not emit submit when name is empty', async () => {
      await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('does not emit submit when url is empty', async () => {
      wrapper.vm.formData.name = 'Test Server';
      await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('emits submit when all required fields are filled', async () => {
      createComponent({
        initialValues: { name: 'Test Server', url: 'https://example.com' },
      });

      await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      expect(wrapper.emitted('submit')).toHaveLength(1);
    });
  });

  describe('input trimming', () => {
    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const formValuesWithRandomSpaces = {
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
        url: addRandomSpacesToString(initialValues.url),
        homepageUrl: addRandomSpacesToString(initialValues.homepageUrl),
        oauthClientId: addRandomSpacesToString(initialValues.oauthClientId),
        oauthClientSecret: addRandomSpacesToString(initialValues.oauthClientSecret),
        authType: initialValues.authType,
      };

      createComponent({ initialValues: formValuesWithRandomSpaces });

      await findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      const expectedValues = {
        name: initialValues.name,
        description: initialValues.description,
        url: initialValues.url,
        homepageUrl: initialValues.homepageUrl,
        transport: 'HTTP',
        authType: initialValues.authType,
        oauthClientId: initialValues.oauthClientId,
        oauthClientSecret: initialValues.oauthClientSecret,
      };

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toMatchObject(expectedValues);
    });
  });
});
