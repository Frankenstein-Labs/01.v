import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import updateGroupStreamingDestination from 'ee/audit_events/graphql/mutations/update_group_streaming_destination.mutation.graphql';
import createGroupStreamingDestination from 'ee/audit_events/graphql/mutations/create_group_streaming_destination.mutation.graphql';
import addGroupEventTypeFiltersToDestination from 'ee/audit_events/graphql/mutations/add_group_event_type_filters.mutation.graphql';
import addGroupNamespaceFiltersToDestination from 'ee/audit_events/graphql/mutations/add_group_namespace_filters.mutation.graphql';
import deleteGroupEventTypeFiltersFromDestination from 'ee/audit_events/graphql/mutations/delete_group_event_type_filters.mutation.graphql';
import deleteGroupNamespaceFiltersFromDestination from 'ee/audit_events/graphql/mutations/delete_group_namespace_filters.mutation.graphql';
import updateInstanceStreamingDestination from 'ee/audit_events/graphql/mutations/update_instance_streaming_destination.mutation.graphql';
import createInstanceStreamingDestination from 'ee/audit_events/graphql/mutations/create_instance_streaming_destination.mutation.graphql';
import addInstanceEventTypeFiltersToDestination from 'ee/audit_events/graphql/mutations/add_instance_event_type_filters.mutation.graphql';
import deleteInstanceEventTypeFiltersFromDestination from 'ee/audit_events/graphql/mutations/delete_instance_event_type_filters.mutation.graphql';

