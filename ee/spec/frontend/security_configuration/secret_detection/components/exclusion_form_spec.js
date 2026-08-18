import {
  GlForm,
  GlFormTextarea,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormCheckbox,
  GlAlert,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import projectSecurityExclusionCreateMutation from 'ee/security_configuration/secret_detection/graphql/project_security_exclusion_create.mutation.graphql';
import projectSecurityExclusionUpdatedMutation from 'ee/security_configuration/secret_detection/graphql/project_security_exclusion_update.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ExclusionForm from 'ee/security_configuration/secret_detection/components/exclusion_form.vue';
import {
  EXCLUSION_TYPE_MAP,
  STATUS_TYPES,
  DRAWER_MODES,
} from 'ee/security_configuration/secret_detection/constants';
import { projectSecurityExclusions } from '../mock_data';

Vue.use(VueApollo);

const mockPreventDefault = { preventDefault: jest.fn() };

const [mockExclusion1, mockExclusion2] = projectSecurityExclusions;
const projectFullPath = 'group/project';

const mockExclusion = {
  type: 'PATH',
  value: 'test',
  description: 'description',
  scanner: 'SECRET_PUSH_PROTECTION',
  active: true,
};

const mutateCreate = jest.fn().mockResolvedValue({
  data: {
    projectSecurityExclusionCreate: {
      errors: [],
      securityExclusion: {
        id: 'gid://gitlab/Security::ProjectSecurityExclusion/31',
        ...mockExclusion,
      },
    },
  },
});

const mutateUpdate = jest.fn().mockResolvedValue({
  data: {
    projectSecurityExclusionUpdate: {
      errors: [],
      securityExclusion: {
        id: 'gid://gitlab/Security::ProjectSecurityExclusion/31',
        ...mockExclusion2,
      },
    },
  },
});

describe('ExclusionForm', () => {
  let wrapper;
  let apolloProvider;
  const mockToastShow = jest.fn();

  const createComponent = (options = {}) => {
    const {
      provide = {},
      mutation = projectSecurityExclusionCreateMutation,
      resolver = mutateCreate,
      props = {},
    } = options;

    apolloProvider = createMockApollo([[mutation, resolver]]);

    wrapper = shallowMountExtended(ExclusionForm, {
      apolloProvider,
      provide: {
        projectFullPath,
        ...provide,
      },
      propsData: {
        exclusion: mockExclusion,
        ...props,
      },
      stubs: {
        GlForm,
        GlFormTextarea,
        GlFormGroup,
        GlFormRadioGroup,
        GlFormCheckbox,
        GlAlert,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findForm = () => wrapper.findComponent(GlForm);
  const findTypeRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findContentTextarea = () => wrapper.findAllComponents(GlFormTextarea).at(0);
  const findDescriptionTextarea = () => wrapper.findAllComponents(GlFormTextarea).at(1);
  const findSecretPushProtectionCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findStatusRadioGroup = () => wrapper.findAllComponents(GlFormRadioGroup).at(1);
  const findSubmitButton = () => wrapper.findComponentByTestId('form-submit-button');
  const findCancelButton = () => wrapper.findComponentByTestId('form-cancel-button');

  it('renders the form', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('renders the type radio group with correct options', () => {
    const typeRadioGroup = findTypeRadioGroup();
    expect(typeRadioGroup.exists()).toBe(true);
    expect(typeRadioGroup.props('options')).toEqual(Object.values(EXCLUSION_TYPE_MAP));
  });

  it('renders the content textarea', () => {
    const contentTextarea = findContentTextarea();
    expect(contentTextarea.exists()).toBe(true);
  });

  it('renders the description textarea', () => {
    const descriptionTextarea = findDescriptionTextarea();
    expect(descriptionTextarea.exists()).toBe(true);
  });

  it('renders the secret push protection checkbox', () => {
    const secretPushProtectionCheckbox = findSecretPushProtectionCheckbox();
    expect(secretPushProtectionCheckbox.exists()).toBe(true);
  });

  it('renders the status radio group with correct options', () => {
    const statusRadioGroup = findStatusRadioGroup();
    expect(statusRadioGroup.exists()).toBe(true);
    expect(statusRadioGroup.props('options')).toEqual(STATUS_TYPES);
  });

  it('renders submit and cancel buttons', () => {
    expect(findSubmitButton().exists()).toBe(true);
    expect(findCancelButton().exists()).toBe(true);
  });

  it('emits cancel event when cancel button is clicked', async () => {
    await findCancelButton().vm.$emit('click');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  describe('form submission', () => {
    describe.each`
      mode      | mutation                                   | resolver        | exclusion
      ${'ADD'}  | ${projectSecurityExclusionCreateMutation}  | ${mutateCreate} | ${mockExclusion}
      ${'EDIT'} | ${projectSecurityExclusionUpdatedMutation} | ${mutateUpdate} | ${mockExclusion1}
    `('form submission in $mode mode', ({ mode, mutation, resolver, exclusion }) => {
      beforeEach(() => {
        createComponent({
          mutation,
          resolver,
          props: {
            exclusion,
            mode: mode === 'ADD' ? DRAWER_MODES.ADD : DRAWER_MODES.EDIT,
          },
        });
      });

      it('submits the form with correct data', async () => {
        await findSubmitButton().vm.$emit('click', mockPreventDefault);

        expect(resolver).toHaveBeenCalledWith({
          input: {
            ...(mode === 'ADD' && { projectPath: projectFullPath }),
            ...(mode === 'EDIT' && { id: exclusion.id }),
            type: exclusion.type,
            value: exclusion.value,
            description: exclusion.description,
            scanner: 'SECRET_PUSH_PROTECTION',
            active: exclusion.active,
          },
        });
      });

      it('captures exception in Sentry when unexpected error occurs', async () => {
        jest.spyOn(Sentry, 'captureException');
        const mockErrorResolver = jest.fn().mockRejectedValue(new Error('Unexpected error'));

        createComponent({ resolver: mockErrorResolver });

        await findSubmitButton().vm.$emit('click', mockPreventDefault);
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Unexpected error'));
      });

      it('displays an error message when submission fails', async () => {
        const errorMessage = 'Failed to create exclusion';
        const mockErrorResolver = jest.fn().mockResolvedValue({
          data: {
            projectSecurityExclusionCreate: {
              errors: [errorMessage],
              securityExclusion: null,
            },
          },
        });

        createComponent({ resolver: mockErrorResolver });

        await findSubmitButton().vm.$emit('click', mockPreventDefault);
        await waitForPromises();

        expect(wrapper.findComponent(GlAlert).exists()).toBe(true);
        expect(wrapper.findComponent(GlAlert).text()).toContain(errorMessage);
      });

      it('clears error messages when form is resubmitted', async () => {
        const errorMessage = 'Failed to create exclusion';
        const mockErrorResolver = jest.fn().mockResolvedValue({
          data: {
            projectSecurityExclusionCreate: {
              errors: [errorMessage],
              securityExclusion: null,
            },
          },
        });

        createComponent({ resolver: mockErrorResolver });

        await findSubmitButton().vm.$emit('click', mockPreventDefault);
        await waitForPromises();

        expect(wrapper.findComponent(GlAlert).exists()).toBe(true);

        await findSubmitButton().vm.$emit('click', mockPreventDefault);

        expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
      });
    });
  });
});
