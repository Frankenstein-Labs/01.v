import { GlAlert } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DynamicPanel from '~/vue_shared/components/dynamic_panel.vue';
import { ARTIFACT_SOURCE_TYPE } from 'ee/cd/constants';
import NewApplicationPanel from 'ee/cd/components/new_application_panel.vue';
import PanelFormField from 'ee/cd/components/shared/panel_form_field.vue';
import PanelFormGroup from 'ee/cd/components/shared/panel_form_group.vue';
import cdApplicationCreateMutation from 'ee/cd/graphql/cd_application_create.mutation.graphql';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('NewApplicationPanel', () => {
  let wrapper;

  const organizationId = 'gid://gitlab/Organizations::Organization/1';

  const successResponse = {
    data: {
      cdApplicationCreate: {
        __typename: 'CdApplicationCreatePayload',
        application: {
          __typename: 'CdApplication',
          id: 'gid://gitlab/Cd::Application/2',
          name: 'acme-platform',
          description: 'A new app',
          updatedAt: '2024-02-01T00:00:00Z',
        },
        errors: [],
      },
    },
  };

  const errorResponse = {
    data: {
      cdApplicationCreate: {
        __typename: 'CdApplicationCreatePayload',
        application: null,
        errors: ['Name has already been taken'],
      },
    },
  };

  const defaultMutationHandler = jest.fn().mockResolvedValue(successResponse);

  const findMountingPortal = () => wrapper.findComponent(MountingPortal);
  const findDynamicPanel = () => wrapper.findComponent(DynamicPanel);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPanelFormFields = () => wrapper.findAllComponents(PanelFormField);
  const findNameInput = () => wrapper.findComponent('#application-name');
  const findDescriptionInput = () => wrapper.findComponent('#application-description');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findSubmitButton = () => wrapper.findComponentByTestId('register-button');
  const findAddServiceHeaderButton = () => wrapper.findComponentByTestId('add-service-header');
  const findServiceEmptyState = () => wrapper.findByTestId('service-empty-state');
  const findServicesList = () => wrapper.findByTestId('services-list');
  const findServiceForm = () => wrapper.findByTestId('service-form');
  const findServiceNameInput = () => wrapper.findComponent('#service-name');
  const findServiceDescriptionInput = () => wrapper.findComponent('#service-description');
  const findArtifactNameInput = () => wrapper.findComponent('#artifact-name');
  const findArtifactUrlInput = () => wrapper.findComponent('#artifact-url');
  const findCancelServiceButton = () => wrapper.findComponentByTestId('cancel-service');
  const findAddServiceButton = () => wrapper.findComponentByTestId('add-service');
  const findEditServiceButtons = () => wrapper.findAllComponentsByTestId('edit-service');
  const findRemoveServiceButtons = () => wrapper.findAllComponentsByTestId('remove-service');
  const findAddAnotherServiceButton = () => wrapper.findByTestId('add-another-service');
  const findEmptyServicesError = () => wrapper.findByTestId('empty-services-error');

  const createComponent = ({ open = true, mutationHandler = defaultMutationHandler } = {}) => {
    wrapper = shallowMountExtended(NewApplicationPanel, {
      apolloProvider: createMockApollo([[cdApplicationCreateMutation, mutationHandler]]),
      propsData: {
        open,
        organizationId,
      },
      stubs: {
        DynamicPanel,
        MountingPortal: stubComponent(MountingPortal, { name: 'MountingPortal' }),
        PanelFormGroup,
      },
    });
  };

  describe('when open is false', () => {
    beforeEach(() => {
      createComponent({ open: false });
    });

    it('does not render the panel', () => {
      expect(findMountingPortal().exists()).toBe(false);
    });
  });

  describe('when open is true', () => {
    beforeEach(() => {
      createComponent({ open: true });
    });

    it('renders into the contextual panel portal', () => {
      expect(findMountingPortal().attributes('mount-to')).toBe('#contextual-panel-portal');
    });

    it('renders the panel', () => {
      expect(findDynamicPanel().exists()).toBe(true);
    });

    it('renders the header text', () => {
      expect(wrapper.text()).toContain('Add application');
      expect(wrapper.text()).toContain('Register application');
    });

    it('renders the explanatory text', () => {
      expect(wrapper.text()).toContain(
        'Declare the topology of your application — services, environments, integrations — and Deploy will orchestrate rollouts for it.',
      );
    });

    it('does not render an error alert by default', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('close', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits close when the dynamic panel emits close', () => {
      findDynamicPanel().vm.$emit('close');

      expect(wrapper.emitted('close')).toEqual([[]]);
    });

    it('emits close when the Cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('close')).toEqual([[]]);
    });
  });

  describe('form fields', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the name field with its label and placeholder', () => {
      expect(findPanelFormFields().at(0).props('label')).toBe('Application name');
      expect(findNameInput().attributes('placeholder')).toBe('e.g. acme-platform');
    });

    it('renders the description field with its label and placeholder', () => {
      expect(findPanelFormFields().at(1).props('label')).toBe('Description');
      expect(findDescriptionInput().attributes('placeholder')).toBe('Brief description');
    });
  });

  describe('form submission', () => {
    describe('when the application name is empty', () => {
      beforeEach(() => {
        createComponent();

        findSubmitButton().vm.$emit('click');
      });

      it('does not call the mutation', () => {
        expect(defaultMutationHandler).not.toHaveBeenCalled();
      });

      it('shows the name field as invalid with feedback', () => {
        expect(findPanelFormFields().at(0).props('state')).toBe(false);
        expect(findPanelFormFields().at(0).props('invalidFeedback')).toBe(
          'Application name is required.',
        );
        expect(findNameInput().props('state')).toBe(false);
      });

      it('shows an empty services error', () => {
        expect(findEmptyServicesError().text()).toContain('Add at least one service.');
      });
    });

    describe('on success', () => {
      beforeEach(async () => {
        createComponent();

        findNameInput().vm.$emit('input', 'acme-platform');
        findDescriptionInput().vm.$emit('input', 'A new app');
        await findAddServiceHeaderButton().vm.$emit('click');
        findServiceNameInput().vm.$emit('input', 'api-gateway');
        findServiceDescriptionInput().vm.$emit('input', 'API service');
        findArtifactNameInput().vm.$emit('input', 'api-gateway-image');
        findArtifactUrlInput().vm.$emit('input', 'registry.example.com/api-gateway');
        findAddServiceButton().vm.$emit('click');
        findSubmitButton().vm.$emit('click');
        await waitForPromises();
      });

      it('calls the mutation with the form values, organization id, and services', () => {
        expect(defaultMutationHandler).toHaveBeenCalledWith({
          input: {
            name: 'acme-platform',
            description: 'A new app',
            organizationId,
            services: [
              {
                description: 'API service',
                name: 'api-gateway',
                artifactSources: [
                  {
                    name: 'api-gateway-image',
                    sourceRef: 'registry.example.com/api-gateway',
                    sourceConfig: { name: 'api-gateway-image', type: ARTIFACT_SOURCE_TYPE },
                  },
                ],
              },
            ],
          },
        });
      });

      it('clears the form fields', () => {
        expect(findNameInput().props('value')).toBe('');
        expect(findDescriptionInput().props('value')).toBe('');
      });

      it('emits close', () => {
        expect(wrapper.emitted('close')).toEqual([[]]);
      });

      it('emits create', () => {
        expect(wrapper.emitted('create')).toEqual([[]]);
      });

      it('does not render an error alert', () => {
        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('when the mutation returns errors', () => {
      beforeEach(async () => {
        createComponent({ mutationHandler: jest.fn().mockResolvedValue(errorResponse) });

        findNameInput().vm.$emit('input', 'acme-platform');
        findDescriptionInput().vm.$emit('input', 'A new app');
        await findAddServiceHeaderButton().vm.$emit('click');
        findServiceNameInput().vm.$emit('input', 'api-gateway');
        findServiceDescriptionInput().vm.$emit('input', 'API service');
        findArtifactNameInput().vm.$emit('input', 'api-gateway-image');
        findArtifactUrlInput().vm.$emit('input', 'registry.example.com/api-gateway');
        findAddServiceButton().vm.$emit('click');
        findSubmitButton().vm.$emit('click');
        await waitForPromises();
      });

      it('renders the returned errors in an alert', () => {
        expect(findAlert().text()).toBe('Name has already been taken');
      });

      it('does not clear the form fields', () => {
        expect(findNameInput().props('value')).toBe('acme-platform');
        expect(findDescriptionInput().props('value')).toBe('A new app');
      });

      it('does not emit close', () => {
        expect(wrapper.emitted('close')).toBeUndefined();
      });

      it('does not emit create', () => {
        expect(wrapper.emitted('create')).toBeUndefined();
      });

      it('dismisses the alert when it emits dismiss', async () => {
        await findAlert().vm.$emit('dismiss');

        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('when the mutation throws', () => {
      beforeEach(async () => {
        createComponent({
          mutationHandler: jest.fn().mockRejectedValue(new Error('network error')),
        });

        findNameInput().vm.$emit('input', 'acme-platform');
        findDescriptionInput().vm.$emit('input', 'A new app');
        await findAddServiceHeaderButton().vm.$emit('click');
        findServiceNameInput().vm.$emit('input', 'api-gateway');
        findServiceDescriptionInput().vm.$emit('input', 'API service');
        findArtifactNameInput().vm.$emit('input', 'api-gateway-image');
        findArtifactUrlInput().vm.$emit('input', 'registry.example.com/api-gateway');
        findAddServiceButton().vm.$emit('click');
        findSubmitButton().vm.$emit('click');
        await waitForPromises();
      });

      it('renders the returned errors in an alert', () => {
        expect(findAlert().text()).toBe('An error occurred. Please try again.');
      });

      it('reports the exception to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('network error'));
      });

      it('does not emit close', () => {
        expect(wrapper.emitted('close')).toBeUndefined();
      });

      it('does not emit create', () => {
        expect(wrapper.emitted('create')).toBeUndefined();
      });
    });
  });

  describe('services section', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('default state', () => {
      it('shows the empty state', () => {
        expect(findServiceEmptyState().exists()).toBe(true);
      });

      it('does not show the service list', () => {
        expect(findServicesList().exists()).toBe(false);
      });

      it('does not show the service form', () => {
        expect(findServiceForm().exists()).toBe(false);
      });

      it('shows the "Add another service" button', () => {
        expect(findAddAnotherServiceButton().exists()).toBe(true);
      });

      it('renders the "Add service" header button', () => {
        expect(findAddServiceHeaderButton().exists()).toBe(true);
      });
    });

    describe('when the "Add service" header button is clicked', () => {
      beforeEach(() => {
        findAddServiceHeaderButton().vm.$emit('click');
      });

      it('shows the service form', () => {
        expect(findServiceForm().exists()).toBe(true);
      });

      it('hides the empty state', () => {
        expect(findServiceEmptyState().exists()).toBe(false);
      });

      it('disables the "Add service" header button', () => {
        expect(findAddServiceHeaderButton().props('disabled')).toBe(true);
      });

      it('renders the service name field with its label and placeholder', () => {
        expect(findPanelFormFields().at(2).props('label')).toBe('Service name');
        expect(findServiceNameInput().attributes('placeholder')).toBe('e.g. api-gateway');
      });

      it('renders the service description field with its label and placeholder', () => {
        expect(findPanelFormFields().at(3).props('label')).toBe('Description');
        expect(findServiceDescriptionInput().attributes('placeholder')).toBe('Brief description');
      });

      it('renders the artifact name field with its label and placeholder', () => {
        expect(findPanelFormFields().at(4).props('label')).toBe('Artifact name');
        expect(findArtifactNameInput().attributes('placeholder')).toBe('e.g. api-gateway');
      });

      it('renders the artifact URL field with its label and placeholder', () => {
        expect(findPanelFormFields().at(5).props('label')).toBe('Artifact URL');
        expect(findArtifactUrlInput().attributes('placeholder')).toBe(
          'e.g. registry.example.com/acme/api-gateway',
        );
      });

      describe('when required service fields are empty and "Add service" is clicked', () => {
        beforeEach(() => {
          findAddServiceButton().vm.$emit('click');
        });

        it('does not add the service', () => {
          expect(findServiceForm().exists()).toBe(true);
          expect(findServicesList().exists()).toBe(false);
        });

        it('shows the service name field as invalid with feedback', () => {
          expect(findPanelFormFields().at(2).props('state')).toBe(false);
          expect(findPanelFormFields().at(2).props('invalidFeedback')).toBe(
            'Service name is required.',
          );
          expect(findServiceNameInput().props('state')).toBe(false);
        });

        it('shows the artifact name field as invalid with feedback', () => {
          expect(findPanelFormFields().at(4).props('state')).toBe(false);
          expect(findPanelFormFields().at(4).props('invalidFeedback')).toBe(
            'Artifact name is required.',
          );
          expect(findArtifactNameInput().props('state')).toBe(false);
        });

        it('shows the artifact URL field as invalid with feedback', () => {
          expect(findPanelFormFields().at(5).props('state')).toBe(false);
          expect(findPanelFormFields().at(5).props('invalidFeedback')).toBe(
            'Artifact URL is required.',
          );
          expect(findArtifactUrlInput().props('state')).toBe(false);
        });
      });

      describe('when Cancel is clicked', () => {
        beforeEach(() => {
          // Fill out form then click cancel button
          findServiceNameInput().vm.$emit('input', 'api-gateway');
          findServiceDescriptionInput().vm.$emit('input', 'API service');
          findArtifactNameInput().vm.$emit('input', 'api-gateway-image');
          findArtifactUrlInput().vm.$emit('input', 'registry.example.com/api-gateway');
          findCancelServiceButton().vm.$emit('click');
        });

        it('hides the service form', () => {
          expect(findServiceForm().exists()).toBe(false);
        });

        it('shows the empty state', () => {
          expect(findServiceEmptyState().exists()).toBe(true);
        });

        it('preserves the entered data when the form is reopened', async () => {
          await findAddServiceHeaderButton().vm.$emit('click');

          expect(findServiceNameInput().props('value')).toBe('api-gateway');
          expect(findServiceDescriptionInput().props('value')).toBe('API service');
          expect(findArtifactNameInput().props('value')).toBe('api-gateway-image');
          expect(findArtifactUrlInput().props('value')).toBe('registry.example.com/api-gateway');
        });
      });

      describe('when a service is added', () => {
        beforeEach(() => {
          findServiceNameInput().vm.$emit('input', 'api-gateway');
          findServiceDescriptionInput().vm.$emit('input', 'API service');
          findArtifactNameInput().vm.$emit('input', 'api-gateway-image');
          findArtifactUrlInput().vm.$emit('input', 'registry.example.com/api-gateway');
          findAddServiceButton().vm.$emit('click');
        });

        it('hides the service form', () => {
          expect(findServiceForm().exists()).toBe(false);
        });

        it('shows the service name in the list', () => {
          expect(findServicesList().text()).toContain('api-gateway');
        });

        it('shows the artifact info in the list', () => {
          expect(findServicesList().text()).toContain('api-gateway-image');
          expect(findServicesList().text()).toContain('registry.example.com/api-gateway');
        });

        it('shows the "Add another service" button', () => {
          expect(findAddAnotherServiceButton().exists()).toBe(true);
        });

        it('does not show the empty state', () => {
          expect(findServiceEmptyState().exists()).toBe(false);
        });

        it('"Add service" header button is not disabled', () => {
          expect(findAddServiceHeaderButton().props('disabled')).toBe(false);
        });

        describe('when the "Add another service" button is clicked', () => {
          beforeEach(async () => {
            await findAddAnotherServiceButton().trigger('click');
          });

          it('shows the service form', () => {
            expect(findServiceForm().exists()).toBe(true);
          });
        });

        describe('when "Edit" is clicked on a service', () => {
          beforeEach(() => {
            findEditServiceButtons().at(0).vm.$emit('click');
          });

          it('shows the service form', () => {
            expect(findServiceForm().exists()).toBe(true);
          });

          it('pre-populates the service name, description, and artifact inputs', () => {
            expect(findServiceNameInput().props('value')).toBe('api-gateway');
            expect(findServiceDescriptionInput().props('value')).toBe('API service');
            expect(findArtifactNameInput().props('value')).toBe('api-gateway-image');
            expect(findArtifactUrlInput().props('value')).toBe('registry.example.com/api-gateway');
          });

          it('shows "Save service" as the form button label', () => {
            expect(findAddServiceButton().text()).toBe('Save service');
          });

          describe('when Cancel is clicked', () => {
            beforeEach(() => {
              findCancelServiceButton().vm.$emit('click');
            });

            it('clears the input data when the form is reopened', async () => {
              await findAddServiceHeaderButton().vm.$emit('click');

              expect(findServiceNameInput().props('value')).toBe('');
              expect(findServiceDescriptionInput().props('value')).toBe('');
              expect(findArtifactNameInput().props('value')).toBe('');
              expect(findArtifactUrlInput().props('value')).toBe('');
            });
          });

          describe('when the service is saved', () => {
            beforeEach(() => {
              findServiceNameInput().vm.$emit('input', 'payment-service');
              findArtifactNameInput().vm.$emit('input', 'payment-service-image');
              findArtifactUrlInput().vm.$emit('input', 'registry.example.com/payment-service');
              findAddServiceButton().vm.$emit('click');
            });

            it('updates the service name in the list', () => {
              expect(findServicesList().text()).toContain('payment-service');
            });

            it('does not show the old service name', () => {
              expect(findServicesList().text()).not.toContain('api-gateway');
            });

            it('hides the service form', () => {
              expect(findServiceForm().exists()).toBe(false);
            });

            describe('when "Register application" is clicked to submit the form', () => {
              beforeEach(() => {
                findNameInput().vm.$emit('input', 'acme-platform');
                findSubmitButton().vm.$emit('click');
              });

              it('calls the mutation with the form values, organization id, and services', () => {
                expect(defaultMutationHandler).toHaveBeenCalledWith({
                  input: {
                    name: 'acme-platform',
                    description: '',
                    organizationId,
                    services: [
                      {
                        name: 'payment-service',
                        description: 'API service',
                        artifactSources: [
                          {
                            name: 'payment-service-image',
                            sourceRef: 'registry.example.com/payment-service',
                            sourceConfig: {
                              name: 'payment-service-image',
                              type: ARTIFACT_SOURCE_TYPE,
                            },
                          },
                        ],
                      },
                    ],
                  },
                });
              });

              it('clears the form fields', async () => {
                await findAddServiceHeaderButton().vm.$emit('click');

                expect(findServiceNameInput().props('value')).toBe('');
                expect(findServiceDescriptionInput().props('value')).toBe('');
                expect(findArtifactNameInput().props('value')).toBe('');
                expect(findArtifactUrlInput().props('value')).toBe('');
              });
            });
          });
        });

        describe('when "Remove" is clicked on a service', () => {
          beforeEach(() => {
            findRemoveServiceButtons().at(0).vm.$emit('click');
          });

          it('removes the service from the list', () => {
            expect(findServicesList().exists()).toBe(false);
          });

          it('shows the empty state', () => {
            expect(findServiceEmptyState().exists()).toBe(true);
          });
        });
      });
    });
  });
});