import StreamDestinationEditor from 'ee/audit_events/components/stream/stream_destination_editor.vue';
import StreamDestinationEditorHttpFields from 'ee/audit_events/components/stream/stream_destination_editor_http_fields.vue';
import StreamDestinationEditorAwsFields from 'ee/audit_events/components/stream/stream_destination_editor_aws_fields.vue';
import StreamDestinationEditorGcpFields from 'ee/audit_events/components/stream/stream_destination_editor_gcp_fields.vue';
import StreamEventTypeFilters from 'ee/audit_events/components/stream/stream_event_type_filters.vue';
import StreamNamespaceFilters from 'ee/audit_events/components/stream/stream_namespace_filters.vue';
import StreamDeleteModal from 'ee/audit_events/components/stream/stream_delete_modal.vue';
import {
  DESTINATION_TYPE_AMAZON_S3,
  DESTINATION_TYPE_GCP_LOGGING,
} from 'ee/audit_events/constants';
import { newStreamDestination } from '../../mock_data';
import {
  mockHttpTypeDestination,
  mockAwsTypeDestination,
  mockGcpTypeDestination,
  destinationCreateMutationPopulator,
} from '../../mock_data/consolidated_api';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('StreamDestinationEditor', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const propsDefinition = {
    newItem: newStreamDestination,
    httpItem: mockHttpTypeDestination[0],
    awsItem: {
      ...mockAwsTypeDestination[0],
      category: DESTINATION_TYPE_AMAZON_S3,
    },
    gcpItem: {
      ...mockGcpTypeDestination[0],
      category: DESTINATION_TYPE_GCP_LOGGING,
    },
  };

  const apolloMocks = {
    group: {
      createDestination: {
        success: [
          createGroupStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              groupAuditEventStreamingDestinationsCreate: destinationCreateMutationPopulator(),
            },
          }),
        ],
        error: [
          createGroupStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              groupAuditEventStreamingDestinationsCreate: {
                errors: ['mock destination creation error'],
                externalAuditEventDestination: null,
              },
            },
          }),
        ],
      },
      updateDestination: {
        success: [
          updateGroupStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              groupAuditEventStreamingDestinationsUpdate: destinationCreateMutationPopulator(),
            },
          }),
        ],
        error: [
          updateGroupStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              groupAuditEventStreamingDestinationsUpdate: {
                errors: ['mock destination update error'],
                externalAuditEventDestination: null,
              },
            },
          }),
        ],
      },
      createEventTypeFilter: [
        addGroupEventTypeFiltersToDestination,
        jest.fn().mockResolvedValue({
          data: {
            auditEventsGroupDestinationEventsAdd: {
              errors: [],
              eventTypeFilters: ['test_event_type'],
            },
          },
        }),
      ],
      deleteEventTypeFilter: [
        deleteGroupEventTypeFiltersFromDestination,
        jest.fn().mockResolvedValue({
          data: {
            auditEventsGroupDestinationEventsDelete: { errors: [] },
          },
        }),
      ],
      createNamespaceFilter: [
        addGroupNamespaceFiltersToDestination,
        jest.fn().mockResolvedValue({
          data: {
            auditEventsGroupDestinationNamespaceFilterCreate: {
              errors: [],
              namespaceFilter: {
                id: 'namespace-filter-id-1',
                namespace: {
                  id: 'namespace-id-1',
                  fullPath: 'group/namespace-path-1',
                },
              },
            },
          },
        }),
      ],
      deleteNamespaceFilter: [
        deleteGroupNamespaceFiltersFromDestination,
        jest.fn().mockResolvedValue({
          data: {
            auditEventsGroupDestinationNamespaceFilterDelete: { errors: [] },
          },
        }),
      ],
    },
    instance: {
      createDestination: {
        success: [
          createInstanceStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              instanceAuditEventStreamingDestinationsCreate: destinationCreateMutationPopulator(),
            },
          }),
        ],
        error: [
          createInstanceStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              instanceAuditEventStreamingDestinationsCreate: {
                errors: ['mock destination creation error'],
                externalAuditEventDestination: null,
              },
            },
          }),
        ],
      },
      updateDestination: {
        success: [
          updateInstanceStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              instanceAuditEventStreamingDestinationsUpdate: destinationCreateMutationPopulator(),
            },
          }),
        ],
        error: [
          updateInstanceStreamingDestination,
          jest.fn().mockResolvedValue({
            data: {
              instanceAuditEventStreamingDestinationsUpdate: {
                errors: ['mock destination update error'],
                externalAuditEventDestination: null,
              },
            },
          }),
        ],
      },
      createEventTypeFilter: [
        addInstanceEventTypeFiltersToDestination,
        jest.fn().mockResolvedValue({
          data: {
            auditEventsInstanceDestinationEventsAdd: {
              errors: [],
              eventTypeFilters: ['test_event_type'],
            },
          },
        }),
      ],
      deleteEventTypeFilter: [
        deleteInstanceEventTypeFiltersFromDestination,
        jest.fn().mockResolvedValue({
          data: {
            auditEventsInstanceDestinationEventsDelete: { errors: [] },
          },
        }),
      ],
    },
  };

  const createComponent = ({ props = {}, provide = {}, apolloHandlers = [] } = {}) => {
    wrapper = shallowMountExtended(StreamDestinationEditor, {
      propsData: {
        ...props,
      },
      provide: {
        ...provide,
      },
      apolloProvider: createMockApollo([...apolloHandlers]),
    });
  };

  const findDataWarning = () => wrapper.findComponentByTestId('data-warning');
  const findAlertErrors = () => wrapper.findByTestId('alert-errors');
  const findDestinationForm = () => wrapper.findComponentByTestId('destination-form');
  const findDestinationName = () => wrapper.findComponentByTestId('destination-name');
  const findSubmitButton = () => wrapper.findComponentByTestId('stream-destination-submit-button');
  const findCancelButton = () => wrapper.findByTestId('stream-destination-cancel-button');
  const findDeleteButton = () => wrapper.findComponentByTestId('stream-destination-delete-button');

  const findStreamDestinationEditorHttpFields = () =>
    wrapper.findComponent(StreamDestinationEditorHttpFields);
  const findStreamDestinationEditorAwsFields = () =>
    wrapper.findComponent(StreamDestinationEditorAwsFields);
  const findStreamDestinationEditorGcpFields = () =>
    wrapper.findComponent(StreamDestinationEditorGcpFields);
  const findStreamEventTypeFilters = () => wrapper.findComponent(StreamEventTypeFilters);
  const findStreamNamespaceFilters = () => wrapper.findComponent(StreamNamespaceFilters);
  const findStreamDeleteModal = () => wrapper.findComponent(StreamDeleteModal);

  describe.each`
    view
    ${'group'}
    ${'instance'}
  `('when the view is $view', ({ view }) => {
    describe('when creating new destination', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: propsDefinition.newItem,
          },
          provide: { groupPath: view },
        });
      });

      it('shows data warning message', () => {
        expect(findDataWarning().props('title')).toBe('Destinations receive all audit event data');
        expect(findDataWarning().text()).toBe(
          'This could include sensitive information. Make sure you trust the destination endpoint.',
        );
      });

      it('renders the correct submit button text', () => {
        expect(findSubmitButton().attributes('name')).toBe('Add external stream destination');
        expect(findSubmitButton().text()).toBe('Add');
      });

      it('renders cancel button', () => {
        expect(findCancelButton().exists()).toBe(true);
      });

      it('does not render delete button', () => {
        expect(findDeleteButton().exists()).toBe(false);
      });

      it('does not render delete modal', () => {
        expect(findStreamDeleteModal().exists()).toBe(false);
      });
    });

    describe('when editing a destination', () => {
      describe('when destination category is http', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.httpItem },
            provide: { groupPath: view },
          });
        });

        it('renders http fields', () => {
          expect(findDestinationName().attributes('value')).toBe('HTTP Destination 1');
          // The formItem passed to children mirrors `item`, except namespaceFilters is reshaped
          // by getFormattedFormItem. Assert on the stable subset instead of toMatchObject deep
          // (which would diff the reshaped array).
          const httpFieldsProps = findStreamDestinationEditorHttpFields().props();
          expect(httpFieldsProps.isEditing).toBe(true);
          expect(httpFieldsProps.loading).toBe(false);
          expect(httpFieldsProps.value).toEqual(
            expect.objectContaining({
              id: propsDefinition.httpItem.id,
              name: propsDefinition.httpItem.name,
              category: propsDefinition.httpItem.category,
              config: propsDefinition.httpItem.config,
            }),
          );
          expect(findStreamEventTypeFilters().props('value')).toBe(
            propsDefinition.httpItem.eventTypeFilters,
          );
        });

        it('renders the correct submit button text', () => {
          expect(findSubmitButton().attributes('name')).toBe('Save external stream destination');
          expect(findSubmitButton().text()).toBe('Save');
        });

        it('renders cancel button', () => {
          expect(findCancelButton().exists()).toBe(true);
        });

        it('renders delete button disabled', () => {
          expect(findDeleteButton().exists()).toBe(true);
        });

        it('passes correct props to delete modal', () => {
          expect(findStreamDeleteModal().props()).toMatchObject({
            item: propsDefinition.httpItem,
          });
        });
      });

      describe('when destination category is aws', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.awsItem },
            provide: { groupPath: view },
          });
        });

        it('renders aws fields', () => {
          expect(findDestinationName().attributes('value')).toBe('AWS Destination 1');
          expect(findStreamDestinationEditorAwsFields().props()).toMatchObject({
            value: propsDefinition.awsItem,
            isEditing: true,
          });
          expect(findStreamEventTypeFilters().props('value')).toBe(
            propsDefinition.awsItem.eventTypeFilters,
          );
        });

        it('passes correct props to delete modal', () => {
          expect(findStreamDeleteModal().props()).toMatchObject({
            item: propsDefinition.awsItem,
          });
        });
      });

      describe('when destination category is gcp', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.gcpItem },
            provide: { groupPath: view },
          });
        });

        it('renders gcp fields', () => {
          expect(findDestinationName().attributes('value')).toBe('GCP Destination 1');
          expect(findStreamDestinationEditorGcpFields().props()).toMatchObject({
            value: propsDefinition.gcpItem,
            isEditing: true,
          });
          expect(findStreamEventTypeFilters().props('value')).toBe(
            propsDefinition.gcpItem.eventTypeFilters,
          );
        });

        it('passes correct props to delete modal', () => {
          expect(findStreamDeleteModal().props()).toMatchObject({
            item: propsDefinition.gcpItem,
          });
        });
      });
    });

    describe('when creating a destination', () => {
      describe('when destination category is http', () => {
        it('creates a destination successfully', async () => {
          createComponent({
            props: { item: propsDefinition.newItem },
            provide: { groupPath: view },
            apolloHandlers: [
              apolloMocks[view].createDestination.success,
              apolloMocks[view].createEventTypeFilter,
            ],
          });

          const expectedDestinationPayload = {
            name: 'New Dest',
            config: {
              url: 'http://test.url',
              headers: [
                {
                  key: 'header-key-1',
                  value: 'header-value-1',
                  active: true,
                },
              ],
            },
            category: 'http',
            secretToken: undefined,
          };

          if (view !== 'instance') {
            expectedDestinationPayload.groupPath = view;
          }

          await findStreamDestinationEditorHttpFields().vm.$emit('input', {
            ...propsDefinition.newItem,
            config: {
              ...expectedDestinationPayload.config,
            },
            namespaceFilters: [],
          });
          await findStreamEventTypeFilters().vm.$emit('input', ['test_event_type']);
          await findDestinationName().vm.$emit('input', 'New Dest');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].createDestination.success[1]).toHaveBeenCalledWith({
            input: expectedDestinationPayload,
          });

          expect(apolloMocks[view].createEventTypeFilter[1]).toHaveBeenCalledWith({
            destinationId: 'test-create-id',
            eventTypeFilters: ['test_event_type'],
          });
          expect(findAlertErrors().exists()).toBe(false);
          expect(wrapper.emitted('added')).toEqual([[]]);
        });

        it('shows creation error in alert', async () => {
          createComponent({
            props: { item: propsDefinition.newItem },
            provide: { groupPath: view },
            apolloHandlers: [apolloMocks[view].createDestination.error],
          });

          await findStreamDestinationEditorHttpFields().vm.$emit('input', {
            ...propsDefinition.newItem,
            config: {
              url: 'http://test.url',
            },
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', 'New Dest');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors().text()).toBe('mock destination creation error');
          expect(wrapper.emitted('error')).toEqual([[]]);
        });

        it('shows default alert message when network error', async () => {
          const mockError = new Error('Network error');
          const mutationHandler = jest.fn().mockRejectedValue(mockError);

          createComponent({
            props: { item: propsDefinition.newItem },
            provide: { groupPath: view },
            apolloHandlers: [[apolloMocks[view].createDestination.error[0], mutationHandler]],
          });

          await findStreamDestinationEditorHttpFields().vm.$emit('input', {
            ...propsDefinition.newItem,
            config: {
              url: 'http://test.url',
            },
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', 'New Dest');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors().text()).toBe(
            'An error occurred when creating external audit event stream destination. Please try it again.',
          );
          expect(Sentry.captureException).toHaveBeenCalledWith(mockError);
          expect(wrapper.emitted('error')).toEqual([[]]);
        });
      });

      describe('when destination category is aws', () => {
        it('creates a destination successfully', async () => {
          createComponent({
            props: { item: { ...propsDefinition.newItem, category: DESTINATION_TYPE_AMAZON_S3 } },
            provide: { groupPath: view },
            apolloHandlers: [apolloMocks[view].createDestination.success],
          });

          const expectedPayload = {
            name: 'New Dest',
            config: {
              accessKeyXid: 'new-AccessKeyXid',
              awsRegion: 'us-test-2',
              bucketName: 'new-bucket-name',
            },
            category: 'aws',
            secretToken: 'mySecretToken',
          };

          if (view !== 'instance') {
            expectedPayload.groupPath = view;
          }

          await findStreamDestinationEditorAwsFields().vm.$emit('input', {
            ...propsDefinition.newItem,
            config: {
              ...expectedPayload.config,
            },
            category: expectedPayload.category,
            secretToken: expectedPayload.secretToken,
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', 'New Dest');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].createDestination.success[1]).toHaveBeenCalledWith({
            input: expectedPayload,
          });
          expect(findAlertErrors().exists()).toBe(false);
          expect(wrapper.emitted('added')).toEqual([[]]);
        });
      });

      describe('when destination category is gcp', () => {
        it('creates a destination successfully', async () => {
          createComponent({
            props: { item: { ...propsDefinition.newItem, category: DESTINATION_TYPE_GCP_LOGGING } },
            provide: { groupPath: view },
            apolloHandlers: [apolloMocks[view].createDestination.success],
          });

          const expectedPayload = {
            name: 'New Dest',
            config: {
              googleProjectIdName: 'new-google-project-id',
              clientEmail: 'new-email@test.com',
              logIdName: 'new-gcp-log-id',
            },
            category: 'gcp',
            secretToken: 'mySecretToken',
          };

          if (view !== 'instance') {
            expectedPayload.groupPath = view;
          }

          await findStreamDestinationEditorGcpFields().vm.$emit('input', {
            ...propsDefinition.newItem,
            config: {
              ...expectedPayload.config,
            },
            category: expectedPayload.category,
            secretToken: expectedPayload.secretToken,
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', 'New Dest');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].createDestination.success[1]).toHaveBeenCalledWith({
            input: expectedPayload,
          });
          expect(findAlertErrors().exists()).toBe(false);
          expect(wrapper.emitted('added')).toEqual([[]]);
        });
      });
    });

    describe('when updating a destination', () => {
      describe('when destination category is http', () => {
        it('updates a destination successfully', async () => {
          createComponent({
            props: { item: { ...propsDefinition.httpItem, namespaceFilters: [] } },
            provide: { groupPath: view },
            apolloHandlers: [
              apolloMocks[view].updateDestination.success,
              apolloMocks[view].createEventTypeFilter,
              apolloMocks[view].deleteEventTypeFilter,
            ],
          });

          const expectedDestinationPayload = {
            id: propsDefinition.httpItem.id,
            name: 'Updated Destination name',
            secretToken: propsDefinition.httpItem.secretToken,
            config: {
              ...propsDefinition.httpItem.config,
              headers: [
                {
                  key: 'updated-header-key-1',
                  value: 'updated-header-value-1',
                  active: true,
                },
              ],
            },
          };

          await findStreamDestinationEditorHttpFields().vm.$emit('input', {
            ...propsDefinition.httpItem,
            config: {
              ...expectedDestinationPayload.config,
            },
            namespaceFilters: [],
          });
          await findStreamEventTypeFilters().vm.$emit('input', ['test_event_type']);
          await findDestinationName().vm.$emit('input', expectedDestinationPayload.name);

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].updateDestination.success[1]).toHaveBeenCalledWith({
            input: expectedDestinationPayload,
          });

          expect(apolloMocks[view].deleteEventTypeFilter[1]).toHaveBeenCalledWith({
            destinationId: propsDefinition.httpItem.id,
            eventTypeFilters: propsDefinition.httpItem.eventTypeFilters,
          });

          expect(apolloMocks[view].createEventTypeFilter[1]).toHaveBeenCalledWith({
            destinationId: propsDefinition.httpItem.id,
            eventTypeFilters: ['test_event_type'],
          });

          expect(findAlertErrors().exists()).toBe(false);
          expect(wrapper.emitted('updated')).toEqual([[]]);
        });

        it('shows update error in alert', async () => {
          createComponent({
            props: { item: { ...propsDefinition.httpItem, namespaceFilters: [] } },
            provide: { groupPath: view },
            apolloHandlers: [apolloMocks[view].updateDestination.error],
          });

          await findStreamDestinationEditorHttpFields().vm.$emit('input', {
            ...propsDefinition.httpItem,
            config: {
              ...propsDefinition.httpItem.config,
              headers: [],
            },
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', 'Updated Destination Name');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].createEventTypeFilter[1]).not.toHaveBeenCalled();
          expect(apolloMocks[view].deleteEventTypeFilter[1]).not.toHaveBeenCalled();
          expect(findAlertErrors().text()).toBe('mock destination update error');
          expect(wrapper.emitted('error')).toEqual([[]]);
        });

        it('shows default alert message when network error', async () => {
          const mockError = new Error('Network error');
          const mutationHandler = jest.fn().mockRejectedValue(mockError);

          createComponent({
            props: { item: { ...propsDefinition.httpItem, namespaceFilters: [] } },
            provide: { groupPath: view },
            apolloHandlers: [[apolloMocks[view].updateDestination.error[0], mutationHandler]],
          });

          await findStreamDestinationEditorHttpFields().vm.$emit('input', {
            ...propsDefinition.httpItem,
            config: {
              ...propsDefinition.httpItem.config,
              headers: [],
            },
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', 'Updated Destination name');

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(findAlertErrors().text()).toBe(
            'An error occurred when updating external audit event stream destination. Please try it again.',
          );
          expect(Sentry.captureException).toHaveBeenCalledWith(mockError);
          expect(wrapper.emitted('error')).toEqual([[]]);
        });
      });

      describe('when destination category is aws', () => {
        it('updates a destination successfully', async () => {
          createComponent({
            props: { item: { ...propsDefinition.awsItem, namespaceFilters: [] } },
            provide: { groupPath: view },
            apolloHandlers: [apolloMocks[view].updateDestination.success],
          });

          const expectedDestinationPayload = {
            id: propsDefinition.awsItem.id,
            name: 'Updated Destination name',
            secretToken: propsDefinition.awsItem.secretToken,
            config: {
              accessKeyXid: 'updated-AccessKeyXid',
              awsRegion: 'us-new-5',
              bucketName: 'updated-bucket-name',
            },
          };

          await findStreamDestinationEditorAwsFields().vm.$emit('input', {
            ...propsDefinition.awsItem,
            config: {
              ...expectedDestinationPayload.config,
            },
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', expectedDestinationPayload.name);

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].updateDestination.success[1]).toHaveBeenCalledWith({
            input: expectedDestinationPayload,
          });

          expect(findAlertErrors().exists()).toBe(false);
          expect(wrapper.emitted('updated')).toEqual([[]]);
        });
      });

      describe('when destination category is gcp', () => {
        it('updates a destination successfully', async () => {
          createComponent({
            props: { item: { ...propsDefinition.gcpItem, namespaceFilters: [] } },
            provide: { groupPath: view },
            apolloHandlers: [apolloMocks[view].updateDestination.success],
          });

          const expectedDestinationPayload = {
            id: propsDefinition.gcpItem.id,
            name: 'Updated Destination name',
            secretToken: propsDefinition.gcpItem.secretToken,
            config: {
              googleProjectIdName: 'updated-google-project-id',
              clientEmail: 'updated-email@test.com',
              logIdName: 'updated-gcp-log-id',
            },
          };

          await findStreamDestinationEditorGcpFields().vm.$emit('input', {
            ...propsDefinition.gcpItem,
            config: {
              ...expectedDestinationPayload.config,
            },
            namespaceFilters: [],
          });
          await findDestinationName().vm.$emit('input', expectedDestinationPayload.name);

          await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
          await waitForPromises();

          expect(apolloMocks[view].updateDestination.success[1]).toHaveBeenCalledWith({
            input: expectedDestinationPayload,
          });

          expect(findAlertErrors().exists()).toBe(false);
          expect(wrapper.emitted('updated')).toEqual([[]]);
        });
      });
    });

    describe('when deleting a destination', () => {
      beforeEach(() => {
        createComponent({
          props: { item: propsDefinition.httpItem },
          provide: { groupPath: view },
        });
      });

      it('updates loading state when deleting', async () => {
        await findStreamDeleteModal().vm.$emit('deleting');

        expect(findStreamDestinationEditorHttpFields().props('loading')).toBe(true);
        expect(findSubmitButton().props('loading')).toBe(true);
        expect(findDeleteButton().props('loading')).toBe(true);
      });

      it('resets loading state when delete completes', async () => {
        await findStreamDeleteModal().vm.$emit('deleting');
        await findStreamDeleteModal().vm.$emit('delete');

        expect(wrapper.emitted().deleted).toEqual([['mock-streaming-destination-1']]);
        expect(findStreamDestinationEditorHttpFields().props('loading')).toBe(false);
        expect(findSubmitButton().props('loading')).toBe(false);
        expect(findDeleteButton().props('loading')).toBe(false);
      });

      it('displays error alert when delete fails', async () => {
        const error = new Error('test error');
        await findStreamDeleteModal().vm.$emit('error', error);

        expect(findAlertErrors().text()).toBe(
          'An error occurred when deleting external audit event stream destination. Please try it again.',
        );

        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });
  });

  describe('for group specific view', () => {
    describe('when editing a destination', () => {
      describe('when destination category is http', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.httpItem },
            provide: { groupPath: 'group' },
          });
        });

        it('renders namespace filters as an array of {namespace, name} entries', () => {
          expect(findStreamNamespaceFilters().props('value')).toStrictEqual([
            {
              namespace: 'myGroup/project1',
              name: 'project1',
            },
          ]);
        });
      });
    });

    describe('when creating a destination', () => {
      it('adds multiple namespace filters to the destination successfully', async () => {
        createComponent({
          props: { item: { ...propsDefinition.newItem, category: DESTINATION_TYPE_AMAZON_S3 } },
          provide: { groupPath: 'group' },
          apolloHandlers: [
            apolloMocks.group.createDestination.success,
            apolloMocks.group.createNamespaceFilter,
          ],
        });

        const expectedPayload = {
          name: 'New Dest',
          config: {
            accessKeyXid: 'new-AccessKeyXid',
            awsRegion: 'us-test-2',
            bucketName: 'new-bucket-name',
          },
          category: 'aws',
          secretToken: 'mySecretToken',
          groupPath: 'group',
        };

        await findStreamDestinationEditorAwsFields().vm.$emit('input', {
          ...propsDefinition.newItem,
          config: {
            ...expectedPayload.config,
          },
          category: expectedPayload.category,
          secretToken: expectedPayload.secretToken,
          namespaceFilters: [],
        });
        await findDestinationName().vm.$emit('input', 'New Dest');
        await findStreamNamespaceFilters().vm.$emit('input', [
          { namespace: 'myGroup/project1' },
          { namespace: 'myGroup/project2' },
        ]);

        await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(apolloMocks.group.createDestination.success[1]).toHaveBeenCalledWith({
          input: expectedPayload,
        });

        expect(apolloMocks.group.createNamespaceFilter[1]).toHaveBeenCalledTimes(2);
        expect(apolloMocks.group.createNamespaceFilter[1]).toHaveBeenCalledWith({
          destinationId: 'test-create-id',
          namespacePath: 'myGroup/project1',
        });
        expect(apolloMocks.group.createNamespaceFilter[1]).toHaveBeenCalledWith({
          destinationId: 'test-create-id',
          namespacePath: 'myGroup/project2',
        });
        expect(findAlertErrors().exists()).toBe(false);
        expect(wrapper.emitted('added')).toEqual([[]]);
      });
    });

    describe('when updating a destination', () => {
      it('issues adds before removes and dispatches one mutation per delta entry', async () => {
        createComponent({
          props: { item: { ...propsDefinition.httpItem } },
          provide: { groupPath: 'group' },
          apolloHandlers: [
            apolloMocks.group.updateDestination.success,
            apolloMocks.group.deleteNamespaceFilter,
            apolloMocks.group.createNamespaceFilter,
          ],
        });

        const expectedDestinationPayload = {
          id: propsDefinition.httpItem.id,
          name: 'Updated Destination name',
          secretToken: propsDefinition.httpItem.secretToken,
          config: {
            headers: [
              {
                key: 'updated-header-key-1',
                value: 'updated-header-value-1',
                active: true,
              },
            ],
          },
        };

        await findStreamDestinationEditorHttpFields().vm.$emit('input', {
          ...propsDefinition.httpItem,
          config: {
            ...expectedDestinationPayload.config,
          },
          // Mirror what getFormattedFormItem produces for the existing destination's filters.
          namespaceFilters: [{ namespace: 'myGroup/project1', name: 'project1' }],
        });
        await findDestinationName().vm.$emit('input', expectedDestinationPayload.name);
        // Replace the single existing entry with a new entry: triggers one add and one remove.
        await findStreamNamespaceFilters().vm.$emit('input', [
          { namespace: 'myGroup/updated-project' },
        ]);

        await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(apolloMocks.group.updateDestination.success[1]).toHaveBeenCalledWith({
          input: expectedDestinationPayload,
        });

        // Add fires for the new path.
        expect(apolloMocks.group.createNamespaceFilter[1]).toHaveBeenCalledWith({
          destinationId: propsDefinition.httpItem.id,
          namespacePath: 'myGroup/updated-project',
        });

        // Remove fires for the previously stored filter (by its server-side id).
        expect(apolloMocks.group.deleteNamespaceFilter[1]).toHaveBeenCalledWith({
          namespaceFilterId: propsDefinition.httpItem.namespaceFilters[0].id,
        });

        // Ordering: the add must invoke before the remove (compliance safety).
        const addInvocationOrder =
          apolloMocks.group.createNamespaceFilter[1].mock.invocationCallOrder[0];
        const removeInvocationOrder =
          apolloMocks.group.deleteNamespaceFilter[1].mock.invocationCallOrder[0];
        expect(addInvocationOrder).toBeLessThan(removeInvocationOrder);

        expect(findAlertErrors().exists()).toBe(false);
        expect(wrapper.emitted('updated')).toEqual([[]]);
      });

      it('does NOT remove existing filters when an add mutation fails', async () => {
        const failingCreate = [
          apolloMocks.group.createNamespaceFilter[0],
          jest.fn().mockResolvedValue({
            data: {
              auditEventsGroupDestinationNamespaceFilterCreate: {
                errors: ['namespace not found'],
                namespaceFilter: null,
              },
            },
          }),
        ];

        createComponent({
          props: { item: { ...propsDefinition.httpItem } },
          provide: { groupPath: 'group' },
          apolloHandlers: [
            apolloMocks.group.updateDestination.success,
            apolloMocks.group.deleteNamespaceFilter,
            failingCreate,
          ],
        });

        await findStreamDestinationEditorHttpFields().vm.$emit('input', {
          ...propsDefinition.httpItem,
          namespaceFilters: [{ namespace: 'myGroup/project1', name: 'project1' }],
        });
        await findDestinationName().vm.$emit('input', 'Updated Destination name');
        await findStreamNamespaceFilters().vm.$emit('input', [{ namespace: 'myGroup/will-fail' }]);

        await findDestinationForm().vm.$emit('submit', { preventDefault: () => {} });
        await waitForPromises();

        expect(failingCreate[1]).toHaveBeenCalled();
        expect(apolloMocks.group.deleteNamespaceFilter[1]).not.toHaveBeenCalled();
        expect(findAlertErrors().text()).toBe('namespace not found');
      });
    });
  });

  describe('for instance specific view', () => {
    describe('when editing a destination', () => {
      describe('when destination category is http', () => {
        beforeEach(() => {
          createComponent({
            props: { item: propsDefinition.httpItem },
            provide: { groupPath: 'instance' },
          });
        });

        it('does render namespace filters', () => {
          expect(findStreamNamespaceFilters().exists()).toBe(true);
        });
      });
    });
  });
});
