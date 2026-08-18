import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlForm, GlSkeletonLoader } from '@gitlab/ui';
import mavenUpstreamSummaryPayload from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_summary.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import LinkUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/link_upstream_form.vue';
import TestUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/test_button.vue';
import UpstreamSelector from 'ee/packages_and_registries/virtual_registries/components/common/registries/show/upstream_selector.vue';
import getMavenUpstreamSummaryQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_summary.query.graphql';

Vue.use(VueApollo);

describe('LinkUpstreamForm', () => {
  let wrapper;

  const defaultProps = {
    linkedUpstreamIds: [],
  };

  const { upstream: mockUpstream } = mavenUpstreamSummaryPayload.data;
  const upstreamId = mockUpstream.id;

  const mavenUpstreamHandler = jest.fn().mockResolvedValue(mavenUpstreamSummaryPayload);

  const createComponent = ({
    handlers = [[getMavenUpstreamSummaryQuery, mavenUpstreamHandler]],
    props = defaultProps,
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(LinkUpstreamForm, {
      apolloProvider: createMockApollo(handlers),
      propsData: props,
      provide: {
        getUpstreamSummaryQuery: getMavenUpstreamSummaryQuery,
        isMavenUpstream: true,
        ...provide,
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findUpstreamSelect = () => wrapper.findComponent(UpstreamSelector);
  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findTestUpstreamButton = () => wrapper.findComponent(TestUpstreamButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders form', () => {
    expect(findForm().exists()).toBe(true);
  });

  it('renders upstream select', () => {
    expect(findUpstreamSelect().props()).toEqual({
      linkedUpstreamIds: defaultProps.linkedUpstreamIds,
    });
  });

  it('renders empty upstream summary when upstream is not selected', () => {
    expect(wrapper.text()).toContain('To view summary, select an upstream.');
  });

  it('renders submit button', () => {
    expect(findSubmitButton().text()).toBe('Add upstream');
  });

  it('renders cancel button', () => {
    expect(findCancelButton().text()).toBe('Cancel');
  });

  it('does not render Test upstream button', () => {
    expect(findTestUpstreamButton().exists()).toBe(false);
  });

  it('does not call maven upstream graphql query', () => {
    expect(mavenUpstreamHandler).not.toHaveBeenCalled();
  });

  describe('when upstream is selected', () => {
    it('renders a loader', async () => {
      await findUpstreamSelect().vm.$emit('select', upstreamId);

      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    describe('and API succeeds', () => {
      beforeEach(() => {
        findUpstreamSelect().vm.$emit('select', upstreamId);
      });

      it('calls maven upstream graphql query', () => {
        expect(mavenUpstreamHandler).toHaveBeenCalledTimes(1);
        expect(mavenUpstreamHandler).toHaveBeenCalledWith({
          id: upstreamId,
        });
      });

      it('renders upstream summary', async () => {
        await waitForPromises();

        expect(wrapper.text()).toContain('URL');
        expect(wrapper.text()).toContain(mockUpstream.url);
        expect(wrapper.text()).toContain('Description');
        expect(wrapper.text()).toContain(mockUpstream.description);
        expect(wrapper.text()).toContain('Artifact caching period');
        expect(wrapper.text()).toContain('24 hours');
        expect(wrapper.text()).toContain('Metadata caching period');
        expect(wrapper.text()).toContain('48 hours');
      });

      it('renders Test upstream button', () => {
        expect(findTestUpstreamButton().props('upstreamId')).toBe(upstreamId);
      });

      describe('if `isMavenUpstream` is set to false', () => {
        beforeEach(async () => {
          createComponent({ provide: { isMavenUpstream: false } });
          findUpstreamSelect().vm.$emit('select', upstreamId);
          await waitForPromises();
        });

        it('does not render `Metadata caching period` label', () => {
          expect(wrapper.text()).toContain('Artifact caching period');
          expect(wrapper.text()).toContain('24 hours');
          expect(wrapper.text()).not.toContain('Metadata caching period');
        });
      });
    });

    describe('and API fails', () => {
      beforeEach(() => {
        createComponent({
          handlers: [
            [getMavenUpstreamSummaryQuery, jest.fn().mockResolvedValue(new Error('GraphQL error'))],
          ],
        });
        findUpstreamSelect().vm.$emit('select', upstreamId);
      });

      it('renders alert message', async () => {
        await waitForPromises();
        expect(wrapper.text()).toContain('Failed to fetch upstream summary.');
      });

      it('renders Test upstream button', () => {
        expect(findTestUpstreamButton().props('upstreamId')).toBe(upstreamId);
      });
    });

    describe('when resolved upstream does not have description', () => {
      const upstreamResponseWithNullDescription = {
        data: {
          ...mavenUpstreamSummaryPayload.data,
          upstream: {
            ...mockUpstream,
            description: null,
          },
        },
      };

      beforeEach(async () => {
        createComponent({
          handlers: [
            [
              getMavenUpstreamSummaryQuery,
              jest.fn().mockResolvedValue(upstreamResponseWithNullDescription),
            ],
          ],
        });
        findUpstreamSelect().vm.$emit('select', upstreamId);
        await waitForPromises();
      });

      it('does not render `Description` label', () => {
        expect(wrapper.text()).toContain(mockUpstream.url);
        expect(wrapper.text()).not.toContain('Description');
      });
    });
  });

  describe('submit', () => {
    it('does not emit event if upstream is not selected', () => {
      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');

      expect(Boolean(submittedEvent)).toBe(false);
    });

    it('emits event if upstream is selected', async () => {
      await findUpstreamSelect().vm.$emit('select', upstreamId);

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(upstreamId);
    });
  });

  it('emits cancel event when Cancel button is clicked', () => {
    findCancelButton().vm.$emit('click');
    expect(Boolean(wrapper.emitted('cancel'))).toBe(true);
    expect(wrapper.emitted('cancel')[0]).toEqual([]);
  });
});
