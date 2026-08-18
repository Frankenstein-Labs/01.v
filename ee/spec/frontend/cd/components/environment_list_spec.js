import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import EnvironmentList from 'ee/cd/components/environment_list.vue';
import EnvironmentCard from 'ee/cd/components/environment_card.vue';
import cdAvailableAgentsQuery from 'ee/cd/graphql/cd_available_agents.query.graphql';
import {
  buildDefaultAvailableAgentsQueryResponse,
  defaultAvailableAgents,
  mockCdEnvironments,
} from './mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('EnvironmentList', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRegisterFirstButton = () => wrapper.findByTestId('register-first-environment-button');
  const findLoader = () => wrapper.findComponent(GlLoadingIcon);
  const findEnvironmentCards = () => wrapper.findAllComponents(EnvironmentCard);
  const findLoadMoreButton = () => wrapper.findComponentByTestId('load-more-button');

  const createComponent = ({ props = {}, agentsHandler } = {}) => {
    const availableAgentsHandler =
      agentsHandler ?? jest.fn().mockResolvedValue(buildDefaultAvailableAgentsQueryResponse());

    wrapper = mountExtended(EnvironmentList, {
      apolloProvider: createMockApollo([[cdAvailableAgentsQuery, availableAgentsHandler]]),
      propsData: props,
    });
  };

  describe('when there are no environments', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the empty state title and description', () => {
      expect(findEmptyState().props('title')).toBe('Get started with environments');
      expect(findEmptyState().props('description')).toBe(
        'Environments are places where code gets deployed, such as staging or production.',
      );
    });

    it('renders the illustration', () => {
      expect(findEmptyState().props('illustrationName')).toBe('empty-environment-md');
    });

    it('renders the "Register your first environment" button in the actions slot', () => {
      expect(findRegisterFirstButton().text()).toBe('Register your first environment');
      expect(findRegisterFirstButton().findComponent(GlButton).props('variant')).toBe('confirm');
    });

    it('does not render environment cards', () => {
      expect(findEnvironmentCards()).toHaveLength(0);
    });

    describe('when the register button is clicked', () => {
      beforeEach(() => {
        findRegisterFirstButton().trigger('click');
      });

      it('emits register', () => {
        expect(wrapper.emitted('register')).toHaveLength(1);
      });
    });
  });

  describe('when there are environments', () => {
    beforeEach(async () => {
      createComponent({ props: { environments: mockCdEnvironments } });
      await waitForPromises();
    });

    it('renders a card for each environment', () => {
      expect(findEnvironmentCards()).toHaveLength(2);
      expect(findEnvironmentCards().at(0).props('environment')).toMatchObject({
        name: 'prod-eu-west-1',
      });
      expect(findEnvironmentCards().at(1).props('environment')).toMatchObject({
        name: 'staging-us-east-1',
      });
    });

    // A driver binding stores only the agent's ID, so the cards need the agent list to
    // turn it into a name.
    it('passes the available agents to each card', () => {
      expect(findEnvironmentCards().at(0).props('agents')).toEqual(defaultAvailableAgents);
      expect(findEnvironmentCards().at(1).props('agents')).toEqual(defaultAvailableAgents);
    });

    it('does not render the empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render the loader', () => {
      expect(findLoader().exists()).toBe(false);
    });
  });

  describe('when the available agents query fails', () => {
    beforeEach(async () => {
      createComponent({
        props: { environments: mockCdEnvironments },
        agentsHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('reports the exception to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('GraphQL error'));
    });

    it('still renders the cards, with no agents to resolve names from', () => {
      expect(findEnvironmentCards()).toHaveLength(2);
      expect(findEnvironmentCards().at(0).props('agents')).toEqual([]);
    });
  });

  describe('when the list is loading', () => {
    beforeEach(() => {
      createComponent({ props: { environments: mockCdEnvironments, loading: true } });
    });

    it('renders the medium loader', () => {
      expect(findLoader().props('size')).toBe('md');
    });

    it('does not render environment cards', () => {
      expect(findEnvironmentCards()).toHaveLength(0);
    });

    it('does not render the empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('load more button', () => {
    describe('when there is no next page', () => {
      beforeEach(() => {
        createComponent({ props: { environments: mockCdEnvironments } });
      });

      it('does not render the button', () => {
        expect(findLoadMoreButton().exists()).toBe(false);
      });
    });

    describe('when there is a next page', () => {
      beforeEach(() => {
        createComponent({ props: { environments: mockCdEnvironments, hasNextPage: true } });
      });

      it('renders a centered load more button', () => {
        expect(findLoadMoreButton().text()).toBe('Load more');
        expect(findLoadMoreButton().element.parentElement.classList).toContain('gl-justify-center');
      });

      it('does not render the button as loading', () => {
        expect(findLoadMoreButton().props('loading')).toBe(false);
      });

      describe('when the button is clicked', () => {
        beforeEach(() => {
          findLoadMoreButton().vm.$emit('click');
        });

        it('emits load-more', () => {
          expect(wrapper.emitted('load-more')).toHaveLength(1);
        });
      });
    });

    describe('when the next page is loading', () => {
      beforeEach(() => {
        createComponent({
          props: { environments: mockCdEnvironments, hasNextPage: true, loadingMore: true },
        });
      });

      it('renders the button as loading and keeps the cards on screen', () => {
        expect(findLoadMoreButton().props('loading')).toBe(true);
        expect(findEnvironmentCards()).toHaveLength(2);
      });
    });
  });
});
