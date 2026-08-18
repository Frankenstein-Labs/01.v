import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { GlFormCheckbox, GlFormInput, GlFormTextarea, GlModal, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import SecretForm from 'ee/ci/secrets/components/secret_form/secret_form.vue';
import createRouter from 'ee/ci/secrets/router';
import SecretBranchesField from 'ee/ci/secrets/components/secret_form/secret_branches_field.vue';
import getProjectBranches from 'ee/ci/secrets/graphql/queries/get_project_branches.query.graphql';
import { DETAILS_ROUTE_NAME, ENTITY_PROJECT, ENTITY_GROUP } from 'ee/ci/secrets/constants';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from 'ee/ci/secrets/context_config';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import {
  mockProjectBranches,
  mockProjectCreateSecret,
  mockGroupCreateSecret,
  mockProjectUpdateSecret,
  mockGroupUpdateSecret,
} from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);
Vue.use(VueRouter);

describe('SecretForm component', () => {
  let wrapper;
  let mockApollo;
  let mockCreateSecretResponse;
  let mockUpdateSecretResponse;
  let mockProjectBranchesResponse;
  const router = createRouter('/', {});

  const defaultProps = {
    areEnvironmentsLoading: false,
    environments: ['production', 'development'],
    isEditing: false,
    submitButtonText: 'Add secret',
  };

  const findConfirmEditModal = () => wrapper.findComponent(GlModal);
  const findBranchFieldGroup = () => wrapper.findByTestId('secret-branches');
  const findBranchField = () => wrapper.findComponent(SecretBranchesField);
  const findDescriptionField = () => wrapper.findComponentByTestId('secret-description');
  const findDescriptionFieldGroup = () => wrapper.findByTestId('secret-description-field-group');
  const findEnvironmentsDropdownGroup = () => wrapper.findByTestId('secret-environments');
  const findEnvironmentsDropdown = () => wrapper.findComponent(CiEnvironmentsDropdown);
  const findNameFieldGroup = () => wrapper.findByTestId('secret-name-field-group');
  const findNameField = () => findNameFieldGroup().findComponent(GlFormInput);
  const findProtectedBranchesCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findRotationFieldGroup = () => wrapper.findByTestId('secret-rotation-field-group');
  const findRotationField = () => findRotationFieldGroup().findComponent(GlFormInput);
  const findValueFieldGroup = () => wrapper.findByTestId('secret-value-field-group');
  const findValueField = () => findValueFieldGroup().findComponent(GlFormTextarea);
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-form-button');

  const createComponent = ({
    context = ENTITY_PROJECT,
    props,
    provide,
    mountFn = shallowMountExtended,
    stubs,
  } = {}) => {
    const contextConfig = SECRETS_MANAGER_CONTEXT_CONFIG[context];
    const handlers = [
      [contextConfig.createSecret.mutation, mockCreateSecretResponse],
      [contextConfig.updateSecret.mutation, mockUpdateSecretResponse],
      [getProjectBranches, mockProjectBranchesResponse],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = mountFn(SecretForm, {
      router,
      apolloProvider: mockApollo,
      provide: {
        contextConfig,
        fullPath: 'path/to/entity',
        isReadOnly: false,
        ...provide,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
        ...stubs,
      },
    });
  };

  const inputRequiredFields = async (context = ENTITY_PROJECT) => {
    findNameField().vm.$emit('input', 'SECRET_KEY');
    findValueField().vm.$emit('input', 'SECRET_VALUE');
    findDescriptionField().vm.$emit('input', 'This is a secret');
    findEnvironmentsDropdown().vm.$emit('select-environment', '*');

    if (context === ENTITY_PROJECT) {
      findBranchField().vm.$emit('select-branch', 'main');
    } else {
      findProtectedBranchesCheckbox().vm.$emit('input', true);
    }

    await nextTick();
  };

  beforeEach(() => {
    mockCreateSecretResponse = jest.fn();
    mockUpdateSecretResponse = jest.fn();
    mockProjectBranchesResponse = jest.fn().mockResolvedValue(mockProjectBranches);
  });

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('template', () => {
    it('renders branch field but not protected branches checkbox for project context', () => {
      createComponent({ context: ENTITY_PROJECT });

      expect(findBranchField().exists()).toBe(true);
      expect(findProtectedBranchesCheckbox().exists()).toBe(false);
    });

    it('renders protected branches checkbox but not branch field for group context', () => {
      createComponent({ context: ENTITY_GROUP });

      expect(findProtectedBranchesCheckbox().exists()).toBe(true);
      expect(findBranchField().exists()).toBe(false);
    });

    it('does not show the confirmation modal', () => {
      createComponent();

      expect(findConfirmEditModal().props('visible')).toBe(false);
    });
  });

  describe('environment dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { CiEnvironmentsDropdown } });
    });

    it('sets the environment', async () => {
      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('');

      findEnvironmentsDropdown().vm.$emit('select-environment', 'staging');
      await nextTick();

      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('staging');
    });

    it('bubbles up the search event', async () => {
      findEnvironmentsDropdown().vm.$emit('search-environment-scope', 'dev');
      await nextTick();

      expect(wrapper.emitted('search-environment')).toEqual([['dev']]);
    });
  });

  describe('branch dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { SecretBranchesField } });
    });

    it('sets the branch', async () => {
      expect(findBranchField().props('selectedBranch')).toBe('');

      findBranchField().vm.$emit('select-branch', 'main');
      await nextTick();

      expect(findBranchField().props('selectedBranch')).toBe('main');
    });
  });

  describe('form validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates name field', async () => {
      expect(findNameField().attributes('state')).toBe('true');

      findNameField().vm.$emit('input', '');
      await nextTick();

      expect(findNameField().attributes('state')).toBeUndefined();
      expect(findNameFieldGroup().attributes('invalid-feedback')).toBe('This field is required.');

      findNameField().vm.$emit('input', 'SECRET_KEY');
      await nextTick();

      expect(findNameField().attributes('state')).toBe('true');
    });

    it('validates value field', async () => {
      expect(findValueField().attributes('state')).toBe('true');

      findValueField().vm.$emit('input', '');
      await nextTick();

      expect(findValueField().attributes('state')).toBeUndefined();
      expect(findValueFieldGroup().attributes('invalid-feedback')).toBe('This field is required.');

      findValueField().vm.$emit('input', 'SECRET_VALUE');
      await nextTick();

      expect(findValueField().attributes('state')).toBe('true');
    });

    it('validates description field', async () => {
      expect(findDescriptionField().attributes('state')).toBe('true');

      // string must be <= SECRET_DESCRIPTION_MAX_LENGTH (200) characters
      findDescriptionField().vm.$emit(
        'input',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
      );
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBeUndefined();
      expect(findDescriptionFieldGroup().attributes('invalid-feedback')).toBe(
        'This field is required and must be 200 characters or less.',
      );

      findDescriptionField().vm.$emit('input', 'This is a short description of the secret.');
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBe('true');

      // description cannot be empty
      findDescriptionField().vm.$emit('input', '');
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBeUndefined();
    });

    it('validates rotation field', async () => {
      // value must be an integer
      findRotationField().vm.$emit('input', 'four');
      await nextTick();

      expect(findRotationField().attributes('state')).toBeUndefined();
      expect(findRotationFieldGroup().attributes('invalid-feedback')).toBe(
        'This field must be a number greater than or equal to 7.',
      );

      // value cannot be < 7
      findRotationField().vm.$emit('input', '4');
      await nextTick();

      expect(findRotationField().attributes('state')).toBeUndefined();
      expect(findRotationFieldGroup().attributes('invalid-feedback')).toBe(
        'This field must be a number greater than or equal to 7.',
      );

      // value must be integer >= 7 or empty
      findRotationField().vm.$emit('input', '');
      await nextTick();

      expect(findRotationField().attributes('state')).toBe('true');

      findRotationField().vm.$emit('input', '7');
      await nextTick();

      expect(findRotationField().attributes('state')).toBe('true');
    });

    const PROJECT_REQUIRED_FIELDS = [
      {
        field: findNameField,
        fieldGroup: findNameFieldGroup,
        feedback: 'This field is required.',
      },
      {
        field: findValueField,
        fieldGroup: findValueFieldGroup,
        feedback: 'This field is required.',
      },
      {
        field: findDescriptionField,
        fieldGroup: findDescriptionFieldGroup,
        feedback: 'This field is required and must be 200 characters or less.',
      },
      {
        field: findEnvironmentsDropdown,
        fieldGroup: findEnvironmentsDropdownGroup,
        feedback: 'This field is required.',
      },
      {
        field: findBranchField,
        fieldGroup: findBranchFieldGroup,
        feedback: 'This field is required.',
      },
    ];

    const GROUP_REQUIRED_FIELDS = [
      {
        field: findNameField,
        fieldGroup: findNameFieldGroup,
        feedback: 'This field is required.',
      },
      {
        field: findValueField,
        fieldGroup: findValueFieldGroup,
        feedback: 'This field is required.',
      },
      {
        field: findDescriptionField,
        fieldGroup: findDescriptionFieldGroup,
        feedback: 'This field is required and must be 200 characters or less.',
      },
      {
        field: findEnvironmentsDropdown,
        fieldGroup: findEnvironmentsDropdownGroup,
        feedback: 'This field is required.',
      },
    ];

    const PROJECT_NAME_HELP_TEXT =
      "The name should be unique within this project and can contain only letters, digits, and '_'.";
    const GROUP_NAME_HELP_TEXT =
      "The name should be unique within this group and can contain only letters, digits, and '_'.";

    describe.each`
      context           | requiredFields             | nameHelpText
      ${ENTITY_PROJECT} | ${PROJECT_REQUIRED_FIELDS} | ${PROJECT_NAME_HELP_TEXT}
      ${ENTITY_GROUP}   | ${GROUP_REQUIRED_FIELDS}   | ${GROUP_NAME_HELP_TEXT}
    `(
      'validates required fields in $context context',
      ({ context, requiredFields, nameHelpText }) => {
        beforeEach(() => {
          createComponent({ context });
        });

        it('shows validation messages for required fields after submitting empty form', async () => {
          requiredFields.forEach(({ field }) => {
            expect(field().attributes('state')).toBe('true');
          });

          // submit empty form
          findSubmitButton().vm.$emit('click');
          await nextTick();

          requiredFields.forEach(({ field, fieldGroup, feedback }) => {
            expect(field().attributes('state')).toBeUndefined();
            expect(fieldGroup().attributes('invalid-feedback')).toBe(feedback);
          });

          // does not submit the form
          expect(mockCreateSecretResponse).toHaveBeenCalledTimes(0);
        });

        it('removes validation error messages and makes form submittable after validation passes', async () => {
          // submit empty form
          findSubmitButton().vm.$emit('click');
          await nextTick();

          // fields are invalid
          requiredFields.forEach(({ field }) => {
            expect(field().attributes('state')).toBeUndefined();
          });
          expect(mockCreateSecretResponse).toHaveBeenCalledTimes(0);

          inputRequiredFields(context);
          await nextTick();

          // fields are valid again
          requiredFields.forEach(({ field }) => {
            expect(field().attributes('state')).toBe('true');
          });

          // can submit form
          findSubmitButton().vm.$emit('click');

          expect(mockCreateSecretResponse).toHaveBeenCalledTimes(1);
        });

        it('shows help text for name field', () => {
          expect(findNameFieldGroup().attributes('description')).toBe(nameHelpText);
        });
      },
    );
  });

  const createSecret = async (context) => {
    await inputRequiredFields(context);

    findSubmitButton().vm.$emit('click');
  };

  const projectCreateMutationVars = { branch: 'main' };
  const groupCreateMutationVars = { branch: undefined, protected: true };

  describe.each`
    context           | mutationVariables            | mockResponse
    ${ENTITY_PROJECT} | ${projectCreateMutationVars} | ${mockProjectCreateSecret}
    ${ENTITY_GROUP}   | ${groupCreateMutationVars}   | ${mockGroupCreateSecret}
  `('creating a secret in $context context', ({ context, mutationVariables, mockResponse }) => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended, context });
    });

    it('renders the correct text for submit button', () => {
      expect(findSubmitButton().text()).toBe('Add secret');
    });

    it('renders loading icon while submitting', async () => {
      expect(findSubmitButton().props('loading')).toBe(false);

      await createSecret(context);
      await nextTick();

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    describe('when submission is successful', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(mockResponse());
        createComponent({ mountFn: mountExtended, context });
      });

      it('calls the create mutation with the correct variables', async () => {
        await createSecret(context);
        await waitForPromises();

        expect(mockCreateSecretResponse).toHaveBeenCalledTimes(1);
        expect(mockCreateSecretResponse).toHaveBeenCalledWith({
          branch: '',
          description: 'This is a secret',
          environment: '*',
          name: 'SECRET_KEY',
          fullPath: 'path/to/entity',
          protected: false,
          secret: 'SECRET_VALUE',
          rotationIntervalDays: null,
          ...mutationVariables,
        });
      });

      it('redirects to the secret details page', async () => {
        const routerPushSpy = jest
          .spyOn(router, 'push')
          .mockImplementation(() => Promise.resolve());
        await createSecret(context);
        await waitForPromises();

        expect(routerPushSpy).toHaveBeenCalledWith({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: 'SECRET_KEY' },
        });
      });
    });

    describe('when submission returns errors', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(
          mockResponse({ errors: ['This secret is invalid.'] }),
        );
        createComponent({ mountFn: mountExtended, context });
      });

      it('renders error message from API', async () => {
        await createSecret(context);
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'This secret is invalid.',
          captureError: true,
          error: new Error('This secret is invalid.'),
        });
      });
    });

    describe('when submission fails', () => {
      const error = new Error('GraphQL error: API error');

      beforeEach(() => {
        mockCreateSecretResponse.mockRejectedValue(error);
        createComponent({ mountFn: mountExtended, context });
      });

      it('renders error message from API', async () => {
        await createSecret(context);
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'API error',
          captureError: true,
          error,
        });
      });
    });

    describe('with rotation', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(mockResponse());
        createComponent({ mountFn: mountExtended, context });
      });

      it('calls the create mutation with null rotation when no rotation period is set', async () => {
        await createSecret(context);
        await waitForPromises();

        expect(mockCreateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            rotationIntervalDays: null,
          }),
        );
      });

      it('calls the create mutation with correct rotation period when set to typical value', async () => {
        await inputRequiredFields(context);
        findRotationField().vm.$emit('input', '30');
        await nextTick();

        findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(mockCreateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            rotationIntervalDays: 30,
          }),
        );
      });

      it('calls the create mutation with null rotation when value is set then cleared', async () => {
        await inputRequiredFields(context);
        findRotationField().vm.$emit('input', '30');
        await nextTick();
        findRotationField().vm.$emit('input', '');
        await nextTick();

        findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(mockCreateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            rotationIntervalDays: null,
          }),
        );
      });

      it('calls the create mutation with trimmed rotation period', async () => {
        await inputRequiredFields(context);
        findRotationField().vm.$emit('input', '   30    ');
        await nextTick();

        findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(mockCreateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            rotationIntervalDays: 30,
          }),
        );
      });
    });
  });

  const projectUpdateMutationVars = { branch: 'edit-branch' };
  const groupUpdateMutationVars = { branch: undefined, protected: false };

  const editSecret = async ({ context, finishRequest = true, editValue = true } = {}) => {
    if (editValue) {
      findValueField().vm.$emit('input', 'EDITED_SECRET_VALUE');
    }

    findDescriptionField().vm.$emit('input', 'This is an edited secret');
    findEnvironmentsDropdown().vm.$emit('select-environment', 'edit-env');

    if (context === ENTITY_PROJECT) {
      findBranchField().vm.$emit('select-branch', 'edit-branch');
    } else {
      findProtectedBranchesCheckbox().vm.$emit('input', false);
    }

    await nextTick();

    findSubmitButton().vm.$emit('click');
    await nextTick();

    findConfirmEditModal().vm.$emit('primary', { preventDefault: jest.fn() });

    if (finishRequest) {
      await waitForPromises();
    }
    await nextTick();
  };

  describe.each`
    context           | mutationVariables            | mockResponse
    ${ENTITY_PROJECT} | ${projectUpdateMutationVars} | ${mockProjectUpdateSecret}
    ${ENTITY_GROUP}   | ${groupUpdateMutationVars}   | ${mockGroupUpdateSecret}
  `('editing a secret in $context context', ({ context, mutationVariables, mockResponse }) => {
    beforeEach(async () => {
      createComponent({
        context,
        mountFn: mountExtended,
        props: {
          isEditing: true,
          secretData: {
            description: 'This is a secret',
            environment: 'production',
            name: 'PROD_PWD',
            metadataVersion: 1,
            ...mutationVariables,
          },
        },
      });

      await nextTick();
    });

    it('does not render name field', () => {
      expect(findNameFieldGroup().exists()).toBe(false);
    });

    it('loads fetched secret data', () => {
      expect(findDescriptionField().props('value')).toBe('This is a secret');
      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('production');

      if (context === ENTITY_PROJECT) {
        expect(findBranchField().props('selectedBranch')).toBe('edit-branch');
      } else {
        expect(findProtectedBranchesCheckbox().props('checked')).toBe(false);
      }
    });

    it('allows value field to be empty', async () => {
      expect(findValueFieldGroup().attributes('state')).toBeUndefined();

      findValueField().vm.$emit('input', 'EDITED_SECRET_VALUE');
      await nextTick();

      expect(findValueFieldGroup().attributes('state')).toBeUndefined();

      findValueField().vm.$emit('input', '');
      await nextTick();

      expect(findValueFieldGroup().attributes('state')).toBeUndefined();
    });

    it('renders the correct text for submit button', () => {
      expect(findSubmitButton().text()).toBe('Save changes');
    });

    it('submit button is already enabled', () => {
      expect(findSubmitButton().props('disabled')).toBe(false);
    });

    it('opens confirmation modal when submitting', async () => {
      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmEditModal().text()).toContain(
        'Are you sure you want to update secret PROD_PWD?',
      );
      expect(findConfirmEditModal().props('visible')).toBe(true);
    });

    it.each`
      modalEvent
      ${'canceled'}
      ${'hidden'}
      ${'secondary'}
    `('hides modal when $modalEvent event is triggered', async ({ modalEvent }) => {
      findSubmitButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmEditModal().props('visible')).toBe(true);

      findConfirmEditModal().vm.$emit(modalEvent);
      await nextTick();

      expect(findConfirmEditModal().props('visible')).toBe(false);
    });

    describe('when submitting form', () => {
      it('hides confirmation modal', async () => {
        await editSecret({ context });

        expect(findConfirmEditModal().props('visible')).toBe(false);
      });

      it('renders loading icon while submitting', async () => {
        await editSecret({ context, finishRequest: false });

        expect(findSubmitButton().props('loading')).toBe(true);
      });
    });

    describe('when update is successful', () => {
      beforeEach(() => {
        mockUpdateSecretResponse.mockResolvedValue(
          mockResponse({
            description: 'This is an edited secret',
            environment: 'edit-env',
            name: 'PROD_PWD',
            secret: 'EDITED_SECRET_VALUE',
            ...mutationVariables,
          }),
        );
      });

      it('calls the update mutation with the correct variables', async () => {
        await editSecret({ context });

        expect(mockUpdateSecretResponse).toHaveBeenCalledTimes(1);
        expect(mockUpdateSecretResponse).toHaveBeenCalledWith({
          branch: '',
          description: 'This is an edited secret',
          environment: 'edit-env',
          metadataVersion: 1,
          name: 'PROD_PWD',
          fullPath: 'path/to/entity',
          rotationIntervalDays: null,
          protected: false,
          secret: 'EDITED_SECRET_VALUE',
          ...mutationVariables,
        });
      });

      it('leaves value blank when it is not edited', async () => {
        await editSecret({ context, editValue: false });

        expect(mockUpdateSecretResponse).toHaveBeenCalledTimes(1);
        expect(mockUpdateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({ secret: undefined }),
        );
      });

      it('triggers toast message', async () => {
        await editSecret({ context });

        expect(wrapper.emitted('show-secrets-toast')).toEqual([
          ['Secret PROD_PWD was successfully updated.'],
        ]);
      });

      it('redirects to the secret details page', async () => {
        const routerPushSpy = jest
          .spyOn(router, 'push')
          .mockImplementation(() => Promise.resolve());
        await editSecret({ context });

        expect(routerPushSpy).toHaveBeenCalledWith({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: 'PROD_PWD' },
        });
      });
    });

    describe('when update returns errors', () => {
      beforeEach(() => {
        mockUpdateSecretResponse.mockResolvedValue(
          mockResponse({ errors: ['Cannot update secret.'] }),
        );
      });

      it('renders error message from API', async () => {
        await editSecret({ context });

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Cannot update secret.',
          captureError: true,
          error: new Error('Cannot update secret.'),
        });
      });
    });

    describe('when update fails', () => {
      const error = new Error('GraphQL error: API error');

      beforeEach(() => {
        mockUpdateSecretResponse.mockRejectedValue(error);
      });

      it('renders error message', async () => {
        await editSecret({ context });

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'API error',
          captureError: true,
          error,
        });
      });
    });

    describe('with rotation', () => {
      beforeEach(() => {
        mockUpdateSecretResponse.mockResolvedValue(
          mockResponse({
            description: 'This is an edited secret',
            environment: 'edit-env',
            name: 'PROD_PWD',
            secret: 'EDITED_SECRET_VALUE',
            ...mutationVariables,
          }),
        );
      });

      it('calls the update mutation with rotation period when set', async () => {
        findRotationField().vm.$emit('input', '14');
        await nextTick();

        await editSecret({ context });

        expect(mockUpdateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            rotationIntervalDays: 14,
          }),
        );
      });

      it('calls the update mutation with null rotation when no rotation period is set', async () => {
        await editSecret({ context });

        expect(mockUpdateSecretResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            rotationIntervalDays: null,
          }),
        );
      });
    });
  });

  describe('read only mode', () => {
    it('disables shared form fields and submit button', () => {
      createComponent({ context: ENTITY_PROJECT, provide: { isReadOnly: true } });

      expect(findNameField().attributes('disabled')).toBeDefined();
      expect(findValueField().attributes('disabled')).toBeDefined();
      expect(findDescriptionField().attributes('disabled')).toBeDefined();
      expect(findEnvironmentsDropdown().attributes('disabled')).toBeDefined();
      expect(findRotationField().attributes('disabled')).toBeDefined();
      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('disables project-exclusive form fields', () => {
      createComponent({ context: ENTITY_PROJECT, provide: { isReadOnly: true } });

      expect(findBranchField().attributes('disabled')).toBeDefined();
    });

    it('disables group-exclusive form fields', () => {
      createComponent({ context: ENTITY_GROUP, provide: { isReadOnly: true } });

      expect(findProtectedBranchesCheckbox().attributes('disabled')).toBeDefined();
    });
  });
});
