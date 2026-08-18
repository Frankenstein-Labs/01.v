import { GlAlert, GlFormInput } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { MountingPortal } from 'portal-vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import NewReleasePanel from 'ee/cd/components/new_release_panel.vue';
import ServicesSelector from 'ee/cd/components/services_selector.vue';
import cdVersionSetCreateMutation from 'ee/cd/graphql/cd_version_set_create.mutation.graphql';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';

Vue.use(VueApollo);

describe('NewReleasePanel', () => {
  let wrapper;
  let createReleaseHandler;

  const applicationId = '1';
  const applicationGid = 'gid://gitlab/Cd::Application/1';

  const createSuccess = {
    data: {
      cdVersionSetCreate: {
        versionSet: {
          id: 'gid://gitlab/Cd::VersionSet/1',
          name: 'May release',
          versionSetEntries: { nodes: [] },
        },
        errors: [],
      },
    },
  };

  const findMountingPortal = () => wrapper.findComponent(MountingPortal);
  const findDynamicPanel = () => wrapper.findComponent(DynamicPanel);
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findCreateButton = () => wrapper.findComponentByTestId('create-button');
  const findNameField = () => wrapper.findComponentByTestId('name-field');
  const findNameInput = () => findNameField().findComponent(GlFormInput);
  const findDescriptionField = () => wrapper.findComponentByTestId('description-field');
  const findDescriptionInput = () => findDescriptionField().findComponent(GlFormInput);
  const findServicesSelector = () => wrapper.findComponent(ServicesSelector);
  const findServicesField = () => wrapper.findComponentByTestId('services-field');
  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  const selectedVersions = [
    {
      serviceId: 'gid://gitlab/Cd::Service/1',
      sourceId: 'gid://gitlab/Cd::ArtifactSource/1',
      versionId: 'gid://gitlab/Cd::Version/2',
    },
    {
      serviceId: 'gid://gitlab/Cd::Service/2',
      sourceId: 'gid://gitlab/Cd::ArtifactSource/2',
      versionId: 'gid://gitlab/Cd::Version/3',
    },
  ];

  const setName = async (name) => {
    findNameInput().vm.$emit('input', name);
    await nextTick();
  };

  const setDescription = async (description) => {
    findDescriptionInput().vm.$emit('input', description);
    await nextTick();
  };

  const selectVersions = async () => {
    findServicesSelector().vm.$emit('change', selectedVersions);
    await nextTick();
  };

  const createComponent = ({ handler = createReleaseHandler } = {}) => {
    wrapper = shallowMountExtended(NewReleasePanel, {
      propsData: {
        applicationId,
      },
      apolloProvider: createMockApollo([[cdVersionSetCreateMutation, handler]]),
      stubs: {
        DynamicPanel,
        MountingPortal: stubComponent(MountingPortal, { name: 'MountingPortal' }),
      },
    });
  };

  beforeEach(() => {
    createReleaseHandler = jest.fn().mockResolvedValue(createSuccess);
  });

  describe('when rendered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders into the contextual panel portal', () => {
      expect(findMountingPortal().attributes()).toMatchObject({
        'mount-to': '#contextual-panel-portal',
      });
    });

    it('renders the panel', () => {
      expect(findDynamicPanel().exists()).toBe(true);
    });

    it('renders the header text', () => {
      expect(wrapper.text()).toContain('Release');
      expect(wrapper.text()).toContain('Create release');
    });

    it('renders the explanatory text', () => {
      expect(wrapper.text()).toContain('Pick a version for each service');
    });

    describe('when the dynamic panel emits close', () => {
      beforeEach(() => {
        findDynamicPanel().vm.$emit('close');
      });

      it('emits close', () => {
        expect(wrapper.emitted('close')).toHaveLength(1);
      });
    });

    describe('when the Cancel button is clicked', () => {
      beforeEach(() => {
        findCancelButton().vm.$emit('click');
      });

      it('emits close', () => {
        expect(wrapper.emitted('close')).toHaveLength(1);
      });
    });

    describe('services selector', () => {
      it('passes the application id to the services selector', () => {
        expect(findServicesSelector().props('applicationId')).toBe(applicationGid);
      });

      it('shows no additional text on the services field while nothing has changed', () => {
        expect(findServicesField().props('additionalText')).toBe('');
      });

      it('reflects the changed count in the services field label', async () => {
        findServicesSelector().vm.$emit('changed-count', 2);
        await nextTick();

        expect(findServicesField().props('additionalText')).toBe('2 changed');
      });
    });

    describe('name field', () => {
      it('renders with the correct label', () => {
        expect(findNameField().props('label')).toBe('Version');
      });

      describe('when the name is within 255 characters', () => {
        beforeEach(async () => {
          await setName('a'.repeat(255));
        });

        it('stays valid', () => {
          expect(findNameField().props('state')).toBe(null);
        });
      });

      describe('when the name exceeds 255 characters', () => {
        beforeEach(async () => {
          await setName('a'.repeat(256));
        });

        it('marks the field as invalid', () => {
          expect(findNameField().props('state')).toBe(false);
          expect(findNameField().props('invalidFeedback')).toBe(
            'Version name cannot exceed 255 characters.',
          );
        });
      });
    });

    describe('description field', () => {
      it('renders the description field with the correct label', () => {
        expect(findDescriptionField().props('label')).toBe('Description');
      });

      it('is in a neutral state by default', () => {
        expect(findDescriptionField().props('state')).toBe(null);
      });

      describe('when the description is within 255 characters', () => {
        beforeEach(async () => {
          findDescriptionInput().vm.$emit('input', 'a'.repeat(255));
          await nextTick();
        });

        it('stays in a neutral state', () => {
          expect(findDescriptionField().props('state')).toBe(null);
        });
      });

      describe('when the description exceeds 255 characters', () => {
        beforeEach(async () => {
          findDescriptionInput().vm.$emit('input', 'a'.repeat(256));
          await nextTick();
        });

        it('marks the field as invalid', () => {
          expect(findDescriptionField().props('state')).toBe(false);
          expect(findDescriptionInput().props('state')).toBe(false);
          expect(findDescriptionField().props('invalidFeedback')).toBe(
            'Description cannot exceed 255 characters.',
          );
        });
      });
    });

    describe('create release', () => {
      it('enables the create button only with a name and at least one selected version', async () => {
        expect(findCreateButton().props('disabled')).toBe(true);

        await setName('v1_0_0');
        expect(findCreateButton().props('disabled')).toBe(true);

        await selectVersions();
        expect(findCreateButton().props('disabled')).toBe(false);
      });

      it('keeps the create button disabled when the description is invalid', async () => {
        await setName('v1_0_0');
        await selectVersions();
        expect(findCreateButton().props('disabled')).toBe(false);

        await setDescription('a'.repeat(256));
        expect(findCreateButton().props('disabled')).toBe(true);
      });

      describe('when a valid name is submitted', () => {
        beforeEach(async () => {
          await setName('v1_0_0');
          await setDescription('May production release');
          await selectVersions();
          findCreateButton().vm.$emit('click');
          await waitForPromises();
        });

        it('creates the version set with the name, description, and selected version ids', () => {
          expect(createReleaseHandler).toHaveBeenCalledWith({
            input: {
              applicationId: applicationGid,
              name: 'v1_0_0',
              description: 'May production release',
              versionIds: ['gid://gitlab/Cd::Version/2', 'gid://gitlab/Cd::Version/3'],
            },
          });
        });

        it('emits created with the new release id', () => {
          expect(wrapper.emitted('created')).toHaveLength(1);
          expect(wrapper.emitted('created')[0][0]).toBe('gid://gitlab/Cd::VersionSet/1');
        });
      });

      describe('when the mutation returns errors', () => {
        beforeEach(async () => {
          createComponent({
            handler: jest.fn().mockResolvedValue({
              data: {
                cdVersionSetCreate: { versionSet: null, errors: ['Name has already been taken'] },
              },
            }),
          });
          await setName('v1_0_0');
          await selectVersions();
          findCreateButton().vm.$emit('click');
          await waitForPromises();
        });

        it('shows the error in an in-panel alert', () => {
          expect(findErrorAlert().text()).toBe('Name has already been taken');
        });

        it('stays open', () => {
          expect(wrapper.emitted('close')).toBeUndefined();
        });
      });

      describe('when the mutation request fails', () => {
        beforeEach(async () => {
          createComponent({ handler: jest.fn().mockRejectedValue(new Error('network error')) });
          await setName('v1_0_0');
          await selectVersions();
          findCreateButton().vm.$emit('click');
          await waitForPromises();
        });

        it('shows an in-panel alert', () => {
          expect(findErrorAlert().exists()).toBe(true);
        });

        it('stays open', () => {
          expect(wrapper.emitted('close')).toBeUndefined();
        });
      });
    });
  });
});
