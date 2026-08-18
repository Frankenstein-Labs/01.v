import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlDisclosureDropdown, GlDisclosureDropdownItem, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupStreamingDestinationsQuery from 'ee/audit_events/graphql/queries/get_group_streaming_destinations.query.graphql';
import instanceStreamingDestinationsQuery from 'ee/audit_events/graphql/queries/get_instance_streaming_destinations.query.graphql';

import {
  AUDIT_STREAMS_NETWORK_ERRORS,
  ADD_STREAM_MESSAGE,
  DELETE_STREAM_MESSAGE,
} from 'ee/audit_events/constants';
import AuditEventsStream from 'ee/audit_events/components/audit_events_stream.vue';
import StreamDestinationEditor from 'ee/audit_events/components/stream/stream_destination_editor.vue';
import StreamItem from 'ee/audit_events/components/stream/stream_item.vue';
import StreamEmptyState from 'ee/audit_events/components/stream/stream_empty_state.vue';
import { groupPath, instanceGroupPath } from '../mock_data';
import {
  mockAllAPIDestinations,
  groupStreamingDestinationDataPopulator,
  instanceStreamingDestinationDataPopulator,
} from '../mock_data/consolidated_api';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');
Vue.use(VueApollo);

describe('AuditEventsStream', () => {
  let wrapper;
  let providedGroupPath = groupPath;

  const streamingDestinationsQuerySpy = jest
    .fn()
    .mockResolvedValue(groupStreamingDestinationDataPopulator(mockAllAPIDestinations));
  const instanceStreamingDestinationsQuerySpy = jest
    .fn()
    .mockResolvedValue(instanceStreamingDestinationDataPopulator(mockAllAPIDestinations));

  const createComponent = ({ apolloProvider, provide = {} } = {}) => {
    wrapper = mountExtended(AuditEventsStream, {
      provide: {
        groupPath: providedGroupPath,
        ...provide,
      },
      apolloProvider,
      stubs: {
        GlAlert: true,
        GlLoadingIcon: true,
        StreamItem: true,
        StreamDestinationEditor: true,
        StreamEmptyState: true,
      },
    });
  };

  const findSuccessMessage = () => wrapper.findComponent(GlAlert);
  const findAddDestinationButton = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDisclosureDropdownItem = (index) =>
    wrapper.findAllComponents(GlDisclosureDropdownItem).at(index).find('button');
  const findHttpDropdownItem = () => findDisclosureDropdownItem(0);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStreamDestinationEditor = () => wrapper.findComponent(StreamDestinationEditor);
  const findStreamEmptyState = () => wrapper.findComponent(StreamEmptyState);
  const findStreamItems = () => wrapper.findAllComponents(StreamItem);

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('Group AuditEventsStream', () => {
    describe('when initialized', () => {
      it('should render the loading icon while waiting for data to be returned', () => {
        const destinationQuerySpy = jest.fn();
        const apolloProvider = createMockApollo([
          [groupStreamingDestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should render empty state when no data is returned', async () => {
        const destinationQuerySpy = jest
          .fn()
          .mockResolvedValue(groupStreamingDestinationDataPopulator([]));
        const apolloProvider = createMockApollo([
          [groupStreamingDestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamEmptyState().exists()).toBe(true);
      });

      it('should report error when server error occurred', async () => {
        const destinationQuerySpy = jest.fn().mockRejectedValue({});
        const apolloProvider = createMockApollo([
          [groupStreamingDestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.FETCHING_ERROR,
        });
      });
    });

    describe('when edit mode entered', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [groupStreamingDestinationsQuery, streamingDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('shows destination editor when entering edit mode', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamDestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

        await findHttpDropdownItem().trigger('click');

        expect(findStreamDestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when a destination is added', async () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamDestinationEditor().exists()).toBe(false);

        await findHttpDropdownItem().trigger('click');

        const streamDestinationEditorComponent = findStreamDestinationEditor();

        expect(streamDestinationEditorComponent.exists()).toBe(true);

        streamDestinationEditorComponent.vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('clears the success message if an error occurs afterwards', async () => {
        await findHttpDropdownItem().trigger('click');

        findStreamDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);

        await findHttpDropdownItem().trigger('click');

        await findStreamDestinationEditor().vm.$emit('error');

        expect(findSuccessMessage().exists()).toBe(false);
      });
    });

    describe('Streaming items', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [groupStreamingDestinationsQuery, streamingDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('shows the items', () => {
        expect(findStreamItems()).toHaveLength(mockAllAPIDestinations.length);

        findStreamItems().wrappers.forEach((streamItem, index) => {
          expect(streamItem.props('item').id).toBe(mockAllAPIDestinations[index].id);
        });
      });

      it('captures an error when the destination category is not recognized', async () => {
        const unknownAPIDestination = {
          __typename: 'GroupAuditEventStreamingDestination',
          id: 'mock-streaming-destination-1',
          name: 'Unknown Destination 1',
          category: 'something_else',
          secretToken: '',
          config: {},
          eventTypeFilters: [],
          namespaceFilters: [],
          active: true,
        };
        const streamingDestinationsQueryUnknownCategory = jest
          .fn()
          .mockResolvedValue(groupStreamingDestinationDataPopulator([unknownAPIDestination]));
        const apolloProvider = createMockApollo([
          [groupStreamingDestinationsQuery, streamingDestinationsQueryUnknownCategory],
        ]);
        createComponent({
          apolloProvider,
        });
        await waitForPromises();

        expect(Sentry.captureException).toHaveBeenCalledWith(
          new Error('Unknown destination category: something_else'),
        );
      });

      it('updates list when destination is removed', async () => {
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(streamingDestinationsQuerySpy).toHaveBeenCalledTimes(1);

        const currentLength = findStreamItems().length;
        findStreamItems().at(0).vm.$emit('deleted');
        await waitForPromises();
        expect(findStreamItems()).toHaveLength(currentLength - 1);
        expect(findSuccessMessage().text()).toBe(DELETE_STREAM_MESSAGE);
      });
    });
  });

  describe('Instance AuditEventsStream', () => {
    beforeEach(() => {
      providedGroupPath = instanceGroupPath;
    });

    afterEach(() => {
      createAlert.mockClear();
    });

    describe('when initialized', () => {
      it('should render the loading icon while waiting for data to be returned', () => {
        const destinationQuerySpy = jest.fn();
        const apolloProvider = createMockApollo([
          [instanceStreamingDestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });

        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('should render empty state when no data is returned', async () => {
        const destinationQuerySpy = jest
          .fn()
          .mockResolvedValue(instanceStreamingDestinationDataPopulator([]));
        const apolloProvider = createMockApollo([
          [instanceStreamingDestinationsQuery, destinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findStreamEmptyState().exists()).toBe(true);
      });

      it('should report error when server error occurred', async () => {
        const instanceDestinationQuerySpy = jest.fn().mockRejectedValue({});
        const apolloProvider = createMockApollo([
          [instanceStreamingDestinationsQuery, instanceDestinationQuerySpy],
        ]);
        createComponent({ apolloProvider });
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: AUDIT_STREAMS_NETWORK_ERRORS.FETCHING_ERROR,
        });
      });
    });

    describe('when edit mode entered', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [instanceStreamingDestinationsQuery, instanceStreamingDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('does not show loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('shows destination editor when entering edit mode', async () => {
        expect(findStreamDestinationEditor().exists()).toBe(false);

        expect(findAddDestinationButton().props('toggleText')).toBe('Add streaming destination');

        await findHttpDropdownItem().trigger('click');

        expect(findStreamDestinationEditor().exists()).toBe(true);
      });

      it('exits edit mode when a destination is added', async () => {
        expect(findStreamDestinationEditor().exists()).toBe(false);

        await findHttpDropdownItem().trigger('click');

        expect(findStreamDestinationEditor().exists()).toBe(true);

        findStreamDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);
      });

      it('clears the success message if an error occurs afterwards', async () => {
        await findHttpDropdownItem().trigger('click');

        findStreamDestinationEditor().vm.$emit('added');
        await waitForPromises();

        expect(findSuccessMessage().text()).toBe(ADD_STREAM_MESSAGE);

        await findHttpDropdownItem().trigger('click');

        await findStreamDestinationEditor().vm.$emit('error');

        expect(findSuccessMessage().exists()).toBe(false);
      });
    });

    describe('Streaming items', () => {
      beforeEach(() => {
        const apolloProvider = createMockApollo([
          [instanceStreamingDestinationsQuery, instanceStreamingDestinationsQuerySpy],
        ]);
        createComponent({ apolloProvider });

        return waitForPromises();
      });

      it('shows the items', () => {
        expect(findStreamItems()).toHaveLength(mockAllAPIDestinations.length);

        findStreamItems().wrappers.forEach((streamItem, index) => {
          expect(streamItem.props('item').id).toBe(mockAllAPIDestinations[index].id);
        });
      });

      it('updates list when destination is removed', async () => {
        await waitForPromises();

        expect(findLoadingIcon().exists()).toBe(false);
        expect(instanceStreamingDestinationsQuerySpy).toHaveBeenCalledTimes(1);

        const currentLength = findStreamItems().length;
        findStreamItems().at(0).vm.$emit('deleted');
        await waitForPromises();
        expect(findStreamItems()).toHaveLength(currentLength - 1);
        expect(findSuccessMessage().text()).toBe(DELETE_STREAM_MESSAGE);
      });
    });
  });
});
