import { nextTick } from 'vue';
import { GlForm, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import FormProjectDropdown from 'ee/ai/catalog/components/form_project_dropdown.vue';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components/visibility_level_radio_group.vue';
import FormGroup from 'ee/ai/catalog/components/form_group.vue';
import {
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
  DEFAULT_FLOW_YML_STRING,
} from 'ee/ai/catalog/constants';

describe('AiCatalogFlowForm', () => {
  let wrapper;

  const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findProjectDropdown = () => wrapper.findComponent(FormProjectDropdown);
  const findProjectFormGroup = () => wrapper.findComponent({ ref: 'fieldProject' });
  const findVisibilityLevelRadioGroup = () => wrapper.findComponent(VisibilityLevelRadioGroup);
  const findNameField = () => wrapper.findComponentByTestId('flow-form-input-name');
  const findDescriptionField = () =>
    wrapper.findComponentByTestId('flow-form-textarea-description');
  const findSubmitButton = () => wrapper.findComponentByTestId('flow-form-submit-button');
  const findDefinitionField = () => wrapper.findComponentByTestId('flow-form-definition');
  const findPublicVisibilityAlert = () => wrapper.findComponent(GlAlert);
  const findAlertLink = () => wrapper.findComponent(GlLink);

  const submitForm = async () => {
    await findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
  };

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errors: [],
  };
  const routeParams = { id: 1 };
  const initialValues = {
    projectId: 'gid://gitlab/Project/1000000',
    type: 'FLOW',
    name: 'My AI Flow',
    description: 'A helpful AI assistant',
    public: true,
    definition: 'version: "v1"',
    visibility: VISIBILITY_LEVEL_PUBLIC,
  };

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogFlowForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        projectId: '2000000',
        isGlobalNamespace: true,
        ...provide,
      },
      mocks: {
        $route: {
          params: props.mode === 'create' ? {} : routeParams,
        },
      },
      stubs: {
        GlForm,
        FormGroup,
        GlSprintf,
      },
    });
  };

  describe('Initial Rendering', () => {
    it('renders the form with the correct initial values when props are provided', () => {
      createWrapper({ props: { initialValues } });

      expect(findProjectDropdown().props('value')).toBe(initialValues.projectId);
      expect(findNameField().props('value')).toBe(initialValues.name);
      expect(findDescriptionField().props('value')).toBe(initialValues.description);
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PUBLIC);
      expect(findDefinitionField().props('value')).toBe(initialValues.definition);
    });

    describe('when aiCatalogInternalVisibility is enabled', () => {
      it('initializes visibilityLevel from the visibility field', () => {
        createWrapper({
          props: {
            initialValues: {
              ...initialValues,
              public: false,
              visibility: VISIBILITY_LEVEL_RESTRICTED,
            },
          },
          provide: { glFeatures: { aiCatalogInternalVisibility: true } },
        });

        expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_RESTRICTED);
      });
    });

    it('renders the form with default values when no props are provided and form is not global', () => {
      createWrapper({ provide: { isGlobalNamespace: false } });

      expect(findProjectDropdown().exists()).toBe(false);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
      expect(findDefinitionField().props('value')).toBe(DEFAULT_FLOW_YML_STRING);
    });

    it('renders the form with default values when no props are provided and form is global', () => {
      createWrapper();

      expect(findProjectDropdown().props('value')).toBe(null);
      expect(findNameField().props('value')).toBe('');
      expect(findDescriptionField().props('value')).toBe('');
      expect(findVisibilityLevelRadioGroup().props('value')).toBe(VISIBILITY_LEVEL_PRIVATE);
      expect(findDefinitionField().props('value')).toBe(DEFAULT_FLOW_YML_STRING);
    });

    describe('when in edit mode', () => {
      beforeEach(() => {
        createWrapper({ props: { mode: 'edit' } });
      });

      it('renders project dropdown as disabled when in edit mode', () => {
        expect(findProjectDropdown().props('disabled')).toBe(true);
      });
    });
  });

  describe('Loading Prop', () => {
    it('shows button with loading icon when the loading property is true', () => {
      createWrapper({ props: { isLoading: true } });

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('does not show the button with loading icon when the loading property is false', () => {
      createWrapper({ props: { isLoading: false } });

      expect(findSubmitButton().props('loading')).toBe(false);
    });
  });

  describe('Form Submission', () => {
    // With the feature flag off, the form emits the `public` boolean and not `visibility`.
    const expectedValues = {
      projectId: 'gid://gitlab/Project/1000000',
      name: 'My AI Flow',
      description: 'A helpful AI assistant',
      public: true,
      definition: 'version: "v1"',
    };

    it('emits form values when user clicks submit', async () => {
      createWrapper({ props: { initialValues } });

      await submitForm();

      expect(wrapper.emitted('submit')).toEqual([[expectedValues]]);
    });

    it('trims the form values before emitting them', async () => {
      const addRandomSpacesToString = (value) => `  ${value}  `;

      const initialValuesWithRandomSpaces = {
        ...initialValues,
        name: addRandomSpacesToString(initialValues.name),
        description: addRandomSpacesToString(initialValues.description),
        definition: addRandomSpacesToString(initialValues.definition),
      };

      createWrapper({ props: { initialValues: initialValuesWithRandomSpaces } });

      await submitForm();

      expect(wrapper.emitted('submit')).toEqual([[expectedValues]]);
    });

    describe('when aiCatalogInternalVisibility is enabled', () => {
      it('emits the visibility level instead of the public flag', async () => {
        createWrapper({
          props: { initialValues },
          provide: { glFeatures: { aiCatalogInternalVisibility: true } },
        });

        await submitForm();

        const { public: unusedPublic, ...expectedValuesWithoutPublic } = expectedValues;
        expect(wrapper.emitted('submit')).toEqual([
          [{ ...expectedValuesWithoutPublic, visibility: VISIBILITY_LEVEL_PUBLIC }],
        ]);
      });

      it('emits RESTRICTED visibility when editing a restricted flow', async () => {
        createWrapper({
          props: {
            mode: 'edit',
            initialValues: {
              ...initialValues,
              public: false,
              visibility: VISIBILITY_LEVEL_RESTRICTED,
            },
          },
          provide: { glFeatures: { aiCatalogInternalVisibility: true } },
        });

        await submitForm();

        const { public: unusedPublic, ...expectedValuesWithoutPublic } = expectedValues;
        expect(wrapper.emitted('submit')).toEqual([
          [
            {
              ...expectedValuesWithoutPublic,
              projectId: undefined,
              visibility: VISIBILITY_LEVEL_RESTRICTED,
            },
          ],
        ]);
      });
    });
  });

  describe('with error messages', () => {
    const mockError = 'The flow could not be created';

    beforeEach(() => {
      createWrapper({ props: { errors: [mockError] } });
    });

    it('passes error alert', () => {
      expect(findErrorAlert().props('errors')).toEqual([mockError]);
    });

    it('renders errors with form errors', async () => {
      const formError = 'Project is required';

      await findProjectDropdown().vm.$emit('error', formError);

      expect(findErrorAlert().props('errors')).toEqual([mockError, formError]);
    });

    it('emits dismiss-errors event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });

  describe('Project field validation', () => {
    beforeEach(() => {
      createWrapper({ isGlobalNamespace: true });
    });

    it('shows validation error when form is submitted and project is not selected', async () => {
      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      expect(findProjectFormGroup().attributes('state')).toBeUndefined();
    });

    it('clears validation error when project is selected', async () => {
      await findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      findProjectDropdown().vm.$emit('input', 'gid://gitlab/Project/123');

      await nextTick(); // formValues.projectId value updates, triggering watcher
      await nextTick(); // formValues.projectId watcher executes
      await nextTick(); // $nextTick callback executes, revalidating project field

      expect(findProjectFormGroup().attributes('state')).toBe('true');
    });
  });

  describe('Public visibility alert', () => {
    describe('when visibility level is private', () => {
      beforeEach(() => {
        createWrapper({ props: { initialValues: { ...initialValues, public: false } } });
      });

      it('does not render alert', () => {
        expect(findPublicVisibilityAlert().exists()).toBe(false);
      });
    });

    describe('when visibility level is public', () => {
      beforeEach(() => {
        createWrapper({ props: { initialValues } });
      });

      it('renders alert', () => {
        expect(findPublicVisibilityAlert().exists()).toBe(true);
      });

      it('renders alert with correct message', () => {
        expect(findPublicVisibilityAlert().text()).toBe(
          "If a public flow is enabled, you can't delete it or make it private. Learn more about flow visibility.",
        );
      });

      it('renders alert with correct link', () => {
        expect(findAlertLink().attributes('href')).toBe(
          '/help/user/duo_agent_platform/flows/custom#flow-visibility',
        );
      });

      it('alert is not dismissible', () => {
        expect(findPublicVisibilityAlert().props('dismissible')).toBe(false);
      });
    });

    describe('when visibility level changes', () => {
      it('shows alert when visibility level changes from private to public', async () => {
        createWrapper({ props: { initialValues: { ...initialValues, public: false } } });

        expect(findPublicVisibilityAlert().exists()).toBe(false);

        findVisibilityLevelRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PUBLIC);
        await nextTick();

        expect(findPublicVisibilityAlert().exists()).toBe(true);
      });

      it('hides alert when visibility level changes from public to private', async () => {
        createWrapper({ props: { initialValues } });

        expect(findPublicVisibilityAlert().exists()).toBe(true);

        findVisibilityLevelRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_PRIVATE);
        await nextTick();

        expect(findPublicVisibilityAlert().exists()).toBe(false);
      });

      it('hides alert when visibility level changes from public to restricted', async () => {
        createWrapper({ props: { initialValues } });

        expect(findPublicVisibilityAlert().exists()).toBe(true);

        findVisibilityLevelRadioGroup().vm.$emit('input', VISIBILITY_LEVEL_RESTRICTED);
        await nextTick();

        expect(findPublicVisibilityAlert().exists()).toBe(false);
      });
    });
  });
});
