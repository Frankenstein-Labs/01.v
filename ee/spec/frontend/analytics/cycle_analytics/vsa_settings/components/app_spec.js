import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import VSASettingsApp from 'ee/analytics/cycle_analytics/vsa_settings/components/app.vue';
import ValueStreamFormContent from 'ee/analytics/cycle_analytics/vsa_settings/components/value_stream_form_content.vue';
import getValueStream from 'ee/analytics/cycle_analytics/vsa_settings/graphql/get_value_stream.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { defaultStages, mockStages, mockValueStreamResponse } from '../mock_data';

Vue.use(VueApollo);

const valueStreamGid = 'gid://gitlab/ValueStream/13';

describe('VSA settings app', () => {
  let wrapper;

  const createWrapper = ({
    props = {},
    provide = {},
    valueStreamProvider = jest.fn().mockResolvedValue(mockValueStreamResponse),
  } = {}) => {
    const apolloProvider = createMockApollo([[getValueStream, valueStreamProvider]]);

    wrapper = shallowMountExtended(VSASettingsApp, {
      apolloProvider,
      provide: {
        isProject: false,
        valueStreamGid,
        fullPath: 'weeeee',
        defaultStages,
        ...provide,
      },
      propsData: props,
    });

    return waitForPromises();
  };

  const findPageHeader = () => wrapper.findByTestId('vsa-settings-page-header');
  const findFormContent = () => wrapper.findComponent(ValueStreamFormContent);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    jest.spyOn(Sentry, 'captureException');
  });

  afterEach(() => {
    Sentry.captureException.mockRestore();
  });

  describe('new value stream', () => {
    let mockProvider;

    beforeEach(() => {
      mockProvider = jest.fn();
      createWrapper({ provide: { valueStreamGid: null }, valueStreamProvider: mockProvider });
    });

    it('renders the page header', () => {
      expect(findPageHeader().text()).toBe('New value stream');
    });

    it('does not send any requests', () => {
      expect(mockProvider).not.toHaveBeenCalled();
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('does not render an alert', () => {
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('renders form content component', () => {
      expect(findFormContent().props()).toMatchObject({
        initialData: { name: '', stages: [] },
      });
    });
  });

  describe('edit value stream', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders the page header', () => {
        expect(findPageHeader().text()).toBe('Edit value stream');
      });

      it('renders loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('does not render an alert', () => {
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('does not render form content component', () => {
        expect(findFormContent().exists()).toBe(false);
      });
    });

    describe('when loaded', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('does not render loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('does not render an alert', () => {
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('renders form content component', () => {
        expect(findFormContent().props()).toMatchObject({
          initialData: {
            id: 'gid://gitlab/ValueStream/1',
            name: 'oink',
            stages: expect.any(Array),
          },
        });

        expect(findFormContent().props().initialData.stages).toHaveLength(
          mockStages.length + defaultStages.length,
        );
      });
    });

    describe('when there is a request error', () => {
      beforeEach(() => {
        return createWrapper({ valueStreamProvider: jest.fn().mockRejectedValue({}) });
      });

      it('does not render loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('renders an alert', () => {
        expect(findErrorAlert().text()).toBe('There was an error fetching the value stream.');
      });

      it('reports the error to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      });

      it('does not render form content component', () => {
        expect(findFormContent().exists()).toBe(false);
      });
    });
  });

  describe('when there is a response parsing error', () => {
    beforeEach(() => {
      return createWrapper({
        valueStreamProvider: jest.fn().mockResolvedValue({ data: { group: null } }),
      });
    });

    it('does not render loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders an alert', () => {
      expect(findErrorAlert().text()).toBe('There was an error fetching the value stream.');
    });

    it('reports the error to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
    });

    it('does not render form content component', () => {
      expect(findFormContent().exists()).toBe(false);
    });
  });
});
